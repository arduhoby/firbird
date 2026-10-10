import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firbird/ai/claude_api_service.dart';
import 'package:firbird/data/app_database.dart';

final Provider<ClaudeApiService> claudeApiServiceProvider =
    Provider<ClaudeApiService>((ref) => ClaudeApiService());

class EvaluationModeNotifier extends Notifier<EvaluationMode> {
  @override
  EvaluationMode build() {
    _load();
    return EvaluationMode.local;
  }

  Future<void> _load() async {
    final AppDatabase db = ref.read(appDatabaseProvider);
    final String mode = await db.evaluationMode();
    state = mode == 'claude' ? EvaluationMode.claude : EvaluationMode.local;
  }

  Future<void> setMode(EvaluationMode mode) async {
    state = mode;
    final AppDatabase db = ref.read(appDatabaseProvider);
    await db.setEvaluationMode(mode.name);
  }
}

final NotifierProvider<EvaluationModeNotifier, EvaluationMode>
evaluationModeProvider =
    NotifierProvider<EvaluationModeNotifier, EvaluationMode>(
      EvaluationModeNotifier.new,
    );
