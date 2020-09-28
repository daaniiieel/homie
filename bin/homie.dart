import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis_auth/auth.dart';
import 'package:googleapis/classroom/v1.dart';
import 'package:googleapis_auth/src/auth_http_utils.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:async';
import 'package:http/http.dart';
import 'package:uuid/uuid.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:isolate';

/// The scopes used by homie
final scopes = [
  ClassroomApi.ClassroomCourseworkMeReadonlyScope,
  ClassroomApi.ClassroomCoursesReadonlyScope
];

/// Parses a credentials.json file from this directory
Future<Map> parseCredentials() async {
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

  return {
    'id': id,
    'todoist': json.decode(creds)['todoist']['token'],
    'kreta': json.decode(creds)['kreta']
  };
}

Future<Map> getTodoistProjects() async {
  var client = Client();
  var credentials = await parseCredentials();
  var url = Uri.parse('https://api.todoist.com/sync/v8/sync');
  var uri = url.replace(queryParameters: {
    'token': credentials['todoist'],
    'sync_token': '*',
    'resource_types': '["projects"]'
  });
  var response = await client.get(uri);
  client.close();
  return json.decode(response.body);
}

Future<Map> addNewTask(String name,
    [Date date, TimeOfDay time, DateTime fullDateTime]) async {
  var client = Client();
  var creds = await parseCredentials();
  var todoist_projects = await getTodoistProjects();

  var url = Uri.parse('https://api.todoist.com/sync/v8/sync');
  var uuid = Uuid();
  var commands = [];
  var dateTimeString;
  if (fullDateTime == null) {
    dateTimeString = googleDateToString(date, time);
  } else {
    dateTimeString = fullDateTime.toLocal().toIso8601String().split('.')[0];
  }

  if (dateTimeString != '') {
    commands = [
      {
        'type': 'item_add',
        'uuid': uuid.v4(),
        'temp_id': uuid.v4(),
        'args': {
          'content': name,
          'due': {'date': dateTimeString}
        }
      }
    ];
  } else {
    commands = [
      {
        'type': 'item_add',
        'uuid': uuid.v4(),
        'temp_id': uuid.v4(),
        'args': {
          'content': name,
        }
      }
    ];
  }
  //print(
  //   '${date.year}-${date.month.toString().length == 1 ? "0${date.month.toString()}" : date.month}-${date.day.toString().length == 1 ? "0${date.day.toString()}" : date.day}');
  var uri = url.replace(queryParameters: {
    'token': creds['todoist'],
    'sync_token': todoist_projects['sync_token'],
    'resource_types': '["items"]',
    'commands': json.encode(commands)
  });
  var response = await client.get(uri).catchError((e) {
    print('e');
  });
  if (json.decode(response.body)['error'] != null) {
    print(
        'addNewTask error ${json.decode(response.body)['error']}, retrying in 15s.');
    io.sleep(Duration(seconds: 15));
    var response2 = await client.get(uri).catchError((e) {
      print('e');
    });
    if (json.decode(response2.body)['error'] != null) {
      return json.decode(response2.body);
    }
  }
  client.close();
  await io.sleep(Duration(seconds: 2));
  return json.decode(response.body);
}

/// An ulity function to save a token from a Client instance.
void saveTokenFromClient(AutoRefreshingClient client) async {
  var tokens = client.credentials;
  var cache = {
    'access_token': tokens.accessToken.data,
    'token_type': tokens.accessToken.type,
    'refresh_token': tokens.refreshToken,
    'expiry': tokens.accessToken.expiry.toIso8601String(),
  };
  // write token to file
  await io.File('./classroom_token.json').writeAsString(json.encode(cache));
}

