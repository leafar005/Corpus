import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:corpus/globals.dart';

import 'package:corpus/widgets/corpus_icon_kind.dart';

import 'package:corpus/widgets/guest_login_prompt.dart';

import 'games_tab.dart';
import 'collection_tab.dart';

import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'groups_tab.dart';



class MyGamesScreen extends StatefulWidget {

  const MyGamesScreen({super.key});



  @override

  State<MyGamesScreen> createState() => _MyGamesScreenState();

}



class _MyGamesScreenState extends State<MyGamesScreen> {

  int _selectedTab = 0;

  int _refreshSeed = 0;

  final ScrollController _scrollController = ScrollController();

  final GlobalKey<_GroupsTabHostState> _groupsTabKey = GlobalKey();



  bool get _isGuest => Supabase.instance.client.auth.currentUser == null;



  @override

  void initState() {

    super.initState();

    if (!_isGuest) {

      libraryUpdateNotifier.addListener(_onLibraryUpdated);

    }

    tabScrollToTopNotifiers[3].addListener(_onScrollToTop);

  }



  @override

  void dispose() {

    libraryUpdateNotifier.removeListener(_onLibraryUpdated);

    tabScrollToTopNotifiers[3].removeListener(_onScrollToTop);

    _scrollController.dispose();

    super.dispose();

  }



  void _onLibraryUpdated() {

    if (!mounted) return;

    if (_selectedTab == 0) {

      setState(() => _refreshSeed++);

    }

  }



  void _onScrollToTop() {

    if (!mounted) return;

    if (_selectedTab != 0) {

      setState(() => _selectedTab = 0);

    }

    if (_scrollController.hasClients) {

      _scrollController.animateTo(

        0,

        duration: const Duration(milliseconds: 300),

        curve: Curves.easeOut,

      );

    }

  }



  @override

  Widget build(BuildContext context) {

    if (_isGuest) {

      return Scaffold(

        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        body: const Center(

          child: GuestLoginPrompt(

            icon: CorpusIconKind.Gamepad,

            message: 'Inicia sesión para ver y gestionar tus juegos.',

          ),

        ),

      );

    }



    final isDesktop = MediaQuery.of(context).size.width > 800;

    final userId = Supabase.instance.client.auth.currentUser!.id;



    return Scaffold(

      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      floatingActionButton: _selectedTab == 2
          ? Padding(
              padding: EdgeInsets.only(
                bottom: (getBottomSpacer(context) - 72).clamp(0.0, double.infinity),
              ),
              child: FloatingActionButton.extended(
                onPressed: () => _groupsTabKey.currentState?.createGroup(),
                icon: const CorpusTablerIcon(CorpusIconKind.Add),
                label: const Text('Nuevo grupo'),
              ),
            )
          : null,

      body: CustomScrollView(

        controller: _scrollController,

        slivers: [

          SliverToBoxAdapter(

            child: Padding(

              padding: EdgeInsets.fromLTRB(

                isDesktop ? 40 : 16,

                isDesktop ? 32 : MediaQuery.of(context).padding.top + 16,

                isDesktop ? 40 : 16,

                8,

              ),

              child: Text(

                'Mis juegos',

                style: Theme.of(context).textTheme.headlineMedium?.copyWith(

                  fontWeight: FontWeight.bold,

                ),

              ),

            ),

          ),

          SliverPersistentHeader(

            pinned: true,

            delegate: _MyGamesTabBarDelegate(

              selectedTab: _selectedTab,

              onTabSelected: (index) {

                setState(() => _selectedTab = index);

              },

              backgroundColor: Theme.of(context).scaffoldBackgroundColor,

            ),

          ),

          ..._buildTabContent(userId, isDesktop),

        ],

      ),

    );

  }



  List<Widget> _buildTabContent(String userId, bool isDesktop) {

    switch (_selectedTab) {

      case 0:

        return [

          GamesTab(

            key: ValueKey('games-$_refreshSeed'),

            userId: userId,

            onReturn: () => setState(() => _refreshSeed++),

            scrollController: _scrollController,

          ),

        ];

      case 1:

        return [

          CollectionTab(

            key: ValueKey('collection-$userId'),

            userId: userId,

          ),

        ];

      case 2:

        return [

          _GroupsTabHost(

            key: _groupsTabKey,

            userId: userId,

          ),

        ];

      default:

        return const [SliverToBoxAdapter(child: SizedBox.shrink())];

    }

  }

}



/// Host para exponer acciones del tab Grupos al FAB del Scaffold.

class _GroupsTabHost extends StatefulWidget {

  const _GroupsTabHost({

    super.key,

    required this.userId,

  });



  final String userId;



  @override

  State<_GroupsTabHost> createState() => _GroupsTabHostState();

}



class _GroupsTabHostState extends State<_GroupsTabHost> {

  final GlobalKey<GroupsTabState> _tabKey = GlobalKey();



  void createGroup() => _tabKey.currentState?.openCreateGroupDialog();



  @override

  Widget build(BuildContext context) {

    return GroupsTab(

      key: _tabKey,

      userId: widget.userId,

    );

  }

}



class _MyGamesTabBarDelegate extends SliverPersistentHeaderDelegate {

  _MyGamesTabBarDelegate({

    required this.selectedTab,

    required this.onTabSelected,

    required this.backgroundColor,

  });



  final int selectedTab;

  final ValueChanged<int> onTabSelected;

  final Color backgroundColor;



  static const _tabs = ['Juegos', 'Colección', 'Grupos'];



  @override

  double get minExtent => 48;



  @override

  double get maxExtent => 48;



  @override

  Widget build(

    BuildContext context,

    double shrinkOffset,

    bool overlapsContent,

  ) {

    final isDesktop = MediaQuery.of(context).size.width > 800;



    return Container(

      decoration: BoxDecoration(

        color: backgroundColor,

        border: Border(

          bottom: BorderSide(

            color: Theme.of(context).colorScheme.onSurface.withValues(

              alpha: 0.1,

            ),

          ),

        ),

      ),

      child: SingleChildScrollView(

        scrollDirection: Axis.horizontal,

        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 16),

        child: Row(

          children: List.generate(_tabs.length, (index) {

            final isSelected = selectedTab == index;

            return GestureDetector(

              onTap: () => onTabSelected(index),

              child: Container(

                padding: const EdgeInsets.symmetric(

                  horizontal: 16,

                  vertical: 12,

                ),

                decoration: BoxDecoration(

                  border: Border(

                    bottom: BorderSide(

                      color: isSelected

                          ? Theme.of(context).colorScheme.primary

                          : Colors.transparent,

                      width: 3,

                    ),

                  ),

                ),

                child: Text(

                  _tabs[index],

                  style: TextStyle(

                    fontSize: 15,

                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,

                    color: isSelected

                        ? Theme.of(context).colorScheme.onSurface

                        : Theme.of(context).colorScheme.onSurfaceVariant,

                  ),

                ),

              ),

            );

          }),

        ),

      ),

    );

  }



  @override

  bool shouldRebuild(covariant _MyGamesTabBarDelegate oldDelegate) {

    return oldDelegate.selectedTab != selectedTab ||

        oldDelegate.backgroundColor != backgroundColor;

  }

}


