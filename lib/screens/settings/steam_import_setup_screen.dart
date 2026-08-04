import 'package:flutter/material.dart';
import 'package:corpus/globals.dart';
import 'steam_import_progress_screen.dart';

class SteamImportSetupScreen extends StatefulWidget {
  const SteamImportSetupScreen({super.key});

  @override
  State<SteamImportSetupScreen> createState() => _SteamImportSetupScreenState();
}

class _SteamImportSetupScreenState extends State<SteamImportSetupScreen> {
  double _minHours = 3.0; // valor por defecto
  // ignore: prefer_final_fields
  bool _isStarting = false;

  void _startImport() {
    final minPlaytimeMinutes = (_minHours * 60).round();

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SteamImportProgressScreen(minPlaytimeMinutes: minPlaytimeMinutes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24.0,
        bottom: getBottomSpacer(context),
        left: 24.0,
        right: 24.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Importar biblioteca',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Solo se importarán los juegos que superen el tiempo mínimo de juego que elijas. Esto evita llenar tu biblioteca de juegos que apenas probaste.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tiempo mínimo de juego',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _minHours == 0
                      ? 'Sin mínimo (todos)'
                      : '${_minHours.toStringAsFixed(_minHours.truncateToDouble() == _minHours ? 0 : 1)}h',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: _minHours,
              min: 0,
              max: 50,
              divisions: 100, // pasos de 0.5h
              label: _minHours == 0
                  ? 'Sin mínimo'
                  : '${_minHours.toStringAsFixed(1)}h',
              onChanged: (val) => setState(() => _minHours = val),
            ),
            Wrap(
              spacing: 8,
              children: [0.0, 1.0, 3.0, 5.0, 10.0]
                  .map(
                    (h) => ChoiceChip(
                      label: Text(h == 0 ? 'Todos' : '${h.toInt()}h'),
                      selected: _minHours == h,
                      onSelected: (_) => setState(() => _minHours = h),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isStarting ? null : _startImport,
                child: _isStarting
                    ? const CircularProgressIndicator()
                    : const Text('Iniciar importación'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
