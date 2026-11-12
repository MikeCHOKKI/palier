import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidIntervalKind, LucidIntervalStep;

/// Un exercice d'un circuit : en répétitions ([reps]) ou en durée ([seconds]),
/// suivi d'un repos ([restSeconds], 0 pour enchaîner).
class CircuitExercise {
  const CircuitExercise({required this.name, this.reps, this.seconds, this.restSeconds = 30})
    : assert((reps == null) != (seconds == null), 'en répétitions ou en durée, pas les deux');

  final String name;
  final int? reps;
  final int? seconds;
  final int restSeconds;

  bool get isTimed => seconds != null;

  static const maxNameLength = 40;
  static const maxReps = 500;
  static const maxSeconds = 30 * 60;
  static const maxRestSeconds = 10 * 60;

  bool get isValid {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > maxNameLength) return false;
    if (restSeconds < 0 || restSeconds > maxRestSeconds) return false;
    if (reps case final count?) return count > 0 && count <= maxReps;
    return seconds! > 0 && seconds! <= maxSeconds;
  }

  @override
  bool operator ==(Object other) =>
      other is CircuitExercise &&
      other.name == name &&
      other.reps == reps &&
      other.seconds == seconds &&
      other.restSeconds == restSeconds;

  @override
  int get hashCode => Object.hash(name, reps, seconds, restSeconds);
}

/// Un circuit de renforcement composé par la personne : des exercices, répétés
/// sur plusieurs tours. Palier ne propose aucun exercice ni aucune charge.
class Circuit {
  const Circuit({
    required this.id,
    required this.name,
    required this.rounds,
    required this.roundRestSeconds,
    required this.exercises,
  });

  final String id;
  final String name;
  final int rounds;

  /// Repos entre deux tours, 0 pour enchaîner.
  final int roundRestSeconds;
  final List<CircuitExercise> exercises;

  CircuitDraft get draft =>
      CircuitDraft(name: name, rounds: rounds, roundRestSeconds: roundRestSeconds, exercises: exercises);
}

/// Un circuit à enregistrer.
class CircuitDraft {
  const CircuitDraft({required this.name, this.rounds = 3, this.roundRestSeconds = 60, this.exercises = const []});

  final String name;
  final int rounds;
  final int roundRestSeconds;
  final List<CircuitExercise> exercises;

  static const maxNameLength = 40;
  static const maxRounds = 20;
  static const maxExercises = 30;

  CircuitProblem? get problem {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > maxNameLength) return CircuitProblem.noName;
    if (rounds < 1 || rounds > maxRounds) return CircuitProblem.badRounds;
    if (roundRestSeconds < 0 || roundRestSeconds > CircuitExercise.maxRestSeconds) return CircuitProblem.badRest;
    if (exercises.isEmpty) return CircuitProblem.noExercise;
    if (exercises.length > maxExercises || exercises.any((e) => !e.isValid)) return CircuitProblem.badExercise;
    return null;
  }

  CircuitDraft copyWith({String? name, int? rounds, int? roundRestSeconds, List<CircuitExercise>? exercises}) =>
      CircuitDraft(
        name: name ?? this.name,
        rounds: rounds ?? this.rounds,
        roundRestSeconds: roundRestSeconds ?? this.roundRestSeconds,
        exercises: exercises ?? this.exercises,
      );
}

enum CircuitProblem { noName, badRounds, badRest, noExercise, badExercise }

/// Les étapes d'un circuit, prêtes pour le minuteur, avec le tour de chacune.
///
/// Tour après tour : chaque exercice, suivi de son repos, sauf après le dernier
/// exercice du tour, où vient le repos entre tours (jamais après le dernier tour).
class CircuitPlan {
  CircuitPlan._(this.steps, this.rounds);

  factory CircuitPlan.of(Circuit circuit, {required String restLabel}) {
    final steps = <LucidIntervalStep>[];
    final rounds = <int>[];
    void add(LucidIntervalStep step, int round) {
      steps.add(step);
      rounds.add(round);
    }

    for (var round = 1; round <= circuit.rounds; round++) {
      for (final (i, exercise) in circuit.exercises.indexed) {
        add(
          exercise.isTimed
              ? LucidIntervalStep.timed(exercise.name, Duration(seconds: exercise.seconds!))
              : LucidIntervalStep.counted(exercise.name, exercise.reps!),
          round,
        );
        final lastOfRound = i == circuit.exercises.length - 1;
        final rest = lastOfRound ? (round < circuit.rounds ? circuit.roundRestSeconds : 0) : exercise.restSeconds;
        if (rest > 0) {
          add(LucidIntervalStep.timed(restLabel, Duration(seconds: rest), kind: LucidIntervalKind.rest), round);
        }
      }
    }
    return CircuitPlan._(List.unmodifiable(steps), List.unmodifiable(rounds));
  }

  final List<LucidIntervalStep> steps;

  /// Le tour (à partir de 1) de chaque étape de [steps].
  final List<int> rounds;

  /// Durée connue d'avance : exercices en durée et repos. Les exercices en
  /// répétitions n'y sont pas, faute de savoir combien de temps ils prennent.
  Duration get timedTotal => steps.fold(Duration.zero, (sum, step) => sum + (step.duration ?? Duration.zero));
}
