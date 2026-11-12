import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucid_core_flutter/lucid_core_flutter.dart'
    show
        LucidButton,
        LucidButtonVariant,
        LucidCountdownRing,
        LucidIntervalController,
        LucidIntervalKind,
        LucidIntervalStatus;
import 'package:material_ui/material_ui.dart';

import '../../../app/palier_snack.dart';
import '../../../app/providers.dart';
import '../../../app/theme/palier_theme.dart';
import '../../../app/theme/palier_tokens.dart';
import '../../../core/platform/screen_awake.dart';
import '../../../core/ui/choice_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/circuits.dart';
import '../domain/sport.dart';
import 'circuit_form_screen.dart' show exerciseSummary;
import 'sport_visuals.dart';

/// « 1:05 ».
String _clock(Duration duration) {
  final seconds = duration.inMilliseconds <= 0 ? 0 : (duration.inMilliseconds / 1000).ceil();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Une séance guidée : le circuit déroulé étape par étape, écran allumé, une
/// vibration à chaque changement. À la fin (ou à l'arrêt), la séance peut
/// rejoindre le journal comme une séance de renforcement.
class CircuitPlayerScreen extends ConsumerStatefulWidget {
  const CircuitPlayerScreen({super.key, required this.circuitId});

  final String circuitId;

  @override
  ConsumerState<CircuitPlayerScreen> createState() => _CircuitPlayerScreenState();
}

class _CircuitPlayerScreenState extends ConsumerState<CircuitPlayerScreen> {
  Circuit? _circuit;
  bool _loading = true;
  CircuitPlan? _plan;
  LucidIntervalController? _controller;
  DateTime? _startedAt;
  WorkoutEffort? _effort;
  bool _saving = false;

  /// Dernière seconde annoncée par une petite vibration (3, 2, 1).
  int? _lastBeep;

  /// Lu une fois : `ref` ne sert plus dans [dispose].
  late final ScreenAwake _screen = ref.read(screenAwakeProvider);

  @override
  void initState() {
    super.initState();
    _screen;
    _load();
  }

  Future<void> _load() async {
    final circuit = await ref.read(sportRepositoryProvider).findCircuit(widget.circuitId);
    if (!mounted) return;
    setState(() {
      _circuit = circuit;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    // L'écran reprend son extinction habituelle.
    _screen.keepOn(false);
    super.dispose();
  }

  void _start(Circuit circuit) {
    final l10n = AppLocalizations.of(context);
    final clock = ref.read(clockProvider);
    final plan = CircuitPlan.of(circuit, restLabel: l10n.playerRest);
    final controller = LucidIntervalController(
      steps: plan.steps,
      clock: clock,
      onStep: (index) {
        _lastBeep = null;
        final rest = index < plan.steps.length && plan.steps[index].kind == LucidIntervalKind.rest;
        rest ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
        if (index >= plan.steps.length) _screen.keepOn(false);
      },
    )..addListener(_onTick);
    setState(() {
      _plan = plan;
      _controller = controller;
      _startedAt = clock();
    });
    _screen.keepOn(true);
    controller.start();
  }

  void _onTick() {
    final remaining = _controller?.remaining;
    if (remaining != null && _controller!.status == LucidIntervalStatus.running) {
      final seconds = (remaining.inMilliseconds / 1000).ceil();
      if (seconds >= 1 && seconds <= 3 && seconds != _lastBeep) {
        _lastBeep = seconds;
        HapticFeedback.selectionClick();
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _save({WorkoutEffort? effort}) async {
    final controller = _controller!;
    final circuit = _circuit!;
    final seconds = controller.elapsed.inSeconds;
    if (seconds <= 0) {
      context.pop();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(sportRepositoryProvider)
          .createWorkout(
            ref.read(activeProfileProvider)!.id,
            WorkoutDraft(
              activity: WorkoutActivity.strength,
              occurredAt: _startedAt!,
              durationSeconds: seconds.clamp(1, WorkoutDraft.maxDurationSeconds),
              effort: effort,
              note: circuit.name,
              circuitId: circuit.id,
            ),
          );
      if (!mounted) return;
      context.pop();
      PalierSnack.done(messenger, l10n.workoutSaved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Fermer en cours de séance : pause, puis on demande quoi faire de ce qui est fait.
  Future<void> _quit() async {
    final controller = _controller;
    if (controller == null || controller.isFinished) {
      context.pop();
      return;
    }
    final wasRunning = controller.status == LucidIntervalStatus.running;
    controller.pause();
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.playerQuitTitle),
        content: Text(l10n.playerQuitBody),
        actionsOverflowDirection: VerticalDirection.up,
        actionsOverflowButtonSpacing: PalierSpace.xs,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'continuer'), child: Text(l10n.playerQuitContinue)),
          TextButton(onPressed: () => Navigator.pop(context, 'abandonner'), child: Text(l10n.playerQuitDiscard)),
          TextButton(onPressed: () => Navigator.pop(context, 'garder'), child: Text(l10n.playerQuitSave)),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'garder':
        await _save();
      case 'abandonner':
        context.pop();
      default:
        if (wasRunning) controller.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final circuit = _circuit;
    final controller = _controller;

    final Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (circuit == null) {
      body = Center(child: Text(l10n.circuitNotFound, style: Theme.of(context).textTheme.bodyLarge));
    } else if (controller == null) {
      body = _Ready(circuit: circuit, onStart: () => _start(circuit));
    } else if (controller.isFinished) {
      body = _Finished(
        elapsed: controller.elapsed,
        effort: _effort,
        saving: _saving,
        onEffort: (effort) => setState(() => _effort = effort == _effort ? null : effort),
        onSave: () => _save(effort: _effort),
        onDiscard: () => context.pop(),
      );
    } else {
      body = _Running(controller: controller, plan: _plan!, rounds: circuit.rounds);
    }

    return PopScope(
      // En cours de séance, le geste retour passe par la même question que la croix.
      canPop: controller == null || controller.isFinished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: controller == null || controller.isFinished
                ? MaterialLocalizations.of(context).closeButtonTooltip
                : l10n.playerQuit,
            onPressed: _quit,
          ),
          title: Text(circuit?.name ?? ''),
        ),
        body: SafeArea(top: false, child: body),
      ),
    );
  }
}

/// Avant de commencer : les exercices du circuit, puis « Commencer ».
class _Ready extends StatelessWidget {
  const _Ready({required this.circuit, required this.onStart});

  final Circuit circuit;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.md, PalierSpace.page, PalierSpace.md),
            children: [
              Text(l10n.playerReady, style: text.headlineMedium),
              const SizedBox(height: PalierSpace.sm),
              Text(
                [l10n.circuitRounds(circuit.rounds), l10n.circuitExerciseCount(circuit.exercises.length)].join(' · '),
                style: manrope(size: 15, weight: FontWeight.w600, color: PalierColors.textMid),
              ),
              const SizedBox(height: PalierSpace.lg),
              for (final (i, exercise) in circuit.exercises.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: PalierSpace.md),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: PalierColors.indigo),
                        child: Text('${i + 1}', style: manrope(size: 14, weight: FontWeight.w700)),
                      ),
                      const SizedBox(width: PalierSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(exercise.name, style: manrope(size: 16, weight: FontWeight.w600)),
                            Text(
                              exerciseSummary(l10n, exercise),
                              style: manrope(size: 13, weight: FontWeight.w500, color: PalierColors.textLow),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: PalierSpace.sm),
              Text(
                l10n.playerReadyBody,
                style: manrope(size: 14, weight: FontWeight.w500, color: PalierColors.textMid),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, 0, PalierSpace.page, PalierSpace.lg),
          child: LucidButton(label: l10n.playerStart, expand: true, onPressed: onStart),
        ),
      ],
    );
  }
}

