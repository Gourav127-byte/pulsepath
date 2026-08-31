import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/pulse_path_theme.dart';
import '../models/distance_recording_state.dart';
import '../providers/distance_recorder_provider.dart';

class DistanceRecorderCard extends ConsumerWidget {
  const DistanceRecorderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(distanceRecorderControllerProvider);
    final controller = ref.read(distanceRecorderControllerProvider.notifier);

    final isRecording = status.isRecording;

    final String statusLabel = switch (status.state) {
      DistanceRecordingLifecycle.recording =>
        'RECORDING (${status.activityType?.name.toUpperCase() ?? 'WALK'})',
      DistanceRecordingLifecycle.finalized => 'FINALIZED',
      DistanceRecordingLifecycle.interrupted =>
        'INTERRUPTED (${status.interruptionReason ?? 'GPS Disconnected'})',
      DistanceRecordingLifecycle.idle => 'IDLE',
    };

    final Color statusColor = switch (status.state) {
      DistanceRecordingLifecycle.recording => PulsePathColors.cyan,
      DistanceRecordingLifecycle.finalized => Colors.greenAccent,
      DistanceRecordingLifecycle.interrupted => Colors.orangeAccent,
      DistanceRecordingLifecycle.idle => PulsePathColors.textSecondary,
    };

    final String distanceDisplay = status.distanceKm != null
        ? '${status.distanceKm!.toStringAsFixed(2)} km'
        : '-- (Not recorded)';

    return Container(
      key: const Key('distance_recorder_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PulsePathColors.surface,
        borderRadius: BorderRadius.circular(PulsePathSizes.cardRadius),
        border: Border.all(color: PulsePathColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.navigation_rounded,
                    color: PulsePathColors.cyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Native Distance Recorder',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text(
                'Recorded GPS Distance:',
                style: TextStyle(color: PulsePathColors.textSecondary),
              ),
              Text(
                distanceDisplay,
                key: const Key('recorded_distance_text'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: status.distanceKm != null
                          ? PulsePathColors.textPrimary
                          : PulsePathColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 480;
              final isNarrow = constraints.maxWidth < 320;

              if (isNarrow) {
                // Stack vertically for narrow viewports (< 320px)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('start_walk_button'),
                      onPressed: isRecording ? null : () => controller.startWalk(),
                      icon: const Icon(Icons.directions_walk_rounded, size: 18),
                      label: const Text('Start Walk'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('start_run_button'),
                      onPressed: isRecording ? null : () => controller.startRun(),
                      icon: const Icon(Icons.directions_run_rounded, size: 18),
                      label: const Text('Start Run'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('finish_session_button'),
                      onPressed: isRecording ? () => controller.finish() : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      label: const Text('Finish'),
                    ),
                  ],
                );
              } else if (!isWide) {
                // Responsive 2-row layout: Start Walk & Start Run in row 1, Finish in row 2
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('start_walk_button'),
                            onPressed: isRecording ? null : () => controller.startWalk(),
                            icon: const Icon(Icons.directions_walk_rounded, size: 18),
                            label: const Text('Start Walk'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('start_run_button'),
                            onPressed: isRecording ? null : () => controller.startRun(),
                            icon: const Icon(Icons.directions_run_rounded, size: 18),
                            label: const Text('Start Run'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: const Key('finish_session_button'),
                      onPressed: isRecording ? () => controller.finish() : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      label: const Text('Finish'),
                    ),
                  ],
                );
              } else {
                // Wide desktop/tablet layout: 3 buttons side-by-side in one row
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('start_walk_button'),
                        onPressed: isRecording ? null : () => controller.startWalk(),
                        icon: const Icon(Icons.directions_walk_rounded, size: 18),
                        label: const Text('Start Walk'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('start_run_button'),
                        onPressed: isRecording ? null : () => controller.startRun(),
                        icon: const Icon(Icons.directions_run_rounded, size: 18),
                        label: const Text('Start Run'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('finish_session_button'),
                        onPressed: isRecording ? () => controller.finish() : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: const Text('Finish'),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