/// Gets a classroom client. If classroom_token.json exists in the current
/// working directory, tries to obtain a client from the cached
/// oAuth2 token. If it doesn't, prompts the user for authentication
/// and saves classroom_token.json
Future<List<dynamic>> getClassroomClient() async {
  // parse the credentials.json file
  var creds = await parseCredentials();

  // if the program has been ran before
  if (await io.File('./classroom_token.json').exists()) {
    print('classroom_token.json exists!');
    try {
      var baseClient = Client();

      var token_json = json
          .decode(await io.File('./classroom_token.json').readAsStringSync());

      var credentials = AccessCredentials(
        AccessToken('Bearer', token_json['access_token'],
            DateTime.parse(token_json['expiry'])),
        token_json['refresh_token'],
        scopes,
      );

      var client = AutoRefreshingClient(baseClient, creds['id'], credentials,
          closeUnderlyingClient: false);

      saveTokenFromClient(client);

      var classroom = ClassroomApi(client);
      return [classroom, client];
    } catch (e) {
      // Wait. This wasn't supposed to happen.
      // ===EMERGENCY MEETING===
      // Give up o [Try again] o Call Luigi

      print(e);
      var client =
          await clientViaUserConsentManual(creds['id'], scopes, authPrompt)
              .catchError((err) => print('Auth error: $err'));
      saveTokenFromClient(client);

      var classroom = ClassroomApi(client);
      return [classroom, client];
    }
  } else {
    // running for the first time => cache token
    var client =
        await clientViaUserConsentManual(creds['id'], scopes, authPrompt)
            .catchError((err) => print('Auth error: $err'));
    saveTokenFromClient(client);

    // get an instance of the classroom client
    var classroom = ClassroomApi(client);
    return [classroom, client];
  }
}

String googleDateToString([Date date, TimeOfDay time]) {
  DateTime newDate;
  if (date != null) {
    if (time != null) {
      newDate = DateTime(date.year, date.month, date.day, time.hours ?? 00,
          time.minutes ?? 00, time.seconds ?? 00);
    } else {
      newDate = DateTime(date.year, date.month, date.day);
    }
    return newDate.toLocal().toIso8601String().split('.')[0];
  } else {
    return '';
  }
}

void classroom_main(String _) async {
  /// The path 'db' (json file) where homie will store its
  /// todoist-classroom id-pairs.
  final database = io.File('./classroom-db.json');

  print(_);
  // get the classroom instance and the authenticated
  // http client
  var classroom_list = await getClassroomClient();

  // this has to be statically typed so
  // vscode intellisense works correctly
  ClassroomApi classroom = classroom_list[0];
  Client client = classroom_list[1];

  var courses_response =
      await classroom.courses.list($fields: 'courses(id,name,courseState)');

  var courses = courses_response.courses;
  for (var course in courses) {
    if (course.courseState != 'ARCHIVED') {
      var work = await classroom.courses.courseWork
          .list(course.id)
          .catchError((err) => print(err));
      if (work != null && work.courseWork != null) {
        for (var assignment in work.courseWork) {
          var submissions = await classroom
              .courses.courseWork.studentSubmissions
              .list(course.id, assignment.id)
              .catchError((err) => print(err));
          for (var submission in submissions.studentSubmissions) {
            if (submission.state != 'TURNED_IN' &&
                submission.state != 'RETURNED') {
              if (await database.exists()) {
                var database_json =
                    json.decode(await database.readAsString()) ?? [];
                var hasElement = database_json
                    .any((element) => element['classroom'] == assignment.id);
                if (!hasElement) {
                  var added_task = await addNewTask(
                      assignment.title, assignment.dueDate, assignment.dueTime);
                  database_json.add({
                    'classroom': assignment.id,
                    'todoist': added_task['items'][0]['id'],
                  });
                  await database.writeAsString(json.encode(database_json));
                  print(
                      '${assignment.title}: ${submission.state} ${course.name}');
                }
              } else {
                var database_json = [];
                var added_task = await addNewTask(
                    assignment.title, assignment.dueDate, assignment.dueTime);

                database_json.add({
                  'classroom': assignment.id,
                  'todoist': added_task['items'][0]['id'],
                });
                await database.writeAsString(json.encode(database_json));
                print(
                    '${assignment.title}: ${submission.state} ${course.name}');
              }
            }
          }
        }
      }
    }
  } // after doing work, close the connection
  try {
    client.close();
  } catch (e) {
    print('Error while closing client: $e');
  }
}

