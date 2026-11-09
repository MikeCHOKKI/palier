import 'package:flutter_test/flutter_test.dart';
import 'package:palier/features/expenses/ui/amount_pad.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('la devise du profil se fige une fois une opération notée', (tester) async {
    final app = await openExpenses(tester);
    await tester.tap(find.text('Noter'));
    await app.settle(tester);
    await tapPad(tester, ['1', '0', '0']);
    await tester.tap(find.text('Eau'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer la dépense'));
    await app.settle(tester);

    await tester.tap(find.text('Réglages').last);
    await app.settle(tester);
    await tester.tap(find.text('Ama').last);
    await app.settle(tester);

    expect(find.textContaining('La devise ne change plus'), findsOneWidget);
    await tester.tap(find.text('€'));
    await tester.pump();
    final profile = await tester.runAsync(() => app.profiles.watchAll().first);
    expect(profile!.single.currency, PalierCurrency.xof);
  });
}

Future<TestApp> openExpenses(WidgetTester tester) async {
  final app = await TestApp.pump(tester, seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')));
  await tester.tap(find.text('Dépenses').last);
  await app.settle(tester);
  return app;
}

Future<void> tapPad(WidgetTester tester, List<String> digits) async {
  for (final d in digits) {
    await tester.tap(find.descendant(of: find.byType(AmountPad), matching: find.text(d)));
    await tester.pump();
  }
}
