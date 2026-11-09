import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/database.dart';
import '../domain/expense_kinds.dart';
import '../domain/expenses.dart';
import '../domain/starter_kit.dart';

/// Un compte encore utilisé par des opérations ne se supprime pas : ses
/// opérations perdraient leur sens et les soldes deviendraient faux.
class AccountInUseException implements Exception {
  const AccountInUseException();
}

/// Comptes, catégories et opérations d'un profil.
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
    );
  }

  Future<void> updateAccount(String id, AccountDraft draft) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        name: Value(draft.name.trim()),
        kind: Value(draft.kind),
        openingBalance: Value(draft.openingBalance),
        updatedAt: Value(_clock()),
      ),
    );
  }

  /// Supprime un compte sans opération ; lève [AccountInUseException] sinon.
  Future<void> deleteAccount(String id) {
    return _db.transaction(() async {
      final used =
          await (_db.select(_db.operations)
                ..where((o) => (o.accountId.equals(id) | o.toAccountId.equals(id)) & o.deletedAt.isNull())
                ..limit(1))
              .getSingleOrNull();
      if (used != null) throw const AccountInUseException();
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

  Future<String> addOperation(String profileId, OperationDraft draft) async {
    _check(draft);
    final now = _clock();
    final id = _uuid.v4();
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
          ),
        );
    return id;
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

  // ------------------------------------------------------------------ outils

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

  static Account _accountOf(AccountRow row, int balance) =>
      Account(id: row.id, name: row.name, kind: row.kind, openingBalance: row.openingBalance, balance: balance);

  static Category _toCategory(CategoryRow row) => Category(id: row.id, name: row.name, kind: row.kind, icon: row.icon);
}
