import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:pubspec_yaml/pubspec_yaml.dart';
import 'package:plain_optional/src/optional.dart';

dynamic main(List<String> args) async {
  if (args.isNotEmpty) {
    for (var arg in args) {
      var package = await http.get('https://pub.dev/api/packages/${arg}');
      var parsed = json.decode(package.body);
      var package_name = parsed['name'];
      var latest_version = parsed['latest']['version'];

      print('Found package $package_name with latest version $latest_version');
      var pubspec = await File('./pubspec.yaml')
          .readAsString()
          .catchError((err) => print(err));
      var pubspec_yaml = pubspec.toPubspecYaml();
      var this_dependencies = pubspec_yaml.dependencies.toList(growable: true);
      var package_spec = PackageDependencySpec.hosted(
          HostedPackageDependencySpec(
              package: package_name, version: Optional('^$latest_version')));

      if (!this_dependencies.contains(package_spec)) {
        this_dependencies.add(package_spec);
      } else {
        print('pubspec.yaml already contains this package.');
      }

      var pubspec_edited =
          pubspec_yaml.copyWith(dependencies: this_dependencies).toYamlString();

      var file = await File('./pubspec.yaml').writeAsString(pubspec_edited);
      print('Written pubspec.yaml: $file');
      var pub_get = await Process.run('pub', ['get']);
      print(pub_get.stdout ?? pub_get.stderr);
    }
  } else {
    print('Please specify the name of the package you want to install.');
  }
}