/// La séance en cours : le tour, l'anneau (décompte ou répétitions), l'étape suivante, les commandes.
class _Running extends StatelessWidget {
  const _Running({required this.controller, required this.plan, required this.rounds});

  final LucidIntervalController controller;
  final CircuitPlan plan;
  final int rounds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;
    final step = controller.current;
    final rest = step.kind == LucidIntervalKind.rest;
    final paused = controller.status == LucidIntervalStatus.paused;
    final remaining = controller.remaining;
    final next = controller.next;
    final round = plan.rounds[controller.index];
    final ringColor = rest ? PalierColors.steel : accent;

    final Widget center;
    final String semanticValue;
    if (remaining != null) {
      center = Text(
        _clock(remaining),
        style: text.displaySmall!.copyWith(fontSize: 56, fontFeatures: const [FontFeature.tabularFigures()]),
      );
      semanticValue = l10n.playerSecondsLeft((remaining.inMilliseconds / 1000).ceil());
    } else {
      center = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${step.reps}', style: text.displaySmall!.copyWith(fontSize: 64)),
          Text(
            l10n.exerciseModeReps.toLowerCase(),
            style: manrope(size: 15, weight: FontWeight.w600, color: PalierColors.textMid),
          ),
        ],
      );
      semanticValue = l10n.exerciseReps(step.reps!);
    }

    return Column(
      children: [
        const SizedBox(height: PalierSpace.sm),
        Text(
          l10n.playerRound(round, rounds),
          style: manrope(size: 15, weight: FontWeight.w600, color: PalierColors.textMid),
        ),
        const Spacer(),
        LucidCountdownRing(
          progress: controller.stepProgress ?? 1,
          size: 260,
          strokeWidth: 14,
          color: ringColor,
          trackColor: PalierColors.indigo,
          semanticLabel: step.label,
          semanticValue: semanticValue,
          child: center,
        ),
        const SizedBox(height: PalierSpace.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PalierSpace.page),
          child: Text(
            step.label,
            textAlign: TextAlign.center,
            style: text.headlineMedium!.copyWith(color: rest ? PalierColors.textMid : PalierColors.textHigh),
          ),
        ),
        const SizedBox(height: PalierSpace.sm),
        Text(
          paused ? l10n.playerPaused : (next == null ? l10n.playerLast : l10n.playerNext(next.label)),
          style: manrope(
            size: 15,
            weight: FontWeight.w600,
            color: paused ? PalierColors.warning : PalierColors.textLow,
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, 0, PalierSpace.page, PalierSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!step.isTimed) ...[
                LucidButton(label: l10n.playerDone, expand: true, onPressed: controller.complete),
                const SizedBox(height: PalierSpace.sm),
              ],
              Row(
                children: [
                  Expanded(
                    child: LucidButton(
                      label: paused ? l10n.playerResume : l10n.playerPause,
                      variant: LucidButtonVariant.outlined,
                      expand: true,
                      onPressed: paused ? controller.resume : controller.pause,
                    ),
                  ),
                  if (step.isTimed) ...[
                    const SizedBox(width: PalierSpace.sm),
                    Expanded(
                      child: LucidButton(
                        label: l10n.playerSkip,
                        variant: LucidButtonVariant.outlined,
                        expand: true,
                        onPressed: controller.complete,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fin du circuit : la durée, le ressenti, et l'enregistrement dans le journal.
class _Finished extends StatelessWidget {
  const _Finished({
    required this.elapsed,
    required this.effort,
    required this.saving,
    required this.onEffort,
    required this.onSave,
    required this.onDiscard,
  });

  final Duration elapsed;
  final WorkoutEffort? effort;
  final bool saving;
  final ValueChanged<WorkoutEffort> onEffort;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(PalierSpace.page, PalierSpace.xl, PalierSpace.page, PalierSpace.md),
            children: [
              Icon(Icons.check_circle_rounded, size: 56, color: accent),
              const SizedBox(height: PalierSpace.md),
              Text(
                l10n.playerFinishedTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: PalierSpace.sm),
              Text(
                l10n.playerFinishedBody(formatMinutes(l10n, (elapsed.inSeconds / 60).round())),
                textAlign: TextAlign.center,
                style: manrope(size: 15, weight: FontWeight.w500, color: PalierColors.textMid),
              ),
              FieldLabel(l10n.workoutEffortLabel),
              PillRow(
                children: [
                  for (final value in WorkoutEffort.values)
                    ChoicePill(label: effortName(l10n, value), selected: value == effort, onTap: () => onEffort(value)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(PalierSpace.page, 0, PalierSpace.page, PalierSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LucidButton(label: l10n.playerSaveWorkout, expand: true, isLoading: saving, onPressed: onSave),
              const SizedBox(height: PalierSpace.sm),
              TextButton(onPressed: onDiscard, child: Text(l10n.playerDiscard)),
            ],
          ),
        ),
      ],
    );
  }
}
