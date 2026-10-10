import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firbird/ai/claude_api_service.dart';
import 'package:firbird/data/app_database.dart';

/// Shows an interactive dialog to view, test, and save or clear the Claude API key.
Future<bool?> showClaudeApiKeyDialog(
  BuildContext context, {
  required ClaudeApiService service,
  required AppDatabase database,
}) async {
  final bool hasExistingKey = await service.hasApiKey();
  String enteredKey = '';
  bool testing = false;
  String? errorText;

  if (!context.mounted) return null;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext dialogContext, StateSetter setDialogState) => AlertDialog(
        title: const Row(
          children: <Widget>[
            Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 24),
            SizedBox(width: 8),
            Text('Claude API Anahtarı'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Canlı dinleme tespitlerini Claude ornitoloji yapay zekası ile değerlendirmek için Anthropic API anahtarınızı girin.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (String value) => enteredKey = value,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Anthropic API Anahtarı',
                hintText: 'sk-ant-api03-...',
                helperText: 'Anahtar cihazın güvenli deposunda saklanır.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://console.anthropic.com/settings/keys'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Anthropic Console\'dan anahtar al'),
            ),
            if (testing) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              const Text('Anahtar Anthropic ile doğrulanıyor…', style: TextStyle(fontSize: 12)),
            ],
            if (errorText != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                errorText!,
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          if (hasExistingKey)
            TextButton(
              onPressed: testing
                  ? null
                  : () async {
                      await service.clearApiKey();
                      await database.clearClaudeApiKeyLastVerifiedAt();
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, false);
                      }
                    },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Anahtarı sil'),
            ),
          TextButton(
            onPressed: testing ? null : () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: testing
                ? null
                : () async {
                    bool completed = false;
                    setDialogState(() {
                      testing = true;
                      errorText = null;
                    });
                    try {
                      await service.testApiKey(enteredKey);
                      await service.saveApiKey(enteredKey);
                      await database.setClaudeApiKeyLastVerifiedAt(DateTime.now());
                      if (dialogContext.mounted) {
                        completed = true;
                        Navigator.pop(dialogContext, true);
                      }
                    } on FormatException catch (error) {
                      if (dialogContext.mounted) {
                        setDialogState(() => errorText = error.message);
                      }
                    } on ClaudeApiException catch (error) {
                      if (dialogContext.mounted) {
                        setDialogState(() => errorText = error.message);
                      }
                    } on Exception catch (error) {
                      if (dialogContext.mounted) {
                        setDialogState(
                          () => errorText = 'Doğrulama başarısız: $error',
                        );
                      }
                    } finally {
                      if (dialogContext.mounted && !completed) {
                        setDialogState(() => testing = false);
                      }
                    }
                  },
            child: const Text('Test et ve kaydet'),
          ),
        ],
      ),
    ),
  );

  return result;
}
