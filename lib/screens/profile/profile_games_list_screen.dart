import 'package:flutter/material.dart';
import 'package:corpus/screens/profile/profile_games_grid_tab.dart';

class ProfileGamesListScreen extends StatelessWidget {
  final String title;
  final String userId;
  final String? status;

  const ProfileGamesListScreen({
    super.key,
    required this.title,
    required this.userId,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ProfileGamesGridTab(
        userId: userId,
        status: status,
        onReturn: () {},
      ),
    );
  }
}

