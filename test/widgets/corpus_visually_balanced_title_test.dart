import 'package:corpus/widgets/corpus_section_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CorpusVisuallyBalancedTitle.computeOffset', () {
    test('positive offset when only leading back button is present', () {
      expect(
        CorpusVisuallyBalancedTitle.computeOffset(hasLeading: true),
        CorpusVisuallyBalancedTitle.defaultLeadingWidth / 2,
      );
    });

    test('no offset when trailing balances leading', () {
      expect(
        CorpusVisuallyBalancedTitle.computeOffset(
          hasLeading: true,
          trailingBalanceWidth: CorpusVisuallyBalancedTitle.defaultLeadingWidth,
        ),
        0,
      );
    });

    test('no offset without leading', () {
      expect(CorpusVisuallyBalancedTitle.computeOffset(hasLeading: false), 0);
    });
  });
}
