import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    testWidgets('runs the action after the duration', (tester) async {
      final debouncer = Debouncer(
        duration: const Duration(milliseconds: 500),
      );
      var callCount = 0;

      debouncer.run(() => callCount++);
      expect(callCount, 0);

      await tester.pump(const Duration(milliseconds: 499));
      expect(callCount, 0);

      await tester.pump(const Duration(milliseconds: 1));
      expect(callCount, 1);

      debouncer.dispose();
    });

    testWidgets('cancels previous action when run is called again',
        (tester) async {
      final debouncer = Debouncer(
        duration: const Duration(milliseconds: 500),
      );
      var callCount = 0;

      debouncer.run(() => callCount++);
      await tester.pump(const Duration(milliseconds: 300));
      debouncer.run(() => callCount++);

      await tester.pump(const Duration(milliseconds: 300));
      expect(callCount, 0, reason: 'First call should have been cancelled');

      await tester.pump(const Duration(milliseconds: 200));
      expect(callCount, 1, reason: 'Only the second call should fire');

      debouncer.dispose();
    });

    testWidgets('cancel prevents pending action from firing', (tester) async {
      final debouncer = Debouncer(
        duration: const Duration(milliseconds: 500),
      );
      var callCount = 0;

      debouncer.run(() => callCount++);
      await tester.pump(const Duration(milliseconds: 300));
      debouncer.cancel();

      await tester.pump(const Duration(milliseconds: 500));
      expect(callCount, 0);

      debouncer.dispose();
    });

    testWidgets('dispose prevents pending action from firing', (tester) async {
      final debouncer = Debouncer(
        duration: const Duration(milliseconds: 500),
      );
      var callCount = 0;

      debouncer.run(() => callCount++);
      debouncer.dispose();

      await tester.pump(const Duration(milliseconds: 1000));
      expect(callCount, 0);
    });
  });
}
