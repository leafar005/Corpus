import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:corpus/widgets/corpus_tabler_icon.dart';
import 'package:corpus/widgets/corpus_icon_kind.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:corpus/globals.dart';
import 'steam_import_setup_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:corpus/services/import_service.dart';
import 'package:corpus/routes/corpus_router.dart';
import '../../theme/corpus_theme_extension.dart';
import '../../widgets/corpus_section_title.dart';

class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  static const int _maxStashImportBytes = 25 * 1024 * 1024; // 25 MB

  final _steamInputController = TextEditingController();
  bool _isLinkingSteam = false;
  String? _steamId;
  String? _steamName;
  bool _isLoading = true;
  bool _isGuest = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _fetchUserData(fromInitState: true);
  }

  @override
  void dispose() {
    _steamInputController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData({bool fromInitState = false}) async {
    String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      userId = null;
    }
    if (userId == null) {
      if (fromInitState) {
        _isGuest = true;
        _loadError = null;
        _isLoading = false;
      } else if (mounted) {
        setState(() {
          _isGuest = true;
          _loadError = null;
          _isLoading = false;
        });
      }
      return;
    }
    if (fromInitState) {
      _isGuest = false;
      _loadError = null;
    } else if (mounted) {
      setState(() {
        _isGuest = false;
        _loadError = null;
      });
    }

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
      debugPrint('[IntegrationsScreen] Error cargando integraciones: $e');
      if (mounted) {
        setState(() {
          _loadError = 'No se pudieron cargar tus integraciones.';
          _isLoading = false;
        });
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
      if (!mounted) return;
      final data = res.data;
      if (data is Map && data['success'] == true) {
        setState(() {
          _steamId = data['steamId']?.toString();
          _steamName = data['steamName']?.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta de Steam vinculada con éxito.'),
          ),
        );
      } else {
        final msg = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'No se pudo vincular la cuenta de Steam.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
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
      if (!mounted) return;

      setState(() {
        _steamId = null;
        _steamName = null;
        _steamInputController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cuenta desvinculada.')));
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

  Future<void> _importFromStash() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json', 'har'],
        withData: kIsWeb,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar archivo: $e')),
        );
      }
      return;
    }

    if (!mounted || result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    if (pickedFile.size > _maxStashImportBytes) {
      final sizeMb = (pickedFile.size / (1024 * 1024)).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El archivo es demasiado grande ($sizeMb MB). El máximo permitido es 25 MB.',
          ),
        ),
      );
      return;
    }

    final Uint8List? fileBytes;
    if (pickedFile.bytes != null) {
      fileBytes = pickedFile.bytes;
    } else if (!kIsWeb && pickedFile.path != null) {
      fileBytes = await File(pickedFile.path!).readAsBytes();
    } else {
      fileBytes = null;
    }

    if (!mounted) return;
    if (fileBytes == null || fileBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El archivo seleccionado está vacío.')),
      );
      return;
    }

    if (fileBytes.length > _maxStashImportBytes) {
      final sizeMb = (fileBytes.length / (1024 * 1024)).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El archivo es demasiado grande ($sizeMb MB). El máximo permitido es 25 MB.',
          ),
        ),
      );
      return;
    }

    var isCancelled = false;
    var loadingDialogOpen = false;
    var notifiersClosed = false;
    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('Preparando datos...');
    Future<void>? dialogFuture;
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    void closeLoadingDialog() {
      notifiersClosed = true;
      if (!loadingDialogOpen) return;
      loadingDialogOpen = false;
      if (rootNavigator.mounted && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
    }

    try {
      if (!mounted) return;
      loadingDialogOpen = true;
      dialogFuture = showDialog<void>(
        context: context,
        barrierDismissible: false,
        routeSettings: const RouteSettings(name: 'loading_dialog'),
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Procesando juegos'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (ctx, progress, child) {
                    return Column(
                      children: [
                        LinearProgressIndicator(
                          value: progress > 0 ? progress : null,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}% completado',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: statusNotifier,
                  builder: (ctx, status, child) => Text(
                    status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  isCancelled = true;
                  notifiersClosed = true;
                  if (loadingDialogOpen && dialogContext.mounted) {
                    loadingDialogOpen = false;
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ).whenComplete(() {
        loadingDialogOpen = false;
      });

      // Cede un frame para que el diálogo se pinte antes de decodificar JSON/HAR/CSV.
      if (!notifiersClosed) {
        statusNotifier.value = 'Leyendo archivo...';
      }
      await Future<void>.delayed(Duration.zero);
      if (isCancelled || !mounted) return;

      final fileName = pickedFile.name.toLowerCase();
      final rows = fileName.endsWith('.csv')
          ? await ImportService.parseCsv(fileBytes)
          : await ImportService.parseStashJson(fileBytes);

      if (isCancelled || !mounted) return;
      if (rows.isEmpty) {
        closeLoadingDialog();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron juegos válidos en el archivo.'),
          ),
        );
        return;
      }
      if (!notifiersClosed) {
        statusNotifier.value =
            'Buscando coincidencias (${rows.length} juegos)...';
      }
      await Future<void>.delayed(Duration.zero);
      if (isCancelled || !mounted) return;

      await ImportService.matchGamesWithIGDB(
        rows,
        (p, t) {
          if (isCancelled || notifiersClosed || !mounted) return;
          if (t > 0) {
            progressNotifier.value = p / t;
            statusNotifier.value = 'Buscando coincidencias ($p de $t)...';
          }
        },
        isCancelled: () => isCancelled || !mounted,
      );

      if (!isCancelled && mounted) {
        closeLoadingDialog();
        context.pushImportPreview(rows);
      }
    } catch (e) {
      closeLoadingDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      notifiersClosed = true;
      closeLoadingDialog();
      if (dialogFuture != null) {
        unawaited(
          dialogFuture.whenComplete(() {
            progressNotifier.dispose();
            statusNotifier.dispose();
          }),
        );
      } else {
        progressNotifier.dispose();
        statusNotifier.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = CorpusThemeExtension.of(context);
    return Scaffold(
      appBar: AppBar(title: const CorpusScreenTitle('Integraciones')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isGuest
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Inicia sesión para vincular e integrar servicios externos.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _loadError = null;
                        });
                        _fetchUserData();
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                                  const CorpusTablerIcon(CorpusIconKind.CheckCircle,
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
                                  icon: const CorpusTablerIcon(CorpusIconKind.CloudDownload),
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
                        icon: const CorpusTablerIcon(CorpusIconKind.HelpOutline, size: 18),
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const CorpusTablerIcon(
                              CorpusIconKind.FileUploadOutlined,
                            ),
                            label: const Text('Importar desde Stash'),
                            onPressed: _importFromStash,
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
                        const CorpusTablerIcon(CorpusIconKind.InfoOutline,
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
                        CorpusTablerIcon(CorpusIconKind.Inventory2Outlined,
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
                            borderRadius: CorpusThemeExtension.of(context).radiusMedium,
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
