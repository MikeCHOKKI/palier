import 'package:drift/drift.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidRecurrence;
import 'package:uuid/uuid.dart';

import '../../../data/database.dart';
import '../domain/budgets.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import '../domain/loans.dart';
import '../domain/recurring.dart';
import '../domain/starter_kit.dart';
import '../domain/tontines.dart';

/// Un compte encore utilisé par des opérations ne se supprime pas : ses
/// opérations perdraient leur sens et les soldes deviendraient faux.
class AccountInUseException implements Exception {
  const AccountInUseException();
}

/// Comptes, catégories, opérations, plafonds et récurrences d'un profil.
class ExpensesRepository {
  ExpensesRepository(this._db, {DateTime Function()? clock, Uuid? uuid})
    : _clock = clock ?? (() => DateTime.now().toUtc()),
      _uuid = uuid ?? const Uuid();

  final PalierDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid;

  /// Le même compte joint deux fois (débité, crédité) : un alias pour chacun,
  /// créé une fois, car la lecture d'une ligne jointe retrouve la table par son objet.
  late final _debitedAccount = _db.alias(_db.accounts, 'from_account');
  late final _creditedAccount = _db.alias(_db.accounts, 'to_account');

  // ---------------------------------------------------------------- départ

  /// Donne au profil son compte et ses catégories de départ, une seule fois :
  /// un profil qui a supprimé ses catégories ne les voit pas revenir.
  Future<void> ensureStarterKit(String profileId) {
    return _db.transaction(() async {
      final anyCategory =
          await (_db.select(_db.categories)
                ..where((c) => c.profileId.equals(profileId))
                ..limit(1))
              .getSingleOrNull();
      final anyAccount =
          await (_db.select(_db.accounts)
                ..where((a) => a.profileId.equals(profileId))
                ..limit(1))
              .getSingleOrNull();
      if (anyAccount == null) await createAccount(profileId, StarterKit.account);
      if (anyCategory == null) {
        for (final draft in StarterKit.categories) {
          await createCategory(profileId, draft);
        }
      }
    });
  }

  // ---------------------------------------------------------------- comptes

  /// Les comptes du profil avec leur solde : solde de départ, plus les revenus
  /// et virements reçus, moins les dépenses et virements émis.
  Stream<List<Account>> watchAccounts(String profileId) {
    final query = _db.customSelect(
      '''
      SELECT a.*,
        a.opening_balance
        + COALESCE((SELECT SUM(CASE o.kind WHEN 'income' THEN o.amount ELSE -o.amount END)
                    FROM operations o
                    WHERE o.account_id = a.id AND o.deleted_at IS NULL), 0)
        + COALESCE((SELECT SUM(o.amount)
                    FROM operations o
                    WHERE o.to_account_id = a.id AND o.kind = 'transfer' AND o.deleted_at IS NULL), 0)
        AS balance
      FROM accounts a
      WHERE a.profile_id = ? AND a.deleted_at IS NULL
      ORDER BY a.position, a.created_at
      ''',
      variables: [Variable.withString(profileId)],
      readsFrom: {_db.accounts, _db.operations},
    );
    return query.watch().map(
      (rows) => [for (final row in rows) _accountOf(_db.accounts.map(row.data), row.read<int>('balance'))],
    );
  }

