import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/balanced_alternates.dart';

void main() {
  late BalancedAlternates balancedAlternates;

  setUp(() {
    balancedAlternates = BalancedAlternates();
  });

  test('empty results with no alternates', () async {
    expect(balancedAlternates.getAlternates(), isEmpty);
  });

  test('one phrase, no alternates returns that phrase', () async {
    balancedAlternates.add(0, 'one', 0.85);
    final alts = balancedAlternates.getAlternates();
    expect(alts, hasLength(1));
    expect(alts[0].recognizedWords, 'one');
    expect(alts[0].confidence, 0.85);
  });

  test('one phrase, one alternate returns that phrase and alternate', () async {
    balancedAlternates.add(0, 'one', 0.85);
    balancedAlternates.add(0, 'an', 0.65);
    final alts = balancedAlternates.getAlternates();
    expect(alts, hasLength(2));
    expect(alts[0].recognizedWords, 'one');
    expect(alts[0].confidence, 0.85);
    expect(alts[1].recognizedWords, 'an');
    expect(alts[1].confidence, 0.65);
  });

  test('one phrase, two alternates returns that phrase and alternates',
      () async {
    balancedAlternates.add(0, 'one', 0.85);
    balancedAlternates.add(0, 'an', 0.65);
    balancedAlternates.add(0, 'and', 0.55);
    final alts = balancedAlternates.getAlternates();
    expect(alts, hasLength(3));
    expect(alts[0].recognizedWords, 'one');
    expect(alts[0].confidence, 0.85);
    expect(alts[1].recognizedWords, 'an');
    expect(alts[1].confidence, 0.65);
    expect(alts[2].recognizedWords, 'and');
    expect(alts[2].confidence, 0.55);
  });

  test('two phrases, no alternates returns concatenated phrase', () async {
    balancedAlternates.add(0, 'one ', 0.85);
    balancedAlternates.add(1, 'tree', 0.95);
    final alts = balancedAlternates.getAlternates();
    expect(alts, hasLength(1));
    expect(alts[0].recognizedWords, 'one tree');
    expect(alts[0].confidence, 0.85);
  });
  test('two phrases, one alternate each returns expected', () async {
    balancedAlternates.add(0, 'one ', 0.85);
    balancedAlternates.add(0, 'an ', 0.65);
    balancedAlternates.add(1, 'tree', 0.95);
    balancedAlternates.add(1, 'free', 0.35);
    final alts = balancedAlternates.getAlternates();
    expect(alts, hasLength(2));
    expect(alts[0].recognizedWords, 'one tree');
    expect(alts[0].confidence, 0.85);
    expect(alts[1].recognizedWords, 'an free');
    expect(alts[1].confidence, 0.35);
  });

  test('two phrases, missing alternate for second', () async {
    balancedAlternates.add(0, 'one ', 0.85);
    balancedAlternates.add(0, 'an ', 0.65);
    balancedAlternates.add(1, 'tree', 0.95);
    final alts = balancedAlternates.getAlternates();
    expect(alts, hasLength(2));
    expect(alts[0].recognizedWords, 'one tree');
    expect(alts[0].confidence, 0.85);
    expect(alts[1].recognizedWords, 'an tree');
    expect(alts[1].confidence, 0.65);
  });
}
