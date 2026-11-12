import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:palier/features/expenses/data/expenses_repository.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../helpers/pump_app.dart';

final _day = DateTime(2026, 11, 10, 12);

void main() {
  testWidgets('seul le jour le plus récent est ouvert ; les autres se déplient au toucher', (tester) async {
    final app = await TestApp.pump(
      tester,
      // Un écran haut : toute la liste du mois tient sans défiler.
      size: const Size(390, 2400),
      now: _day,
      seed: (repo) => repo.create(const ProfileDraft(name: 'Ama')),
    );
    await tester.runAsync(() async {
      final repo = ExpensesRepository(app.db);
      final profileId = (await app.profiles.watchAll().first).single.id;
      await repo.ensureStarterKit(profileId);
      final account = (await repo.watchAccounts(profileId).first).single.id;
      final category = (await repo.watchCategories(profileId, kind: CategoryKind.expense).first).first.id;
      Future<void> spend(String note, DateTime at) => repo.addOperation(
        profileId,
        OperationDraft(
          kind: OperationKind.expense,
          amount: 1000,
          accountId: account,
          categoryId: category,
          note: note,
          occurredAt: at,
        ),
      );
      await spend('pain', DateTime(2026, 11, 10, 8));
      await spend('marché', DateTime(2026, 11, 8, 9));
      await spend('tomates', DateTime(2026, 11, 8, 10));
    });
    await tester.tap(find.text('Dépenses').last);
    await app.settle(tester);

    final older = find.textContaining('2 opérations');
    expect(find.textContaining('pain'), findsOneWidget);
    expect(find.textContaining('marché'), findsNothing);

    await tester.tap(older);
    await app.settle(tester);
    expect(find.textContaining('marché'), findsOneWidget);
    expect(find.textContaining('2 opérations'), findsNothing, reason: 'ouvert, le jour ne se résume plus');

    await tester.tap(find.textContaining('Aujourd’hui'));
    await app.settle(tester);
    expect(find.textContaining('pain'), findsNothing);
    expect(find.textContaining('1 opération'), findsOneWidget);
  });
}
