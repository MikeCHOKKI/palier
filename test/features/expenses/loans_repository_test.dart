import 'package:flutter_test/flutter_test.dart';
import 'package:palier/app/providers.dart';
import 'package:palier/data/database.dart';
import 'package:palier/features/backup/data/backup_service.dart';
import 'package:palier/features/backup/domain/backup_codec.dart';
import 'package:palier/features/expenses/data/expenses_repository.dart';
import 'package:palier/features/expenses/domain/expense_kinds.dart';
import 'package:palier/features/expenses/domain/expenses.dart';
import 'package:palier/features/expenses/domain/loans.dart';
import 'package:palier/features/profiles/data/profiles_repository.dart';
import 'package:palier/features/profiles/domain/profile.dart';

import '../../helpers/test_database.dart';

void main() {
  late PalierDatabase db;
  late ExpensesRepository repo;
  late String ama;
  late Account momo;

  final LoanNotes notes = (
    lent: (name) => 'Prêt $name',
    borrowed: (name) => 'Emprunt $name',
    repayment: (name) => 'Remboursement $name',
  );
  final day = DateTime(2026, 11, 11);

  LoanDraft draft(LoanDirection direction, {int amount = 30000, bool beforePalier = false}) => LoanDraft(
    name: 'Koffi',
    direction: direction,
    amount: amount,
    accountId: momo.id,
    day: day,
    beforePalier: beforePalier,
  );

  Future<int> balanceOf(String id) async => (await repo.watchAccounts(ama).first).firstWhere((a) => a.id == id).balance;
  Future<Loan> onlyLoan() async => (await repo.watchLoans(ama).first).single;

  Future<List<OperationEntry>> entries() async {
    final (from, to) = MonthView.bounds(DateTime(2026, 11));
    return repo.watchOperations(ama, from: from, to: to).first;
  }

  Future<MonthView> month() async => MonthView(month: DateTime(2026, 11), entries: await entries());

  setUp(() async {
    db = openTestDatabase();
    repo = ExpensesRepository(db, clock: () => DateTime.utc(2026, 11, 11, 9));
    ama = (await ProfilesRepository(db).create(const ProfileDraft(name: 'Ama'))).id;
    momo = await repo.createAccount(
      ama,
      const AccountDraft(name: 'MoMo', kind: AccountKind.mobileMoney, openingBalance: 100000),
    );
  });

  tearDown(() => db.close());

  test('prêter fait sortir l’argent du compte, sans compter comme une dépense', () async {
    await repo.createLoan(ama, draft(LoanDirection.lent), notes: notes);

    final loan = await onlyLoan();
    expect((loan.balance, loan.remaining, loan.repaid, loan.settled), (30000, 30000, 0, false));
    expect(await balanceOf(momo.id), 70000);
    final view = await month();
    expect((view.spent, view.received), (0, 0));
    expect((await entries()).single.note, 'Prêt Koffi');
  });

  test('emprunter fait entrer l’argent, et le solde du prêt dit ce qu’on doit', () async {
    await repo.createLoan(ama, draft(LoanDirection.borrowed), notes: notes);

    final loan = await onlyLoan();
    expect((loan.balance, loan.remaining), (-30000, 30000));
    expect(await balanceOf(momo.id), 130000);
  });

  test('les remboursements partiels réduisent le reste, jusqu’à solder le prêt', () async {
    await repo.createLoan(ama, draft(LoanDirection.borrowed), notes: notes);
    Future<void> repay(int amount) async =>
        repo.repayLoan(ama, await onlyLoan(), amount: amount, accountId: momo.id, day: day, notes: notes);

    await repay(10000);
    expect(((await onlyLoan()).remaining, (await onlyLoan()).repaid), (20000, 10000));
    expect(await balanceOf(momo.id), 120000);

    await expectLater(repay(25000), throwsArgumentError, reason: 'plus que le reste dû');
    await repay(20000);
    final loan = await onlyLoan();
    expect((loan.remaining, loan.repaid, loan.settled), (0, 30000, true));
    expect(await balanceOf(momo.id), 100000);
    expect((await month()).spent, 0, reason: 'un remboursement n’est pas une dépense');
  });

  test('un prêt d’avant Palier ne touche pas aux comptes', () async {
    await repo.createLoan(ama, draft(LoanDirection.lent, amount: 12000, beforePalier: true), notes: notes);

    expect((await onlyLoan()).remaining, 12000);
    expect(await balanceOf(momo.id), 100000);
    expect(await entries(), isEmpty);
  });

  test('supprimé, il emporte ses opérations : les comptes retrouvent leur solde', () async {
    final id = await repo.createLoan(ama, draft(LoanDirection.lent), notes: notes);
    await repo.repayLoan(ama, await onlyLoan(), amount: 5000, accountId: momo.id, day: day, notes: notes);
    final loanAccount = (await onlyLoan()).accountId;
    await repo.deleteLoan(id);

    expect(await repo.watchLoans(ama).first, isEmpty);
    expect(await balanceOf(momo.id), 100000);
    expect((await repo.watchAccounts(ama).first).map((a) => a.id), isNot(contains(loanAccount)));
    expect(await entries(), isEmpty);
  });

  test('se renomme, et suit le profil dans la sauvegarde', () async {
    final id = await repo.createLoan(ama, draft(LoanDirection.lent), notes: notes);
    await repo.renameLoan(id, 'Koffi (moto)');
    expect((await onlyLoan()).name, 'Koffi (moto)');

    BackupService serviceFor(PalierDatabase base) =>
        BackupService(base, codec: const BackupCodec(iterations: 1000), sections: backupSections(base));
    final file = await serviceFor(db).exportProfile(ama, 'lune-baobab-42');
    final other = openTestDatabase();
    addTearDown(other.close);
    final service = serviceFor(other);
    await service.import(await service.open(file, 'lune-baobab-42'));
    expect(await ExpensesRepository(other).watchLoans(ama).first, await repo.watchLoans(ama).first);
  });
}
