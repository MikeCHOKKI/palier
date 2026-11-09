import 'package:drift/drift.dart';

/// Relit les dates d'un JSON (export chiffré) en UTC.
///
/// Le sérialiseur par défaut de drift rend une date locale : écrite en base, elle
/// devient un texte avec décalage (« +01:00 ») que SQLite compare mal aux dates
/// UTC (« Z ») de tout le reste de la base, ce qui fausse tris et filtres par mois.
class UtcValueSerializer extends ValueSerializer {
  const UtcValueSerializer();

  static const _defaults = ValueSerializer.defaults();

  @override
  T fromJson<T>(dynamic json) {
    final value = _defaults.fromJson<T>(json);
    return value is DateTime ? value.toUtc() as T : value;
  }

  @override
  dynamic toJson<T>(T value) => _defaults.toJson<T>(value);
}
