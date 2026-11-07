// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 40),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accentMeta = const VerificationMeta('accent');
  @override
  late final GeneratedColumn<String> accent = GeneratedColumn<String>(
    'accent',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('XOF'),
  );
  static const VerificationMeta _isMinorMeta = const VerificationMeta('isMinor');
  @override
  late final GeneratedColumn<bool> isMinor = GeneratedColumn<bool>(
    'is_minor',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_minor" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _expensesEnabledMeta = const VerificationMeta('expensesEnabled');
  @override
  late final GeneratedColumn<bool> expensesEnabled = GeneratedColumn<bool>(
    'expenses_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("expenses_enabled" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sportEnabledMeta = const VerificationMeta('sportEnabled');
  @override
  late final GeneratedColumn<bool> sportEnabled = GeneratedColumn<bool>(
    'sport_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("sport_enabled" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta('pinHash');
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinSaltMeta = const VerificationMeta('pinSalt');
  @override
  late final GeneratedColumn<String> pinSalt = GeneratedColumn<String>(
    'pin_salt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinIterationsMeta = const VerificationMeta('pinIterations');
  @override
  late final GeneratedColumn<int> pinIterations = GeneratedColumn<int>(
    'pin_iterations',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _biometricEnabledMeta = const VerificationMeta('biometricEnabled');
  @override
  late final GeneratedColumn<bool> biometricEnabled = GeneratedColumn<bool>(
    'biometric_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("biometric_enabled" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _failedPinAttemptsMeta = const VerificationMeta('failedPinAttempts');
  @override
  late final GeneratedColumn<int> failedPinAttempts = GeneratedColumn<int>(
    'failed_pin_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lockedUntilMeta = const VerificationMeta('lockedUntil');
  @override
  late final GeneratedColumn<DateTime> lockedUntil = GeneratedColumn<DateTime>(
    'locked_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    name,
    accent,
    currency,
    isMinor,
    expensesEnabled,
    sportEnabled,
    pinHash,
    pinSalt,
    pinIterations,
    biometricEnabled,
    failedPinAttempts,
    lockedUntil,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(Insertable<ProfileRow> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta, deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('accent')) {
      context.handle(_accentMeta, accent.isAcceptableOrUnknown(data['accent']!, _accentMeta));
    } else if (isInserting) {
      context.missing(_accentMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta, currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('is_minor')) {
      context.handle(_isMinorMeta, isMinor.isAcceptableOrUnknown(data['is_minor']!, _isMinorMeta));
    }
    if (data.containsKey('expenses_enabled')) {
      context.handle(
        _expensesEnabledMeta,
        expensesEnabled.isAcceptableOrUnknown(data['expenses_enabled']!, _expensesEnabledMeta),
      );
    }
    if (data.containsKey('sport_enabled')) {
      context.handle(_sportEnabledMeta, sportEnabled.isAcceptableOrUnknown(data['sport_enabled']!, _sportEnabledMeta));
    }
    if (data.containsKey('pin_hash')) {
      context.handle(_pinHashMeta, pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta));
    }
    if (data.containsKey('pin_salt')) {
      context.handle(_pinSaltMeta, pinSalt.isAcceptableOrUnknown(data['pin_salt']!, _pinSaltMeta));
    }
    if (data.containsKey('pin_iterations')) {
      context.handle(
        _pinIterationsMeta,
        pinIterations.isAcceptableOrUnknown(data['pin_iterations']!, _pinIterationsMeta),
      );
    }
    if (data.containsKey('biometric_enabled')) {
      context.handle(
        _biometricEnabledMeta,
        biometricEnabled.isAcceptableOrUnknown(data['biometric_enabled']!, _biometricEnabledMeta),
      );
    }
    if (data.containsKey('failed_pin_attempts')) {
      context.handle(
        _failedPinAttemptsMeta,
        failedPinAttempts.isAcceptableOrUnknown(data['failed_pin_attempts']!, _failedPinAttemptsMeta),
      );
    }
    if (data.containsKey('locked_until')) {
      context.handle(_lockedUntilMeta, lockedUntil.isAcceptableOrUnknown(data['locked_until']!, _lockedUntilMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      accent: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}accent'])!,
      currency: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      isMinor: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_minor'])!,
      expensesEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}expenses_enabled'],
      )!,
      sportEnabled: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}sport_enabled'])!,
      pinHash: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}pin_hash']),
      pinSalt: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}pin_salt']),
      pinIterations: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}pin_iterations']),
      biometricEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}biometric_enabled'],
      )!,
      failedPinAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_pin_attempts'],
      )!,
      lockedUntil: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}locked_until']),
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String name;
  final String accent;
  final String currency;

  /// Profil d'enfant : pas d'objectif de poids, de calories ni de mensurations.
  final bool isMinor;
  final bool expensesEnabled;
  final bool sportEnabled;

  /// Code du profil : empreinte PBKDF2, jamais le code lui-même.
  final String? pinHash;
  final String? pinSalt;
  final int? pinIterations;
  final bool biometricEnabled;

  /// Essais de code manqués d'affilée, et fin du blocage qui en découle.
  final int failedPinAttempts;
  final DateTime? lockedUntil;
  const ProfileRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.name,
    required this.accent,
    required this.currency,
    required this.isMinor,
    required this.expensesEnabled,
    required this.sportEnabled,
    this.pinHash,
    this.pinSalt,
    this.pinIterations,
    required this.biometricEnabled,
    required this.failedPinAttempts,
    this.lockedUntil,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['name'] = Variable<String>(name);
    map['accent'] = Variable<String>(accent);
    map['currency'] = Variable<String>(currency);
    map['is_minor'] = Variable<bool>(isMinor);
    map['expenses_enabled'] = Variable<bool>(expensesEnabled);
    map['sport_enabled'] = Variable<bool>(sportEnabled);
    if (!nullToAbsent || pinHash != null) {
      map['pin_hash'] = Variable<String>(pinHash);
    }
    if (!nullToAbsent || pinSalt != null) {
      map['pin_salt'] = Variable<String>(pinSalt);
    }
    if (!nullToAbsent || pinIterations != null) {
      map['pin_iterations'] = Variable<int>(pinIterations);
    }
    map['biometric_enabled'] = Variable<bool>(biometricEnabled);
    map['failed_pin_attempts'] = Variable<int>(failedPinAttempts);
    if (!nullToAbsent || lockedUntil != null) {
      map['locked_until'] = Variable<DateTime>(lockedUntil);
    }
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
      name: Value(name),
      accent: Value(accent),
      currency: Value(currency),
      isMinor: Value(isMinor),
      expensesEnabled: Value(expensesEnabled),
      sportEnabled: Value(sportEnabled),
      pinHash: pinHash == null && nullToAbsent ? const Value.absent() : Value(pinHash),
      pinSalt: pinSalt == null && nullToAbsent ? const Value.absent() : Value(pinSalt),
      pinIterations: pinIterations == null && nullToAbsent ? const Value.absent() : Value(pinIterations),
      biometricEnabled: Value(biometricEnabled),
      failedPinAttempts: Value(failedPinAttempts),
      lockedUntil: lockedUntil == null && nullToAbsent ? const Value.absent() : Value(lockedUntil),
    );
  }

  factory ProfileRow.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      name: serializer.fromJson<String>(json['name']),
      accent: serializer.fromJson<String>(json['accent']),
      currency: serializer.fromJson<String>(json['currency']),
      isMinor: serializer.fromJson<bool>(json['isMinor']),
      expensesEnabled: serializer.fromJson<bool>(json['expensesEnabled']),
      sportEnabled: serializer.fromJson<bool>(json['sportEnabled']),
      pinHash: serializer.fromJson<String?>(json['pinHash']),
      pinSalt: serializer.fromJson<String?>(json['pinSalt']),
      pinIterations: serializer.fromJson<int?>(json['pinIterations']),
      biometricEnabled: serializer.fromJson<bool>(json['biometricEnabled']),
      failedPinAttempts: serializer.fromJson<int>(json['failedPinAttempts']),
      lockedUntil: serializer.fromJson<DateTime?>(json['lockedUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'name': serializer.toJson<String>(name),
      'accent': serializer.toJson<String>(accent),
      'currency': serializer.toJson<String>(currency),
      'isMinor': serializer.toJson<bool>(isMinor),
      'expensesEnabled': serializer.toJson<bool>(expensesEnabled),
      'sportEnabled': serializer.toJson<bool>(sportEnabled),
      'pinHash': serializer.toJson<String?>(pinHash),
      'pinSalt': serializer.toJson<String?>(pinSalt),
      'pinIterations': serializer.toJson<int?>(pinIterations),
      'biometricEnabled': serializer.toJson<bool>(biometricEnabled),
      'failedPinAttempts': serializer.toJson<int>(failedPinAttempts),
      'lockedUntil': serializer.toJson<DateTime?>(lockedUntil),
    };
  }

  ProfileRow copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? name,
    String? accent,
    String? currency,
    bool? isMinor,
    bool? expensesEnabled,
    bool? sportEnabled,
    Value<String?> pinHash = const Value.absent(),
    Value<String?> pinSalt = const Value.absent(),
    Value<int?> pinIterations = const Value.absent(),
    bool? biometricEnabled,
    int? failedPinAttempts,
    Value<DateTime?> lockedUntil = const Value.absent(),
  }) => ProfileRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    name: name ?? this.name,
    accent: accent ?? this.accent,
    currency: currency ?? this.currency,
    isMinor: isMinor ?? this.isMinor,
    expensesEnabled: expensesEnabled ?? this.expensesEnabled,
    sportEnabled: sportEnabled ?? this.sportEnabled,
    pinHash: pinHash.present ? pinHash.value : this.pinHash,
    pinSalt: pinSalt.present ? pinSalt.value : this.pinSalt,
    pinIterations: pinIterations.present ? pinIterations.value : this.pinIterations,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
    lockedUntil: lockedUntil.present ? lockedUntil.value : this.lockedUntil,
  );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      name: data.name.present ? data.name.value : this.name,
      accent: data.accent.present ? data.accent.value : this.accent,
      currency: data.currency.present ? data.currency.value : this.currency,
      isMinor: data.isMinor.present ? data.isMinor.value : this.isMinor,
      expensesEnabled: data.expensesEnabled.present ? data.expensesEnabled.value : this.expensesEnabled,
      sportEnabled: data.sportEnabled.present ? data.sportEnabled.value : this.sportEnabled,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      pinSalt: data.pinSalt.present ? data.pinSalt.value : this.pinSalt,
      pinIterations: data.pinIterations.present ? data.pinIterations.value : this.pinIterations,
      biometricEnabled: data.biometricEnabled.present ? data.biometricEnabled.value : this.biometricEnabled,
      failedPinAttempts: data.failedPinAttempts.present ? data.failedPinAttempts.value : this.failedPinAttempts,
      lockedUntil: data.lockedUntil.present ? data.lockedUntil.value : this.lockedUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('accent: $accent, ')
          ..write('currency: $currency, ')
          ..write('isMinor: $isMinor, ')
          ..write('expensesEnabled: $expensesEnabled, ')
          ..write('sportEnabled: $sportEnabled, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinSalt: $pinSalt, ')
          ..write('pinIterations: $pinIterations, ')
          ..write('biometricEnabled: $biometricEnabled, ')
          ..write('failedPinAttempts: $failedPinAttempts, ')
          ..write('lockedUntil: $lockedUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    name,
    accent,
    currency,
    isMinor,
    expensesEnabled,
    sportEnabled,
    pinHash,
    pinSalt,
    pinIterations,
    biometricEnabled,
    failedPinAttempts,
    lockedUntil,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.name == this.name &&
          other.accent == this.accent &&
          other.currency == this.currency &&
          other.isMinor == this.isMinor &&
          other.expensesEnabled == this.expensesEnabled &&
          other.sportEnabled == this.sportEnabled &&
          other.pinHash == this.pinHash &&
          other.pinSalt == this.pinSalt &&
          other.pinIterations == this.pinIterations &&
          other.biometricEnabled == this.biometricEnabled &&
          other.failedPinAttempts == this.failedPinAttempts &&
          other.lockedUntil == this.lockedUntil);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> name;
  final Value<String> accent;
  final Value<String> currency;
  final Value<bool> isMinor;
  final Value<bool> expensesEnabled;
  final Value<bool> sportEnabled;
  final Value<String?> pinHash;
  final Value<String?> pinSalt;
  final Value<int?> pinIterations;
  final Value<bool> biometricEnabled;
  final Value<int> failedPinAttempts;
  final Value<DateTime?> lockedUntil;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.accent = const Value.absent(),
    this.currency = const Value.absent(),
    this.isMinor = const Value.absent(),
    this.expensesEnabled = const Value.absent(),
    this.sportEnabled = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.pinSalt = const Value.absent(),
    this.pinIterations = const Value.absent(),
    this.biometricEnabled = const Value.absent(),
    this.failedPinAttempts = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    required String name,
    required String accent,
    this.currency = const Value.absent(),
    this.isMinor = const Value.absent(),
    this.expensesEnabled = const Value.absent(),
    this.sportEnabled = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.pinSalt = const Value.absent(),
    this.pinIterations = const Value.absent(),
    this.biometricEnabled = const Value.absent(),
    this.failedPinAttempts = const Value.absent(),
    this.lockedUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       name = Value(name),
       accent = Value(accent);
  static Insertable<ProfileRow> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? name,
    Expression<String>? accent,
    Expression<String>? currency,
    Expression<bool>? isMinor,
    Expression<bool>? expensesEnabled,
    Expression<bool>? sportEnabled,
    Expression<String>? pinHash,
    Expression<String>? pinSalt,
    Expression<int>? pinIterations,
    Expression<bool>? biometricEnabled,
    Expression<int>? failedPinAttempts,
    Expression<DateTime>? lockedUntil,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (name != null) 'name': name,
      if (accent != null) 'accent': accent,
      if (currency != null) 'currency': currency,
      if (isMinor != null) 'is_minor': isMinor,
      if (expensesEnabled != null) 'expenses_enabled': expensesEnabled,
      if (sportEnabled != null) 'sport_enabled': sportEnabled,
      if (pinHash != null) 'pin_hash': pinHash,
      if (pinSalt != null) 'pin_salt': pinSalt,
      if (pinIterations != null) 'pin_iterations': pinIterations,
      if (biometricEnabled != null) 'biometric_enabled': biometricEnabled,
      if (failedPinAttempts != null) 'failed_pin_attempts': failedPinAttempts,
      if (lockedUntil != null) 'locked_until': lockedUntil,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? name,
    Value<String>? accent,
    Value<String>? currency,
    Value<bool>? isMinor,
    Value<bool>? expensesEnabled,
    Value<bool>? sportEnabled,
    Value<String?>? pinHash,
    Value<String?>? pinSalt,
    Value<int?>? pinIterations,
    Value<bool>? biometricEnabled,
    Value<int>? failedPinAttempts,
    Value<DateTime?>? lockedUntil,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      name: name ?? this.name,
      accent: accent ?? this.accent,
      currency: currency ?? this.currency,
      isMinor: isMinor ?? this.isMinor,
      expensesEnabled: expensesEnabled ?? this.expensesEnabled,
      sportEnabled: sportEnabled ?? this.sportEnabled,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      pinIterations: pinIterations ?? this.pinIterations,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (accent.present) {
      map['accent'] = Variable<String>(accent.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (isMinor.present) {
      map['is_minor'] = Variable<bool>(isMinor.value);
    }
    if (expensesEnabled.present) {
      map['expenses_enabled'] = Variable<bool>(expensesEnabled.value);
    }
    if (sportEnabled.present) {
      map['sport_enabled'] = Variable<bool>(sportEnabled.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (pinSalt.present) {
      map['pin_salt'] = Variable<String>(pinSalt.value);
    }
    if (pinIterations.present) {
      map['pin_iterations'] = Variable<int>(pinIterations.value);
    }
    if (biometricEnabled.present) {
      map['biometric_enabled'] = Variable<bool>(biometricEnabled.value);
    }
    if (failedPinAttempts.present) {
      map['failed_pin_attempts'] = Variable<int>(failedPinAttempts.value);
    }
    if (lockedUntil.present) {
      map['locked_until'] = Variable<DateTime>(lockedUntil.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('accent: $accent, ')
          ..write('currency: $currency, ')
          ..write('isMinor: $isMinor, ')
          ..write('expensesEnabled: $expensesEnabled, ')
          ..write('sportEnabled: $sportEnabled, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinSalt: $pinSalt, ')
          ..write('pinIterations: $pinIterations, ')
          ..write('biometricEnabled: $biometricEnabled, ')
          ..write('failedPinAttempts: $failedPinAttempts, ')
          ..write('lockedUntil: $lockedUntil, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$PalierDatabase extends GeneratedDatabase {
  _$PalierDatabase(QueryExecutor e) : super(e);
  $PalierDatabaseManager get managers => $PalierDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [profiles];
  @override
  DriftDatabaseOptions get options => const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  required String name,
  required String accent,
  Value<String> currency,
  Value<bool> isMinor,
  Value<bool> expensesEnabled,
  Value<bool> sportEnabled,
  Value<String?> pinHash,
  Value<String?> pinSalt,
  Value<int?> pinIterations,
  Value<bool> biometricEnabled,
  Value<int> failedPinAttempts,
  Value<DateTime?> lockedUntil,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String> name,
  Value<String> accent,
  Value<String> currency,
  Value<bool> isMinor,
  Value<bool> expensesEnabled,
  Value<bool> sportEnabled,
  Value<String?> pinHash,
  Value<String?> pinSalt,
  Value<int?> pinIterations,
  Value<bool> biometricEnabled,
  Value<int> failedPinAttempts,
  Value<DateTime?> lockedUntil,
  Value<int> rowid,
});

class $$ProfilesTableFilterComposer extends Composer<_$PalierDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accent =>
      $composableBuilder(column: $table.accent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMinor =>
      $composableBuilder(column: $table.isMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get expensesEnabled =>
      $composableBuilder(column: $table.expensesEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get sportEnabled =>
      $composableBuilder(column: $table.sportEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pinSalt =>
      $composableBuilder(column: $table.pinSalt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pinIterations =>
      $composableBuilder(column: $table.pinIterations, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get biometricEnabled =>
      $composableBuilder(column: $table.biometricEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get failedPinAttempts =>
      $composableBuilder(column: $table.failedPinAttempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lockedUntil =>
      $composableBuilder(column: $table.lockedUntil, builder: (column) => ColumnFilters(column));
}

class $$ProfilesTableOrderingComposer extends Composer<_$PalierDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accent =>
      $composableBuilder(column: $table.accent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMinor =>
      $composableBuilder(column: $table.isMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get expensesEnabled =>
      $composableBuilder(column: $table.expensesEnabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get sportEnabled =>
      $composableBuilder(column: $table.sportEnabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pinSalt =>
      $composableBuilder(column: $table.pinSalt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pinIterations =>
      $composableBuilder(column: $table.pinIterations, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get biometricEnabled =>
      $composableBuilder(column: $table.biometricEnabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get failedPinAttempts =>
      $composableBuilder(column: $table.failedPinAttempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lockedUntil =>
      $composableBuilder(column: $table.lockedUntil, builder: (column) => ColumnOrderings(column));
}

class $$ProfilesTableAnnotationComposer extends Composer<_$PalierDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt => $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get accent => $composableBuilder(column: $table.accent, builder: (column) => column);

  GeneratedColumn<String> get currency => $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<bool> get isMinor => $composableBuilder(column: $table.isMinor, builder: (column) => column);

  GeneratedColumn<bool> get expensesEnabled =>
      $composableBuilder(column: $table.expensesEnabled, builder: (column) => column);

  GeneratedColumn<bool> get sportEnabled =>
      $composableBuilder(column: $table.sportEnabled, builder: (column) => column);

  GeneratedColumn<String> get pinHash => $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumn<String> get pinSalt => $composableBuilder(column: $table.pinSalt, builder: (column) => column);

  GeneratedColumn<int> get pinIterations =>
      $composableBuilder(column: $table.pinIterations, builder: (column) => column);

  GeneratedColumn<bool> get biometricEnabled =>
      $composableBuilder(column: $table.biometricEnabled, builder: (column) => column);

  GeneratedColumn<int> get failedPinAttempts =>
      $composableBuilder(column: $table.failedPinAttempts, builder: (column) => column);

  GeneratedColumn<DateTime> get lockedUntil =>
      $composableBuilder(column: $table.lockedUntil, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$PalierDatabase,
          $ProfilesTable,
          ProfileRow,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (ProfileRow, BaseReferences<_$PalierDatabase, $ProfilesTable, ProfileRow>),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$PalierDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> accent = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<bool> isMinor = const Value.absent(),
                Value<bool> expensesEnabled = const Value.absent(),
                Value<bool> sportEnabled = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<String?> pinSalt = const Value.absent(),
                Value<int?> pinIterations = const Value.absent(),
                Value<bool> biometricEnabled = const Value.absent(),
                Value<int> failedPinAttempts = const Value.absent(),
                Value<DateTime?> lockedUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                accent: accent,
                currency: currency,
                isMinor: isMinor,
                expensesEnabled: expensesEnabled,
                sportEnabled: sportEnabled,
                pinHash: pinHash,
                pinSalt: pinSalt,
                pinIterations: pinIterations,
                biometricEnabled: biometricEnabled,
                failedPinAttempts: failedPinAttempts,
                lockedUntil: lockedUntil,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                required String name,
                required String accent,
                Value<String> currency = const Value.absent(),
                Value<bool> isMinor = const Value.absent(),
                Value<bool> expensesEnabled = const Value.absent(),
                Value<bool> sportEnabled = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<String?> pinSalt = const Value.absent(),
                Value<int?> pinIterations = const Value.absent(),
                Value<bool> biometricEnabled = const Value.absent(),
                Value<int> failedPinAttempts = const Value.absent(),
                Value<DateTime?> lockedUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                accent: accent,
                currency: currency,
                isMinor: isMinor,
                expensesEnabled: expensesEnabled,
                sportEnabled: sportEnabled,
                pinHash: pinHash,
                pinSalt: pinSalt,
                pinIterations: pinIterations,
                biometricEnabled: biometricEnabled,
                failedPinAttempts: failedPinAttempts,
                lockedUntil: lockedUntil,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfilesTable, ProfileRow>(table),
                  BaseReferences<_$PalierDatabase, $ProfilesTable, ProfileRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$PalierDatabase,
      $ProfilesTable,
      ProfileRow,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (ProfileRow, BaseReferences<_$PalierDatabase, $ProfilesTable, ProfileRow>),
      ProfileRow,
      PrefetchHooks Function()
    >;

class $PalierDatabaseManager {
  final _$PalierDatabase _db;
  $PalierDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles => $$ProfilesTableTableManager(_db, _db.profiles);
}
