import 'package:flutter_test/flutter_test.dart';
import 'package:corpus/utils/safe_change_notifier.dart';

class _TestNotifier extends SafeChangeNotifier {
  int value = 0;

  void incrementViaNotifyListeners() {
    value++;
    notifyListeners();
  }

  void incrementViaNotify() {
    value++;
    notify();
  }
}

void main() {
  group('SafeChangeNotifier', () {
    test('notifyListeners y notify notifican antes de dispose', () {
      final notifier = _TestNotifier();
      var notifications = 0;
      notifier.addListener(() => notifications++);

      notifier.incrementViaNotifyListeners();
      notifier.incrementViaNotify();

      expect(notifier.isDisposed, isFalse);
      expect(notifier.value, 2);
      expect(notifications, 2);

      notifier.dispose();
    });

    test('notifyListeners y notify hacen no-op seguro tras dispose', () {
      final notifier = _TestNotifier();
      var notifications = 0;
      notifier.addListener(() => notifications++);

      notifier.incrementViaNotifyListeners();
      expect(notifications, 1);

      notifier.dispose();
      expect(notifier.isDisposed, isTrue);

      expect(() {
        notifier.notifyListeners();
        notifier.incrementViaNotifyListeners();
        notifier.incrementViaNotify();
      }, returnsNormally);

      expect(notifications, 1);
    });

    test('notifyListeners tras operación asíncrona luego de dispose no lanza', () async {
      final notifier = _TestNotifier();
      var notifications = 0;
      notifier.addListener(() => notifications++);

      final future = Future<void>.delayed(
        const Duration(milliseconds: 10),
        notifier.notifyListeners,
      );

      notifier.dispose();
      await expectLater(future, completes);
      expect(notifications, 0);
    });
  });
}
