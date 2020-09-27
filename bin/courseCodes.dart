import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/classroom/v1.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:async';

Future<ClientId> parseCredentials() async {
  var credentials = await io.File('./credentials.json');
  var creds = '';
  if (await credentials.existsSync()) {
    creds = await credentials.readAsString();
  } else {
    throw 'File ./credentials.json doesn\'t exist. Aborting.';
  }

  var creds_json = json.decode(creds)['installed'];

  // get a client id from the creds
  var id = ClientId(creds_json['client_id'], creds_json['client_secret']);

  return id;
}

void main(List<String> arguments) async {
  // parse the credentials.json file
  var creds = await parseCredentials();

  // scopes we're gonna use
  var scopes = [
    ClassroomApi.ClassroomCourseworkMeReadonlyScope,
    ClassroomApi.ClassroomCoursesReadonlyScope
  ];

  // get an auto-refreshing http client with the oauth deitails

  var client = await clientViaUserConsentManual(creds, scopes, authPrompt)
      .catchError((err) => print('Auth error: $err'));

  // get an instance of the classroom client
  var classroom = ClassroomApi(client);

  var courses_response = await classroom.courses.list();
  courses_response.courses.forEach((element) {
    print('${element.name}: ${element.enrollmentCode}');
  });

  // after doing work, close the connection
  try {
    client.close();
  } catch (e) {
    print('Error while closing client: $e');
  }
}

Future<String> authPrompt(String url) {
  print(
      'Please go to the following URL and grant access, then type the code below:');
  print('  => $url');
  print('Code:');
  var input = io.stdin.readLineSync();
  print('---\n');
  return Future<String>.value(input);
}
