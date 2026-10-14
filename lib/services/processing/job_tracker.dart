import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/diagnostics/diagnostics_log.dart';
import '../../features/processing/model/processing_args.dart';

enum ActiveJobStatus { processing, done, failed }

/// In-memory representation of an active or recently completed clean job,
/// allowing the user to background the job and reattach from Home.
class ActiveJob {
  const ActiveJob({
    required this.photoPath,
    this.keepIds,
    required this.status,
    this.outcome,
    this.errorMessage,
    required this.startedAt,
  });

  final String photoPath;
  final List<int>? keepIds;
  final ActiveJobStatus status;
  final ProcessingOutcome? outcome;
  final String? errorMessage;
  final DateTime startedAt;

  ActiveJob copyWith({
    ActiveJobStatus? status,
    ProcessingOutcome? outcome,
    String? errorMessage,
  }) {
    return ActiveJob(
      photoPath: photoPath,
      keepIds: keepIds,
      status: status ?? this.status,
      outcome: outcome ?? this.outcome,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt,
    );
  }
}

/// Global tracker for in-flight and completed background jobs.
class JobTracker {
  JobTracker._();
  static final JobTracker instance = JobTracker._();

  final activeJob = Rxn<ActiveJob>();

  void _setJob(ActiveJob? job) {
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      activeJob.value = job;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        activeJob.value = job;
      });
    }
  }

  void trackStarted({required String photoPath, List<int>? keepIds}) {
    diag('job_tracker', 'trackStarted: ${photoPath.split('/').last}');
    _setJob(
      ActiveJob(
        photoPath: photoPath,
        keepIds: keepIds,
        status: ActiveJobStatus.processing,
        startedAt: DateTime.now(),
      ),
    );
  }

  void trackDone(ProcessingOutcome outcome) {
    diag('job_tracker', 'trackDone: detected=${outcome.personsDetected} removed=${outcome.removedIds.length}');
    if (activeJob.value != null) {
      _setJob(
        activeJob.value!.copyWith(
          status: ActiveJobStatus.done,
          outcome: outcome,
        ),
      );
    } else {
      _setJob(
        ActiveJob(
          photoPath: outcome.originalPath,
          status: ActiveJobStatus.done,
          outcome: outcome,
          startedAt: DateTime.now(),
        ),
      );
    }
  }

  void trackFailed(String errorMessage) {
    diag('job_tracker', 'trackFailed: $errorMessage');
    if (activeJob.value != null) {
      _setJob(
        activeJob.value!.copyWith(
          status: ActiveJobStatus.failed,
          errorMessage: errorMessage,
        ),
      );
    }
  }

  void clear() {
    diag('job_tracker', 'clear');
    _setJob(null);
  }
}

