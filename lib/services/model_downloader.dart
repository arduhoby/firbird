import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final modelDownloaderProvider = Provider<ModelDownloader>((ref) {
  return ModelDownloader();
});

class ModelDownloader {
  final Dio _dio = Dio();

  Future<void> downloadModel({
    required String url,
    required String fileName,
    required void Function(int, int) onReceiveProgress,
    required void Function(String) onError,
    required void Function() onSuccess,
  }) async {
    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        onError('Depolama alanına erişilemiyor.');
        return;
      }
      
      final Directory targetDir = Directory(path.join(externalDir.path, 'firbird_test_model'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      
      final File file = File(path.join(targetDir.path, fileName));
      if (await file.exists()) {
        // Assume already downloaded for now.
        onSuccess();
        return;
      }
      
      await _dio.download(
        url,
        file.path,
        onReceiveProgress: onReceiveProgress,
      );
      
      onSuccess();
    } catch (e) {
      onError('İndirme hatası: $e');
    }
  }
  
  Future<bool> isModelDownloaded(String fileName) async {
    final Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) return false;
    final File file = File(path.join(externalDir.path, 'firbird_test_model', fileName));
    return await file.exists();
  }
}
