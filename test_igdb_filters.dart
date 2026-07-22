import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final igdbClientId = '8x9e7fwrn3wp8fwhxiut4dkbu2oe5h';
  final igdbClientSecret = 'yhg7541eheo6w7g9db56dxwhr13yrv';

  final authUrl = 'https://id.twitch.tv/oauth2/token?client_id=$igdbClientId&client_secret=$igdbClientSecret&grant_type=client_credentials';
  final authResponse = await http.post(Uri.parse(authUrl));
  final token = jsonDecode(authResponse.body)['access_token'];

  Future<void> fetch(String endpoint, String body) async {
    final response = await http.post(
      Uri.parse('https://api.igdb.com/v4/$endpoint'),
      headers: {
        'Client-ID': igdbClientId,
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      body: body,
    );
    print('--- $endpoint ---');
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      print('Count: ${list.length}');
      // Print first 5 items
      for (var item in list.take(5)) {
        print(item);
      }
      
      // Also write all of them to a JSON file so I can inspect them
      File('${endpoint}.json').writeAsStringSync(jsonEncode(list));
    } else {
      print('Error: ${response.statusCode} - ${response.body}');
    }
  }

  await fetch('genres', 'fields id,name; limit 100;');
  await Future.delayed(Duration(seconds: 1));
  await fetch('themes', 'fields id,name; limit 100;');
  await Future.delayed(Duration(seconds: 1));
  await fetch('game_modes', 'fields id,name; limit 100;');
  await Future.delayed(Duration(seconds: 1));
  await fetch('player_perspectives', 'fields id,name; limit 100;');
  await Future.delayed(Duration(seconds: 1));
  await fetch('platforms', 'fields id,name; sort name asc; limit 500;');
}
