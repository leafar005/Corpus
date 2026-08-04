import 'package:flutter/material.dart';
import 'package:corpus/screens/profile/profile_games_grid_tab.dart';

class ProfileGamesListScreen extends StatefulWidget {
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
  State<ProfileGamesListScreen> createState() => _ProfileGamesListScreenState();
}

class _ProfileGamesListScreenState extends State<ProfileGamesListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          ProfileGamesGridTab(
            userId: widget.userId,
            status: widget.status,
            onReturn: () {},
            scrollController: _scrollController,
          ),
        ],
      ),
    );
  }
}
