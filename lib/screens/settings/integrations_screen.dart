import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'steam_import_setup_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:corpus/services/import_service.dart';
import 'package:corpus/screens/settings/import_preview_screen.dart';

class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  final _steamInputController = TextEditingController();
  bool _isLinkingSteam = false;
  String? _steamId;
  String? _steamName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('steam_id, steam_name')
          .eq('id', userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _steamId = res?['steam_id'];
          _steamName = res?['steam_name'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _linkSteam() async {
    final input = _steamInputController.text.trim();
    if (input.isEmpty) return;
    setState(() => _isLinkingSteam = true);
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'resolve-steam-id',
        body: {'urlOrId': input},
      );
      final data = res.data;
      if (data != null && data['success'] == true) {
        setState(() {
          _steamId = data['steamId'];
          _steamName = data['steamName'];
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cuenta de Steam vinculada con éxito.'),
            ),
          );
      }
    } on FunctionException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.details ?? e.toString()}')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al vincular: $e')));
    } finally {
      if (mounted) setState(() => _isLinkingSteam = false);
    }
  }

  Future<void> _unlinkSteam() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLinkingSteam = true);
    try {
      await Supabase.instance.client
          .from('users')
          .update({'steam_id': null, 'steam_name': null})
          .eq('id', userId);

      setState(() {
        _steamId = null;
        _steamName = null;
        _steamInputController.clear();
      });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cuenta desvinculada.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al desvincular: $e')));
    } finally {
      if (mounted) setState(() => _isLinkingSteam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integraciones')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _steamId == null || _steamId!.isEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vincula tu cuenta de Steam para importar tus juegos y tiempo de juego. Pega tu URL de perfil de Steam (ej. https://steamcommunity.com/id/tunombre) o tu SteamID64.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _steamInputController,
                                      decoration: const InputDecoration(
                                        hintText: 'Steam Profile URL o ID',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _isLinkingSteam
                                        ? null
                                        : _linkSteam,
                                    child: _isLinkingSteam
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Vincular'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _steamName != null
                                          ? 'Cuenta vinculada: $_steamName'
                                          : 'Cuenta de Steam vinculada',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _isLinkingSteam
                                        ? null
                                        : _unlinkSteam,
                                    child: const Text(
                                      'Desvincular',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.cloud_download),
                                  label: const Text(
                                    'Importar biblioteca de Steam',
                                  ),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) =>
                                          const SteamImportSetupScreen(),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Importar Biblioteca',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Migrar tu biblioteca de juegos y reseñas desde Stash utilizando un archivo JSON, HAR o CSV exportado desde la app.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.file_upload_outlined),
                            label: const Text('Importar desde Stash'),
                            onPressed: () async {
                              try {
                                final result = await FilePicker.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['csv', 'json', 'har'],
                                );

                                if (result != null) {
                                  final fileBytes = await result.files.single
                                      .readAsBytes();

                                  if (fileBytes.isNotEmpty) {
                                    bool isCancelled = false;
                                    ValueNotifier<double> progressNotifier =
                                        ValueNotifier(0.0);
                                    ValueNotifier<String> statusNotifier =
                                        ValueNotifier("Preparando datos...");

                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: const Text(
                                              'Procesando juegos',
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ValueListenableBuilder<double>(
                                                  valueListenable:
                                                      progressNotifier,
                                                  builder: (context, progress, child) {
                                                    return Column(
                                                      children: [
                                                        LinearProgressIndicator(
                                                          value: progress > 0
                                                              ? progress
                                                              : null,
                                                          minHeight: 8,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 16,
                                                        ),
                                                        Text(
                                                          '${(progress * 100).toStringAsFixed(1)}% completado',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 12),
                                                ValueListenableBuilder<String>(
                                                  valueListenable:
                                                      statusNotifier,
                                                  builder:
                                                      (
                                                        context,
                                                        status,
                                                        child,
                                                      ) => Text(
                                                        status,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  isCancelled = true;
                                                  Navigator.pop(context);
                                                },
                                                child: const Text('Cancelar'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    }

                                    final fileName = result.files.single.name
                                        .toLowerCase();
                                    final rows = fileName.endsWith('.csv')
                                        ? ImportService.parseCsv(fileBytes)
                                        : ImportService.parseStashJson(
                                            fileBytes,
                                          );

                                    await ImportService.matchGamesWithIGDB(rows, (
                                      p,
                                      t,
                                    ) {
                                      if (t > 0) {
                                        progressNotifier.value = p / t;
                                        statusNotifier.value =
                                            "Buscando coincidencias ($p de $t)...";
                                      }
                                    }, isCancelled: () => isCancelled);

                                    if (!isCancelled && context.mounted) {
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).pop();
                                    }

                                    if (!isCancelled && context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ImportPreviewScreen(rows: rows),
                                        ),
                                      );
                                    }
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