  Future<Account> createAccount(String profileId, AccountDraft draft) async {
    final now = _clock();
    final id = _uuid.v4();
    final last = await _lastPosition(_db.accounts, profileId);
    await _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            profileId: profileId,
            name: draft.name.trim(),
            kind: draft.kind,
            openingBalance: Value(draft.openingBalance),
            goal: Value(draft.goal),
            position: Value(last + 1),
          ),
        );
    final name = draft.name.trim();
    return Account(
      id: id,
      name: name,
      kind: draft.kind,
      openingBalance: draft.openingBalance,
      balance: draft.openingBalance,
      goal: draft.goal,
    );
  }

  Future<void> updateAccount(String id, AccountDraft draft) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        name: Value(draft.name.trim()),
        kind: Value(draft.kind),
        openingBalance: Value(draft.openingBalance),
        goal: Value(draft.goal),
        updatedAt: Value(_clock()),
      ),
    );
  }

  /// Supprime un compte sans opération ni récurrence ; lève [AccountInUseException] sinon.
  Future<void> deleteAccount(String id) {
    return _db.transaction(() async {
      final used =
          await (_db.select(_db.operations)
                ..where((o) => (o.accountId.equals(id) | o.toAccountId.equals(id)) & o.deletedAt.isNull())
                ..limit(1))
              .getSingleOrNull();
      if (used != null) throw const AccountInUseException();
      final repeating =
          await (_db.select(_db.recurrences)
                ..where((r) => (r.accountId.equals(id) | r.toAccountId.equals(id)) & r.deletedAt.isNull())
                ..limit(1))
              .getSingleOrNull();
      if (repeating != null) throw const AccountInUseException();
      final now = _clock();
      await (_db.update(
        _db.accounts,
      )..where((a) => a.id.equals(id))).write(AccountsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
    });
  }

  // ------------------------------------------------------------- catégories

  Stream<List<Category>> watchCategories(String profileId, {CategoryKind? kind}) {
    final query = _db.select(_db.categories)
      ..where((c) {
        final mine = c.profileId.equals(profileId) & c.deletedAt.isNull();
        return kind == null ? mine : mine & c.kind.equalsValue(kind);
      })
      ..orderBy([(c) => OrderingTerm.asc(c.position), (c) => OrderingTerm.asc(c.createdAt)]);
    return query.watch().map((rows) => [for (final row in rows) _toCategory(row)]);
  }

  Future<Category> createCategory(String profileId, CategoryDraft draft) async {
    final now = _clock();
    final id = _uuid.v4();
    final last = await _lastPosition(_db.categories, profileId);
    await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            profileId: profileId,
            name: draft.name.trim(),
            kind: draft.kind,
            icon: draft.icon,
            position: Value(last + 1),
          ),
        );
    return Category(id: id, name: draft.name.trim(), kind: draft.kind, icon: draft.icon);
  }

  /// Renomme ou change l'icône ; le type (dépense ou revenu) reste celui de la création.
  Future<void> updateCategory(String id, {required String name, required String icon}) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(name.trim()), icon: Value(icon), updatedAt: Value(_clock())),
    );
  }

  /// Suppression douce : les opérations passées gardent le nom de leur catégorie.
  Future<void> deleteCategory(String id) {
    final now = _clock();
    return (_db.update(
      _db.categories,
    )..where((c) => c.id.equals(id))).write(CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  // ------------------------------------------------------------- opérations

  /// Opérations dont la date tombe dans [from ; to[, la plus récente d'abord.
  Stream<List<OperationEntry>> watchOperations(String profileId, {required DateTime from, required DateTime to}) {
    final o = _db.operations;
    return _entriesQuery(
      o.profileId.equals(profileId) &
          o.deletedAt.isNull() &
          o.occurredAt.isBiggerOrEqualValue(from.toUtc()) &
          o.occurredAt.isSmallerThanValue(to.toUtc()),
    ).watch().map((rows) => rows.map(_toEntry).toList(growable: false));
  }

  Future<OperationEntry?> findOperation(String id) async {
    final o = _db.operations;
    final row = await _entriesQuery(o.id.equals(id) & o.deletedAt.isNull()).getSingleOrNull();
    return row == null ? null : _toEntry(row);
  }

  /// Le profil a-t-il déjà saisi une opération ? (Sa devise ne change plus alors.)
  Future<bool> hasOperations(String profileId) async {
    final row =
        await (_db.select(_db.operations)
              ..where((o) => o.profileId.equals(profileId) & o.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Enregistre une opération. Avec [repeat], elle devient la première échéance
  /// d'une nouvelle récurrence ; avec [due], elle règle cette échéance.
  Future<String> addOperation(String profileId, OperationDraft draft, {LucidRecurrence? repeat, Due? due}) {
    _check(draft);
    assert(repeat == null || due == null, 'une opération règle une échéance ou en crée une, pas les deux');
    return _db.transaction(() async {
      final now = _clock();
      final id = _uuid.v4();
      String? recurrenceId = due?.recurring.id;
      DateTime? dueOn = due?.day;
      if (repeat != null) {
        final recurring = RecurringDraft.fromOperation(draft, repeat);
        recurrenceId = await createRecurring(profileId, recurring);
        dueOn = recurring.rule.start;
      }
      await _db
          .into(_db.operations)
          .insert(
            OperationsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              profileId: profileId,
              kind: draft.kind,
              amount: draft.amount,
              accountId: draft.accountId!,
              toAccountId: Value(draft.kind == OperationKind.transfer ? draft.toAccountId : null),
              categoryId: Value(draft.kind == OperationKind.transfer ? null : draft.categoryId),
              note: Value(draft.cleanNote),
              occurredAt: draft.occurredAt.toUtc(),
              recurrenceId: Value(recurrenceId),
              dueOn: Value(dueOn == null ? null : dayKey(dueOn)),
            ),
          );
      return id;
    });
  }

  Future<void> updateOperation(String id, OperationDraft draft) {
    _check(draft);
    return (_db.update(_db.operations)..where((o) => o.id.equals(id))).write(
      OperationsCompanion(
        kind: Value(draft.kind),
        amount: Value(draft.amount),
        accountId: Value(draft.accountId!),
        toAccountId: Value(draft.kind == OperationKind.transfer ? draft.toAccountId : null),
        categoryId: Value(draft.kind == OperationKind.transfer ? null : draft.categoryId),
        note: Value(draft.cleanNote),
        occurredAt: Value(draft.occurredAt.toUtc()),
        updatedAt: Value(_clock()),
      ),
    );
  }

  Future<void> deleteOperation(String id) {
    final now = _clock();
    return (_db.update(
      _db.operations,
    )..where((o) => o.id.equals(id))).write(OperationsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  /// Annule une suppression (bouton « Annuler » juste après).
  Future<void> restoreOperation(String id) {
    return (_db.update(_db.operations)..where((o) => o.id.equals(id))).write(
      OperationsCompanion(deletedAt: const Value(null), updatedAt: Value(_clock())),
    );
  }

  // --------------------------------------------------------------- plafonds

  /// Les plafonds du profil, dans l'ordre de leurs catégories. Une catégorie
  /// supprimée emporte son plafond.
  Stream<List<Budget>> watchBudgets(String profileId) {
    final b = _db.budgets;
    final c = _db.categories;
    final query = _db.select(b).join([innerJoin(c, c.id.equalsExp(b.categoryId))])
      ..where(b.profileId.equals(profileId) & b.deletedAt.isNull() & c.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(c.position), OrderingTerm.asc(c.createdAt)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          () {
            final budget = row.readTable(b);
            final category = row.readTable(c);
            return Budget(
              categoryId: category.id,
              categoryName: category.name,
              categoryIcon: category.icon,
              amount: budget.amount,
            );
          }(),
      ],
    );
  }

  /// Pose ou change le plafond d'une catégorie. Une catégorie n'a qu'une ligne :
  /// un plafond retiré puis remis réutilise la sienne.
  Future<void> setBudget(String profileId, String categoryId, int amount) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount', 'Un plafond est positif');
    final now = _clock();
    return _db
        .into(_db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: _uuid.v4(),
            createdAt: now,
            updatedAt: now,
            profileId: profileId,
            categoryId: categoryId,
            amount: amount,
          ),
          onConflict: DoUpdate(
            (_) => BudgetsCompanion(amount: Value(amount), deletedAt: const Value(null), updatedAt: Value(now)),
            target: [_db.budgets.categoryId],
          ),
        );
  }

  /// Retire le plafond d'une catégorie (suppression douce).
  Future<void> removeBudget(String categoryId) {
    final now = _clock();
    return (_db.update(_db.budgets)..where((b) => b.categoryId.equals(categoryId))).write(
      BudgetsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Ce que [categoryId] a coûté entre [from] et [to[ : de quoi savoir si une
  /// dépense vient de franchir un seuil du plafond.
  Future<int> spentIn(String profileId, String categoryId, {required DateTime from, required DateTime to}) async {
    final o = _db.operations;
    final total = o.amount.sum();
    final row =
        await (_db.selectOnly(o)
              ..addColumns([total])
              ..where(
                o.profileId.equals(profileId) &
                    o.categoryId.equals(categoryId) &
                    o.kind.equalsValue(OperationKind.expense) &
                    o.deletedAt.isNull() &
                    o.occurredAt.isBiggerOrEqualValue(from.toUtc()) &
                    o.occurredAt.isSmallerThanValue(to.toUtc()),
              ))
            .getSingle();
    return row.read(total) ?? 0;
  }

  // ------------------------------------------------------------ récurrences

  /// Les récurrences du profil, avec leurs échéances déjà réglées ou passées.
  /// Relues à chaque changement d'opération : régler ou supprimer une
  /// opération fait disparaître ou revenir son échéance.
  Stream<List<Recurring>> watchRecurrings(String profileId) async* {
    yield await _recurrings(profileId);
    final tables = <ResultSetImplementation<dynamic, dynamic>>[
      _db.recurrences,
      _db.recurrenceSkips,
      _db.operations,
      _db.accounts,
      _db.categories,
    ];
    await for (final _ in _db.tableUpdates(TableUpdateQuery.onAllTables(tables))) {
      yield await _recurrings(profileId);
    }
  }

  Future<Recurring?> findRecurring(String id) async {
    final row = await (_db.select(
      _db.recurrences,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return null;
    final all = await _recurrings(row.profileId);
    return all.where((r) => r.id == id).firstOrNull;
  }

  /// Crée une récurrence. Ses échéances comptent à partir du jour de création :
  /// une récurrence posée le 11 avec un début le 5 ne réclame pas l'échéance du
  /// 5, sans doute déjà réglée, mais attend la suivante.
  Future<String> createRecurring(String profileId, RecurringDraft draft) async {
    _check(draft.asOperation);
    final now = _clock();
    final id = _uuid.v4();
    final rule = draft.rule;
    await _db
        .into(_db.recurrences)
        .insert(
          RecurrencesCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            profileId: profileId,
            kind: draft.kind,
            amount: draft.amount,
            accountId: draft.accountId!,
            toAccountId: Value(draft.kind == OperationKind.transfer ? draft.toAccountId : null),
            categoryId: Value(draft.kind == OperationKind.transfer ? null : draft.categoryId),
            note: Value(draft.cleanNote),
            unit: rule.unit.repeat,
            every: Value(rule.interval),
            startsOn: dayKey(rule.start),
            endsOn: Value(rule.until == null ? null : dayKey(rule.until!)),
            dueFrom: dayKey(_later(rule.start, localDay(now))),
          ),
        );
    return id;
  }

  /// Change une récurrence. Si sa règle change (unité, fréquence, début), les
  /// échéances ne comptent plus qu'à partir d'aujourd'hui : celles de l'ancienne
  /// règle ne réapparaissent pas sous de nouvelles dates.
  Future<void> updateRecurring(String id, RecurringDraft draft) {
    _check(draft.asOperation);
    return _db.transaction(() async {
      final row = await (_db.select(_db.recurrences)..where((r) => r.id.equals(id))).getSingle();
      final rule = draft.rule;
      final ruleChanged =
          row.unit != rule.unit.repeat || row.every != rule.interval || row.startsOn != dayKey(rule.start);
      await (_db.update(_db.recurrences)..where((r) => r.id.equals(id))).write(
        RecurrencesCompanion(
          kind: Value(draft.kind),
          amount: Value(draft.amount),
          accountId: Value(draft.accountId!),
          toAccountId: Value(draft.kind == OperationKind.transfer ? draft.toAccountId : null),
          categoryId: Value(draft.kind == OperationKind.transfer ? null : draft.categoryId),
          note: Value(draft.cleanNote),
          unit: Value(rule.unit.repeat),
          every: Value(rule.interval),
          startsOn: Value(dayKey(rule.start)),
          endsOn: Value(rule.until == null ? null : dayKey(rule.until!)),
          dueFrom: ruleChanged ? Value(dayKey(localDay(_clock()))) : const Value.absent(),
          updatedAt: Value(_clock()),
        ),
      );
    });
  }

  /// Suppression douce : les opérations déjà réglées restent.
  Future<void> deleteRecurring(String id) {
    final now = _clock();
    return (_db.update(
      _db.recurrences,
    )..where((r) => r.id.equals(id))).write(RecurrencesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  Future<void> restoreRecurring(String id) {
    return (_db.update(_db.recurrences)..where((r) => r.id.equals(id))).write(
      RecurrencesCompanion(deletedAt: const Value(null), updatedAt: Value(_clock())),
    );
  }

  /// Passe une échéance sans rien enregistrer. Une échéance n'a qu'une ligne :
  /// passée, rétablie puis repassée, c'est la même.
  Future<void> skipDue(String profileId, Due due) {
    final now = _clock();
    return _db
        .into(_db.recurrenceSkips)
        .insert(
          RecurrenceSkipsCompanion.insert(
            id: _uuid.v4(),
            createdAt: now,
            updatedAt: now,
            profileId: profileId,
            recurrenceId: due.recurring.id,
            dueOn: dayKey(due.day),
          ),
          onConflict: DoUpdate(
            (_) => RecurrenceSkipsCompanion(deletedAt: const Value(null), updatedAt: Value(now)),
            target: [_db.recurrenceSkips.recurrenceId, _db.recurrenceSkips.dueOn],
          ),
        );
  }

  /// Annule [skipDue] (bouton « Annuler »).
  Future<void> unskipDue(Due due) {
    final now = _clock();
    return (_db.update(_db.recurrenceSkips)
          ..where((s) => s.recurrenceId.equals(due.recurring.id) & s.dueOn.equals(dayKey(due.day))))
        .write(RecurrenceSkipsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  // --------------------------------------------------------------- tontines

  /// Les tontines du profil, avec le solde de leur compte.
  Stream<List<Tontine>> watchTontines(String profileId) async* {
    yield await _tontines(profileId);
    final tables = <ResultSetImplementation<dynamic, dynamic>>[
      _db.tontines,
      _db.accounts,
      _db.operations,
      _db.recurrences,
    ];
    await for (final _ in _db.tableUpdates(TableUpdateQuery.onAllTables(tables))) {
      yield await _tontines(profileId);
    }
  }

  /// Crée une tontine : son compte, sa cotisation et sa main. Une tontine déjà
  /// commencée reçoit en solde de départ les tours d'avant aujourd'hui, que les
  /// récurrences ne réclameront pas. [notes] nomment les deux échéances dans
  /// « À valider » et dans la liste du mois.
  Future<String> createTontine(String profileId, TontineDraft draft, {required TontineNotes notes}) {
    _checkTontine(draft);
    return _db.transaction(() async {
      final now = _clock();
      final terms = draft.terms;
      final account = await createAccount(
        profileId,
        AccountDraft(name: draft.name, kind: AccountKind.tontine, openingBalance: terms.openingBalance(localDay(now))),
      );
      final contributionId = await createRecurring(profileId, _contributionOf(draft, account.id, notes));
      final handId = await createRecurring(profileId, _handOf(draft, account.id, notes));
      final id = _uuid.v4();
      await _db
          .into(_db.tontines)
          .insert(
            TontinesCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              profileId: profileId,
              accountId: account.id,
              contributionId: contributionId,
              handId: handId,
              members: terms.members,
              rank: terms.rank,
            ),
          );
      return id;
    });
  }

  /// Change une tontine. Le solde de départ de son compte ne bouge pas : il dit
  /// ce qui s'est passé avant qu'on la suive. Si le calendrier change, ses
  /// échéances repartent d'aujourd'hui (voir [updateRecurring]).
  Future<void> updateTontine(String id, TontineDraft draft, {required TontineNotes notes}) {
    _checkTontine(draft);
    return _db.transaction(() async {
      final row = await (_db.select(_db.tontines)..where((t) => t.id.equals(id))).getSingle();
      await (_db.update(_db.accounts)..where((a) => a.id.equals(row.accountId))).write(
        AccountsCompanion(name: Value(draft.name.trim()), updatedAt: Value(_clock())),
      );
      await updateRecurring(row.contributionId, _contributionOf(draft, row.accountId, notes));
      await updateRecurring(row.handId, _handOf(draft, row.accountId, notes));
      await (_db.update(_db.tontines)..where((t) => t.id.equals(id))).write(
        TontinesCompanion(
          members: Value(draft.terms.members),
          rank: Value(draft.terms.rank),
          updatedAt: Value(_clock()),
        ),
      );
    });
  }

  /// Arrête une tontine : plus aucune échéance. Son compte reste s'il a des
  /// opérations (son histoire et son solde comptent) ; sinon il part avec elle.
  Future<void> deleteTontine(String id) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.tontines)..where((t) => t.id.equals(id))).getSingle();
      final now = _clock();
      await (_db.update(
        _db.tontines,
      )..where((t) => t.id.equals(id))).write(TontinesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await deleteRecurring(row.contributionId);
      await deleteRecurring(row.handId);
      try {
        await deleteAccount(row.accountId);
      } on AccountInUseException {
        // Le compte garde ses opérations.
      }
    });
  }

  RecurringDraft _contributionOf(TontineDraft draft, String tontineAccountId, TontineNotes notes) => RecurringDraft(
    kind: OperationKind.transfer,
    amount: draft.terms.contribution,
    accountId: draft.accountId,
    toAccountId: tontineAccountId,
    note: notes.contribution(draft.name.trim()),
    rule: draft.terms.contributionRule,
  );

  RecurringDraft _handOf(TontineDraft draft, String tontineAccountId, TontineNotes notes) => RecurringDraft(
    kind: OperationKind.transfer,
    amount: draft.terms.pot,
    accountId: tontineAccountId,
    toAccountId: draft.accountId,
    note: notes.hand(draft.name.trim()),
    rule: draft.terms.handRule,
  );

  Future<List<Tontine>> _tontines(String profileId) async {
    final rows =
        await (_db.select(_db.tontines)
              ..where((t) => t.profileId.equals(profileId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    if (rows.isEmpty) return const [];
    final balances = {for (final a in await watchAccounts(profileId).first) a.id: a.balance};
    // Tous les comptes, supprimés compris : un nom reste lisible.
    final names = {
      for (final a in await (_db.select(_db.accounts)..where((a) => a.profileId.equals(profileId))).get()) a.id: a.name,
    };
    final contributions = {
      for (final r in await (_db.select(
        _db.recurrences,
      )..where((r) => r.id.isIn(rows.map((t) => t.contributionId)))).get())
        r.id: r,
    };
    return [
      for (final row in rows)
        if (contributions[row.contributionId] case final contribution?)
          Tontine(
            id: row.id,
            name: names[row.accountId] ?? '',
            accountId: row.accountId,
            balance: balances[row.accountId] ?? 0,
            terms: TontineTerms(
              contribution: contribution.amount,
              members: row.members,
              rank: row.rank,
              unit: contribution.unit.lucid,
              interval: contribution.every,
              firstRound: parseDayKey(contribution.startsOn),
            ),
            payAccountId: contribution.accountId,
            payAccountName: names[contribution.accountId] ?? '',
            contributionId: row.contributionId,
            handId: row.handId,
          ),
    ];
  }

  static void _checkTontine(TontineDraft draft) {
    final problem = draft.problem;
    if (problem != null) throw ArgumentError.value(problem, 'draft', 'Tontine incomplète');
  }

  // ------------------------------------------------------------------ prêts

  /// Les prêts du profil, avec le solde de leur compte.
  Stream<List<Loan>> watchLoans(String profileId) async* {
    yield await _loans(profileId);
    final tables = <ResultSetImplementation<dynamic, dynamic>>[_db.loans, _db.accounts, _db.operations];
    await for (final _ in _db.tableUpdates(TableUpdateQuery.onAllTables(tables))) {
      yield await _loans(profileId);
    }
  }

  /// Note un prêt : son compte, et le virement qui le fait (sauf prêt d'avant
  /// Palier, dont le reste dû devient le solde de départ du compte).
  Future<String> createLoan(String profileId, LoanDraft draft, {required LoanNotes notes}) {
    final problem = draft.problem;
    if (problem != null) throw ArgumentError.value(problem, 'draft', 'Prêt incomplet');
    return _db.transaction(() async {
      final now = _clock();
      final name = draft.name.trim();
      final account = await createAccount(
        profileId,
        AccountDraft(name: name, kind: AccountKind.loan, openingBalance: draft.beforePalier ? draft.signedAmount : 0),
      );
      if (!draft.beforePalier) {
        final lent = draft.direction == LoanDirection.lent;
        await addOperation(
          profileId,
          OperationDraft(
            kind: OperationKind.transfer,
            amount: draft.amount,
            accountId: lent ? draft.accountId : account.id,
            toAccountId: lent ? account.id : draft.accountId,
            note: lent ? notes.lent(name) : notes.borrowed(name),
            occurredAt: _onDay(draft.day, now),
          ),
        );
      }
      final id = _uuid.v4();
      await _db
          .into(_db.loans)
          .insert(
            LoansCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              profileId: profileId,
              accountId: account.id,
              direction: draft.direction,
              amount: draft.amount,
              payAccountId: draft.accountId!,
              startedOn: dayKey(draft.day),
            ),
          );
      return id;
    });
  }

  /// Note un remboursement, partiel ou complet : un virement en sens inverse
  /// du prêt. Jamais plus que le reste dû.
  Future<String> repayLoan(
    String profileId,
    Loan loan, {
    required int amount,
    required String? accountId,
    required DateTime day,
    required LoanNotes notes,
  }) {
    final problem = loan.repaymentProblem(amount, accountId);
    if (problem != null) throw ArgumentError.value(problem, 'amount', 'Remboursement impossible');
    final lent = loan.direction == LoanDirection.lent;
    return addOperation(
      profileId,
      OperationDraft(
        kind: OperationKind.transfer,
        amount: amount,
        accountId: lent ? loan.accountId : accountId,
        toAccountId: lent ? accountId : loan.accountId,
        note: notes.repayment(loan.name),
        occurredAt: _onDay(day, _clock()),
      ),
    );
  }

  Future<void> renameLoan(String id, String name) async {
    final row = await (_db.select(_db.loans)..where((l) => l.id.equals(id))).getSingle();
    await (_db.update(_db.accounts)..where((a) => a.id.equals(row.accountId))).write(
      AccountsCompanion(name: Value(name.trim()), updatedAt: Value(_clock())),
    );
  }

  /// Supprime un prêt noté par erreur, avec ses opérations : les comptes
  /// retrouvent leur solde d'avant.
  Future<void> deleteLoan(String id) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.loans)..where((l) => l.id.equals(id))).getSingle();
      final now = _clock();
      final gone = Value(now);
      await (_db.update(_db.operations)
            ..where((o) => (o.accountId.equals(row.accountId) | o.toAccountId.equals(row.accountId))))
          .write(OperationsCompanion(deletedAt: gone, updatedAt: Value(now)));
      await (_db.update(
        _db.loans,
      )..where((l) => l.id.equals(id))).write(LoansCompanion(deletedAt: gone, updatedAt: Value(now)));
      await (_db.update(
        _db.accounts,
      )..where((a) => a.id.equals(row.accountId))).write(AccountsCompanion(deletedAt: gone, updatedAt: Value(now)));
    });
  }

  /// Un instant du jour [day], à l'heure de [now] : la liste du mois garde l'ordre de saisie.
  static DateTime _onDay(DateTime day, DateTime now) {
    final local = now.toLocal();
    return DateTime(day.year, day.month, day.day, local.hour, local.minute);
  }

  Future<List<Loan>> _loans(String profileId) async {
    final rows =
        await (_db.select(_db.loans)
              ..where((l) => l.profileId.equals(profileId) & l.deletedAt.isNull())
              ..orderBy([(l) => OrderingTerm.asc(l.createdAt)]))
            .get();
    if (rows.isEmpty) return const [];
    final balances = {for (final a in await watchAccounts(profileId).first) a.id: a.balance};
    final names = {
      for (final a in await (_db.select(_db.accounts)..where((a) => a.profileId.equals(profileId))).get()) a.id: a.name,
    };
    return [
      for (final row in rows)
        Loan(
          id: row.id,
          name: names[row.accountId] ?? '',
          direction: row.direction,
          amount: row.amount,
          accountId: row.accountId,
          balance: balances[row.accountId] ?? 0,
          payAccountId: row.payAccountId,
          payAccountName: names[row.payAccountId] ?? '',
          startedOn: parseDayKey(row.startedOn),
        ),
    ];
  }

  Future<List<Recurring>> _recurrings(String profileId) async {
    final r = _db.recurrences;
    final from = _debitedAccount;
    final to = _creditedAccount;
    final category = _db.categories;
    final rows =
        await (_db.select(r).join([
                innerJoin(from, from.id.equalsExp(r.accountId)),
                leftOuterJoin(to, to.id.equalsExp(r.toAccountId)),
                leftOuterJoin(category, category.id.equalsExp(r.categoryId)),
              ])
              ..where(r.profileId.equals(profileId) & r.deletedAt.isNull())
              ..orderBy([OrderingTerm.asc(r.createdAt)]))
            .get();

    final settled = <String, Set<DateTime>>{};
    final o = _db.operations;
    final paid =
        await (_db.selectOnly(o)
              ..addColumns([o.recurrenceId, o.dueOn])
              ..where(
                o.profileId.equals(profileId) & o.deletedAt.isNull() & o.recurrenceId.isNotNull() & o.dueOn.isNotNull(),
              ))
            .get();
    for (final row in paid) {
      settled.putIfAbsent(row.read(o.recurrenceId)!, () => {}).add(parseDayKey(row.read(o.dueOn)!));
    }
    final skipped = await (_db.select(
      _db.recurrenceSkips,
    )..where((s) => s.profileId.equals(profileId) & s.deletedAt.isNull())).get();
    for (final skip in skipped) {
      settled.putIfAbsent(skip.recurrenceId, () => {}).add(parseDayKey(skip.dueOn));
    }

    return [
      for (final row in rows)
        () {
          final recurrence = row.readTable(r);
          final cat = row.readTableOrNull(category);
          return Recurring(
            id: recurrence.id,
            kind: recurrence.kind,
            amount: recurrence.amount,
            accountId: recurrence.accountId,
            accountName: row.readTable(from).name,
            toAccountId: recurrence.toAccountId,
            toAccountName: row.readTableOrNull(to)?.name,
            categoryId: recurrence.categoryId,
            categoryName: cat?.name,
            categoryIcon: cat?.icon,
            note: recurrence.note,
            rule: LucidRecurrence(
              unit: recurrence.unit.lucid,
              interval: recurrence.every,
              start: parseDayKey(recurrence.startsOn),
              until: recurrence.endsOn == null ? null : parseDayKey(recurrence.endsOn!),
            ),
            // Même règle pour les lignes créées avant elle (le 11/11) : jamais
            // d'échéance antérieure au jour de création.
            dueFrom: _later(parseDayKey(recurrence.dueFrom), localDay(recurrence.createdAt)),
            settled: Set.unmodifiable(settled[recurrence.id] ?? const <DateTime>{}),
          );
        }(),
    ];
  }

  // ------------------------------------------------------------------ outils

  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static void _check(OperationDraft draft) {
    final problem = draft.problem;
    if (problem != null) throw ArgumentError.value(problem, 'draft', 'Opération incomplète');
  }

  JoinedSelectStatement<HasResultSet, dynamic> _entriesQuery(Expression<bool> where) {
    final o = _db.operations;
    final from = _debitedAccount;
    final to = _creditedAccount;
    final category = _db.categories;
    // Pas de filtre sur la suppression des comptes et catégories jointes : une
    // opération ancienne garde le nom qu'elle avait.
    return _db.select(o).join([
        innerJoin(from, from.id.equalsExp(o.accountId)),
        leftOuterJoin(to, to.id.equalsExp(o.toAccountId)),
        leftOuterJoin(category, category.id.equalsExp(o.categoryId)),
      ])
      ..where(where)
      ..orderBy([OrderingTerm.desc(o.occurredAt), OrderingTerm.desc(o.createdAt)]);
  }

  OperationEntry _toEntry(TypedResult row) {
    final operation = row.readTable(_db.operations);
    final from = row.readTable(_debitedAccount);
    final to = row.readTableOrNull(_creditedAccount);
    final category = row.readTableOrNull(_db.categories);
    return OperationEntry(
      id: operation.id,
      kind: operation.kind,
      amount: operation.amount,
      occurredAt: operation.occurredAt,
      accountId: operation.accountId,
      accountName: from.name,
      toAccountId: operation.toAccountId,
      toAccountName: to?.name,
      categoryId: operation.categoryId,
      categoryName: category?.name,
      categoryIcon: category?.icon,
      note: operation.note,
      recurrenceId: operation.recurrenceId,
      dueOn: operation.dueOn == null ? null : parseDayKey(operation.dueOn!),
    );
  }

  Future<int> _lastPosition(TableInfo<Table, dynamic> table, String profileId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(MAX(position), -1) AS last FROM ${table.actualTableName} WHERE profile_id = ?',
          variables: [Variable.withString(profileId)],
          readsFrom: {table},
        )
        .getSingle();
    return row.read<int>('last');
  }

  static Account _accountOf(AccountRow row, int balance) => Account(
    id: row.id,
    name: row.name,
    kind: row.kind,
    openingBalance: row.openingBalance,
    balance: balance,
    goal: row.goal,
  );

  static Category _toCategory(CategoryRow row) => Category(id: row.id, name: row.name, kind: row.kind, icon: row.icon);
}
