import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final igdbClientId = '8x9e7fwrn3wp8fwhxiut4dkbu2oe5h';
  final igdbClientSecret = 'yhg7541eheo6w7g9db56dxwhr13yrv';

  final authUrl = 'https://id.twitch.tv/oauth2/token?client_id=$igdbClientId&client_secret=$igdbClientSecret&grant_type=client_credentials';
  final authResponse = await http.post(Uri.parse(authUrl));
  final token = jsonDecode(authResponse.body)['access_token'];

  final response = await http.post(
    Uri.parse('https://api.igdb.com/v4/game_time_to_beats'),
    headers: {
      'Client-ID': igdbClientId,
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    },
    body: 'fields *; where game_id = 1942; limit 1;',
  );
  
  print(response.body);
}
