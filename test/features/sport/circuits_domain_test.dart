import 'package:flutter_test/flutter_test.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart' show LucidIntervalKind;
import 'package:palier/features/sport/domain/circuits.dart';

void main() {
  const pushUps = CircuitExercise(name: 'Pompes', reps: 12, restSeconds: 20);
  const plank = CircuitExercise(name: 'Gainage', seconds: 40, restSeconds: 30);
  const squats = CircuitExercise(name: 'Squats', reps: 15, restSeconds: 0);

  Circuit circuit({int rounds = 2, int roundRest = 60, List<CircuitExercise> exercises = const [pushUps, plank]}) =>
      Circuit(id: 'c', name: 'Maison', rounds: rounds, roundRestSeconds: roundRest, exercises: exercises);

  group('plan', () {
    test('chaque exercice est suivi de son repos, et le dernier du tour du repos entre tours', () {
      final plan = CircuitPlan.of(circuit(), restLabel: 'Repos');
      expect(
        [for (final step in plan.steps) step.label],
        ['Pompes', 'Repos', 'Gainage', 'Repos', 'Pompes', 'Repos', 'Gainage'],
      );
      expect(plan.rounds, [1, 1, 1, 1, 2, 2, 2]);
      expect(plan.steps[0].reps, 12);
      expect(plan.steps[0].isTimed, isFalse);
      expect(plan.steps[2].duration, const Duration(seconds: 40));
      // Le repos entre tours remplace celui du dernier exercice.
      expect(plan.steps[3].duration, const Duration(seconds: 60));
      expect(plan.steps[3].kind, LucidIntervalKind.rest);
      // 20 + 40 + 60 + 20 + 40 : les pompes, en répétitions, n'ont pas de durée.
      expect(plan.timedTotal, const Duration(seconds: 180));
    });

    test('un repos nul est sauté, et le dernier tour finit sans repos', () {
      final plan = CircuitPlan.of(circuit(rounds: 1, exercises: const [squats, plank]), restLabel: 'Repos');
      expect([for (final step in plan.steps) step.label], ['Squats', 'Gainage']);
    });
  });

  group('brouillon', () {
    CircuitDraft draft({String name = 'Maison', int rounds = 3, List<CircuitExercise> exercises = const [pushUps]}) =>
        CircuitDraft(name: name, rounds: rounds, exercises: exercises);

    test('il faut un nom, des tours raisonnables et au moins un exercice valable', () {
      expect(draft().problem, isNull);
      expect(draft(name: '  ').problem, CircuitProblem.noName);
      expect(draft(rounds: 0).problem, CircuitProblem.badRounds);
      expect(draft(rounds: 21).problem, CircuitProblem.badRounds);
      expect(draft(exercises: const []).problem, CircuitProblem.noExercise);
      expect(draft(exercises: const [CircuitExercise(name: 'Pompes', reps: 0)]).problem, CircuitProblem.badExercise);
      expect(draft(exercises: const [CircuitExercise(name: '', seconds: 30)]).problem, CircuitProblem.badExercise);
      expect(
        draft(exercises: const [CircuitExercise(name: 'Gainage', seconds: 30, restSeconds: 601)]).problem,
        CircuitProblem.badExercise,
      );
    });
  });
}
