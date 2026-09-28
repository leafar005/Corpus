import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../my_games/collection_tab.dart';

/// Pantalla de depuración: estantería virtual de juegos por plataforma.
/// Ruta: `/private/collection`
class CollectionShelfScreen extends StatefulWidget {
  const CollectionShelfScreen({super.key});

  @override
  State<CollectionShelfScreen> createState() => _CollectionShelfScreenState();
}

class _CollectionShelfScreenState extends State<CollectionShelfScreen> {
  final _tabKey = GlobalKey<CollectionTabState>();

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _reload() => _tabKey.currentState?.reload() ?? Future.value();

  @override
  Widget build(BuildContext context) {
    final userId = _userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Estantería'),
        actions: [
          IconButton(
            icon: const CorpusTablerIcon(CorpusIconKind.Refresh),
            tooltip: 'Recargar',
            onPressed: _tabKey.currentState?.isLoading == true ? null : _reload,
          ),
        ],
      ),
      bottomNavigationBar: userId != null
          ? Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: CollectionShelfActionBar(
                    onBulkAdd: () => _tabKey.currentState?.openBulkAdd(),
                    onAddGame: () => _tabKey.currentState?.openAddGame(),
                  ),
                ),
              ),
            )
          : null,
      body: userId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CorpusTablerIcon(
                      CorpusIconKind.Shelves,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Inicia sesión para ver tu estantería',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  CollectionTab(
                    key: _tabKey,
                    userId: userId,
                    showInlineActions: false,
                    horizontalPadding: 20,
                  ),
                ],
              ),
            ),
    );
  }
}
