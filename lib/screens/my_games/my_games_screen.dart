import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/guest_login_prompt.dart';

import 'games_tab.dart';
import 'collection_tab.dart';
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

  final GlobalKey<GamesTabState> _gamesTabKey = GlobalKey<GamesTabState>();
  final GlobalKey<CollectionTabState> _collectionTabKey =
      GlobalKey<CollectionTabState>();
  final GlobalKey<GroupsTabState> _groupsTabKey = GlobalKey<GroupsTabState>();

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
    setState(() => _refreshSeed++);
    _gamesTabKey.currentState?.reload();
    _collectionTabKey.currentState?.reload();
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

  Future<void> _onRefresh() async {
    switch (_selectedTab) {
      case 0:
        await (_gamesTabKey.currentState?.reload() ?? Future.value());
        break;
      case 1:
        await (_collectionTabKey.currentState?.reload() ?? Future.value());
        break;
      case 2:
        await (_groupsTabKey.currentState?.reload() ?? Future.value());
        break;
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
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
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
            ..._buildTabContent(userId),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTabContent(String userId) {
    switch (_selectedTab) {
      case 0:
        return [
          GamesTab(
            key: _gamesTabKey,
            userId: userId,
            onReturn: () => setState(() => _refreshSeed++),
            scrollController: _scrollController,
          ),
        ];
      case 1:
        return [
          CollectionTab(
            key: _collectionTabKey,
            userId: userId,
          ),
        ];
      case 2:
        return [
          GroupsTab(
            key: _groupsTabKey,
            userId: userId,
            allowCreate: true,
          ),
        ];
      default:
        return const [SliverToBoxAdapter(child: SizedBox.shrink())];
    }
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

  static const _tabs = [
    (label: 'Juegos', icon: CorpusIconKind.Gamepad),
    (label: 'Estantería', icon: CorpusIconKind.Shelves),
    (label: 'Colecciones', icon: CorpusIconKind.CollectionsBookmarkOutlined),
  ];

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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 16),
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            final isSelected = selectedTab == index;
            final color = isSelected
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant;

            return InkWell(
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
                          ? colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CorpusTablerIcon(
                      tab.icon,
                      size: 18,
                      color: isSelected ? colorScheme.primary : color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
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
