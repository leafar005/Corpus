import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'steam_import_setup_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:corpus/services/import_service.dart';
import 'package:corpus/screens/settings/import_preview_screen.dart';
import '../../theme/corpus_theme_extension.dart';

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cuenta de Steam vinculada con éxito.'),
            ),
          );
        }
      }
    } on FunctionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.details ?? e.toString()}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al vincular: $e')));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cuenta desvinculada.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al desvincular: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLinkingSteam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CorpusThemeExtension>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('Integraciones')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                top: 16.0,
                bottom: getBottomSpacer(context),
                left: 16.0,
                right: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: ext.radiusMedium,
                    ),
                    child: _steamId == null || _steamId!.isEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vincula tu cuenta de Steam para importar tus juegos y tiempo de juego. Pega tu URL de perfil de Steam (ej. https://steamcommunity.com/id/tunombre) o tu SteamID64.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Importar Biblioteca',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.help_outline, size: 18),
                        label: const Text('¿Cómo hacerlo?'),
                        onPressed: () => _showStashMigrationHelp(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: ext.radiusMedium,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Migrar tu biblioteca de juegos y reseñas desde Stash utilizando un archivo JSON, HAR o CSV exportado desde la app.',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: ext.radiusMedium,
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.amber,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Aviso sobre juegos duplicados',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Si importas juegos que ya tienes en tu biblioteca de Corpus, se creará una segunda reseña para cada uno de ellos. Tenlo en cuenta por si quieres revisarlas o borrar una de las dos más adelante.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
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

  void _showStashMigrationHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Migrar tu biblioteca desde Stash',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Actualmente, Stash no tiene un botón oficial para exportar tus juegos, pero puedes extraerlos capturando el tráfico de la app desde tu móvil. Es más fácil de lo que parece:',
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildHelpStep(
                      context: context,
                      number: '1',
                      title: 'Captura tus datos',
                      content:
                          'Descarga una aplicación gratuita para capturar tráfico en tu móvil. Si usas iOS te recomendamos Proxyman. Si usas Android, las mejores opciones son PCAPdroid o HTTP Toolkit.\n\n'
                          'Abre la aplicación que acabas de descargar e inicia la captura de red.\n\n'
                          'Abre tu app de Stash y haz scroll lentamente por toda tu biblioteca (y la pestaña de reseñas) para asegurarte de que todos tus juegos cargan en pantalla.\n\n'
                          'Vuelve a la app de captura, detén el proceso y exporta el registro generado. Guárdalo o compártelo eligiendo el formato .har.',
                    ),
                    const SizedBox(height: 24),
                    _buildHelpStep(
                      context: context,
                      number: '2',
                      title: '¡Sube tu archivo a Corpus!',
                      content:
                          'Vuelve a esta pantalla y sube directamente el archivo .har o .json que has exportado (también soportamos .csv). Corpus hará la magia: lo leerá automáticamente, buscará las carátulas en alta calidad, vinculará las franquicias y recuperará tus estados, reseñas y horas jugadas. ¡Bienvenido a tu nueva casa!',
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: Theme.of(context)
                                .extension<CorpusThemeExtension>()!
                                .radiusMedium,
                          ),
                        ),
                        child: const Text(
                          '¡Entendido!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHelpStep({
    required BuildContext context,
    required String number,
    required String title,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
