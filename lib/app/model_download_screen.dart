import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/model_downloader.dart';

class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  bool _isDownloading = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  Future<void> _checkModel() async {
    final downloader = ref.read(modelDownloaderProvider);
    final isBioClipDownloaded = await downloader.isModelDownloaded('model.onnx');
    final isBirdNetDownloaded = await downloader.isModelDownloaded('birdnet.onnx');
    if (isBioClipDownloaded && isBirdNetDownloaded) {
      if (mounted) context.go('/onboarding');
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _error = null;
    });

    final downloader = ref.read(modelDownloaderProvider);
    
    // Download BioCLIP
    await downloader.downloadModel(
      url: 'https://huggingface.co/mahan-ym/bioclip-2-quantized/resolve/main/onnx/bioclip2_model_int8.onnx?download=true',
      fileName: 'model.onnx',
      onReceiveProgress: (int received, int total) {
        if (total != -1 && mounted) {
          setState(() {
            _progress = (received / total) * 0.9; // 90% for BioCLIP
          });
        }
      },
      onError: (String error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _error = 'BioCLIP: $error';
          });
        }
      },
      onSuccess: () {},
    );

    if (_error != null) return;

    // Download BirdNET
    await downloader.downloadModel(
      url: 'https://huggingface.co/justinchuby/BirdNET-onnx/resolve/main/models/birdnet_default.onnx?download=true',
      fileName: 'birdnet.onnx',
      onReceiveProgress: (int received, int total) {
        if (total != -1 && mounted) {
          setState(() {
            _progress = 0.9 + ((received / total) * 0.1); // 10% for BirdNET
          });
        }
      },
      onError: (String error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _error = 'BirdNET: $error';
          });
        }
      },
      onSuccess: () {
        if (mounted) {
          context.go('/onboarding');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.download_rounded, size: 88, color: Colors.green),
              const SizedBox(height: 32),
              Text(
                'Yapay Zeka Modeli İndirilecek',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Kuşları çevrimdışı tanıyabilmek için görsel ve işitsel yapay zeka modellerinin (toplam yaklaşık 340 MB) indirilmesi gerekiyor. Bu işlem sadece bir kez yapılacaktır.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isDownloading) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}% tamamlandı',
                  textAlign: TextAlign.center,
                ),
              ] else if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _startDownload,
                  child: const Text('Tekrar Dene'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.download),
                  label: const Text('İndirmeyi Başlat (340 MB)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