String ellipsize(String input, int length) => input.length > length
    ? input.split('').sublist(0, length - 4).join() + '...'
    : input;
void kreta_main(String _) async {
  /// The path 'db' (json file) where homie will store its
  /// todoist-classroom id-pairs.
  final database = io.File('./kreta-db.json');

  print(_);
  var client = Client();
  final userAgent = 'hu.ekreta.student/1.0.5/Android/0/0';
  var creds = await parseCredentials();
  var login_response = await client.post(
    'https://idp.e-kreta.hu/connect/token',
    body: {
      'userName': creds['kreta']['username'],
      'password': creds['kreta']['password'],
      'institute_code': creds['kreta']['schoolCode'],
      'grant_type': 'password',
      'client_id': 'kreta-ellenorzo-mobile'
    },
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent': userAgent,
    },
  );

  var login_json = json.decode(login_response.body);
  var instituteCode = creds['kreta']['schoolCode'];
  var auth_token = login_json['access_token'];
  var fromDate = DateTime.now().subtract(Duration(days: 7));

  // get homeworks
  var homeworks_response = await client.get(
    'https://$instituteCode.e-kreta.hu/ellenorzo/V3/Sajat/HaziFeladatok?datumTol=' +
        fromDate.toUtc().toIso8601String(),
    headers: {'Authorization': 'Bearer $auth_token', 'User-Agent': userAgent},
  );

  var homeworks_json = json.decode(homeworks_response.body);

  for (var homework in homeworks_json) {
    if (await database.exists()) {
      var database_json = json.decode(await database.readAsString()) ?? [];
      var hasElement =
          database_json.any((element) => element['kreta'] == homework['Uid']);
      if (!hasElement &&
          DateTime.parse(homework['HataridoDatuma']).isAfter(DateTime.now())) {
        var title = ellipsize(parseHtmlString(homework['Szoveg']), 40);

        var added_task = await addNewTask(
            title, null, null, DateTime.parse(homework['HataridoDatuma']));

        database_json.add({
          'kreta': homework['Uid'],
          'todoist': added_task['items'][0]['id'],
        });
        await database.writeAsString(json.encode(database_json));
        print(
            '${title} ${DateTime.parse(homework['HataridoDatuma']).toLocal()}');
      }
    } else {
      if (DateTime.parse(homework['HataridoDatuma']).isAfter(DateTime.now())) {
        var database_json = [];
        var title = ellipsize(parseHtmlString(homework['Szoveg']), 40);

        var added_task = await addNewTask(
            title, null, null, DateTime.parse(homework['HataridoDatuma']));
        print(added_task);
        database_json.add({
          'kreta': homework['Uid'],
          'todoist': added_task['items'][0]['id'],
        });

        await database.writeAsString(json.encode(database_json));
        print(
            '${title} ${DateTime.parse(homework['HataridoDatuma']).toLocal()}');
      }
    }
  }
  client.close();
}

void main(List<String> args) {
  kreta_main('Starting KRÉTA sync');
  classroom_main('Starting Classroom synnc');
}

/// The frontend of the auth prompt used by getClassroomClient()
Future<String> authPrompt(String url) {
  print(
      'Please go to the following URL and grant access, then type the code below:');
  print('  => $url');
  print('Code:');
  var input = io.stdin.readLineSync();
  print('---\n');
  return Future<String>.value(input);
}

String parseHtmlString(String htmlString) {
  var text = html.Element.span()..appendHtml(htmlString);
  return text.innerText;
}
