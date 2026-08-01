import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:firbird/audio/fft_util.dart';

class SpectrogramMarker {
  const SpectrogramMarker({
    required this.position,
    required this.label,
    this.confirmed = false,
  });

  final double position;
  final String label;
  final bool confirmed;
}

class WavSpectrogram {
  static Future<List<List<double>>> analyze(
    String filePath, {
    int maxColumns = 24000,
    double? columnsPerSecond = 8.0,
    int bins = 48,
  }) async {
    final Uint8List bytes = await File(filePath).readAsBytes();
    if (bytes.length < 46) return const <List<double>>[];
    final int dataOffset = _findDataOffset(bytes);
    if (dataOffset < 0 || dataOffset >= bytes.length - 2) {
      return const <List<double>>[];
    }

    final ByteData data = ByteData.sublistView(bytes);
    final int sampleCount = (bytes.length - dataOffset) ~/ 2;
    if (sampleCount < 512) return const <List<double>>[];
    final int sampleRate = bytes.length >= 28
        ? data.getUint32(24, Endian.little)
        : 48000;
    return _analyzeSamples(
      data,
      dataOffset: dataOffset,
      sampleCount: sampleCount,
      sampleRate: sampleRate,
      maxColumns: maxColumns,
      columnsPerSecond: columnsPerSecond,
      bins: bins,
    );
  }

  static List<List<double>> analyzePcm16(
    Uint8List pcmBytes, {
    int sampleRate = 48000,
    int maxColumns = 24000,
    double? columnsPerSecond = 8.0,
    int bins = 48,
  }) {
    final int sampleCount = pcmBytes.length ~/ 2;
    if (sampleCount < 512) return const <List<double>>[];
    return _analyzeSamples(
      ByteData.sublistView(pcmBytes),
      dataOffset: 0,
      sampleCount: sampleCount,
      sampleRate: sampleRate,
      maxColumns: maxColumns,
      columnsPerSecond: columnsPerSecond,
      bins: bins,
    );
  }

  static List<List<double>> _analyzeSamples(
    ByteData data, {
    required int dataOffset,
    required int sampleCount,
    required int sampleRate,
    required int maxColumns,
    required double? columnsPerSecond,
    required int bins,
  }) {
    final int requestedColumns = columnsPerSecond == null
        ? maxColumns
        : math.max(
            maxColumns,
            (sampleCount / math.max(sampleRate, 1) * columnsPerSecond).ceil(),
          );
    final int hop = math.max(256, sampleCount ~/ requestedColumns);
    final List<List<double>> columns = <List<double>>[];
    for (int start = 0; start + 512 <= sampleCount; start += hop) {
      final List<double> real = List<double>.filled(512, 0);
      final List<double> imag = List<double>.filled(512, 0);
      for (int i = 0; i < 512; i++) {
        final double window = 0.5 - 0.5 * math.cos(2 * math.pi * i / 511);
        real[i] =
            data.getInt16(dataOffset + (start + i) * 2, Endian.little) /
            32768 *
            window;
      }
      FftUtil.fft(real, imag);
      final List<double> column = List<double>.filled(bins, 0);
      for (int bin = 0; bin < bins; bin++) {
        final int from = 1 + (math.pow(bin / bins, 1.7) * 254).floor();
        final int to = math.max(
          from + 1,
          1 + (math.pow((bin + 1) / bins, 1.7) * 254).floor(),
        );
        double peak = 0;
        for (int k = from; k < math.min(to, 256); k++) {
          peak = math.max(
            peak,
            math.sqrt(real[k] * real[k] + imag[k] * imag[k]),
          );
        }
        column[bin] = ((math.log(1 + peak * 28) / math.log(29))).clamp(
          0.0,
          1.0,
        );
      }
      columns.add(column);
      if (columns.length >= maxColumns) break;
    }
    return columns;
  }

  static int _findDataOffset(Uint8List bytes) {
    for (int i = 12; i + 8 < bytes.length; i++) {
      if (bytes[i] == 100 &&
          bytes[i + 1] == 97 &&
          bytes[i + 2] == 116 &&
          bytes[i + 3] == 97) {
        return i + 8;
      }
    }
    return -1;
  }

  // FFT is provided by the canonical FftUtil in lib/audio/fft_util.dart.
}

class AudioSpectrogram extends StatelessWidget {
  const AudioSpectrogram({
    super.key,
    required this.columns,
    this.markers = const <SpectrogramMarker>[],
    this.playbackPosition,
    this.onSeek,
    this.height = 150,
    this.liveCenter = false,
    this.width,
  });

  final List<List<double>> columns;
  final List<SpectrogramMarker> markers;
  final double? playbackPosition;
  final ValueChanged<double>? onSeek;
  final double height;
  final bool liveCenter;
  final double? width;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: onSeek == null
        ? null
        : (details) {
            final RenderBox box = context.findRenderObject()! as RenderBox;
            onSeek!((details.localPosition.dx / box.size.width).clamp(0, 1));
          },
    child: SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: CustomPaint(
        painter: _SpectrogramPainter(
          columns: columns,
          markers: markers,
          playbackPosition: playbackPosition,
          liveCenter: liveCenter,
        ),
      ),
    ),
  );
}

/// Keeps each time slice at a readable width for completed recordings.
/// Horizontally scales to 30 seconds per screen width so lines and bird markers
/// are never squeezed together. Auto-scrolls during playback to keep indicator centered.
class ScrollableAudioSpectrogram extends StatefulWidget {
  const ScrollableAudioSpectrogram({
    super.key,
    required this.columns,
    this.markers = const <SpectrogramMarker>[],
    this.playbackPosition,
    this.onSeek,
    this.height = 200,
    this.durationMs,
    this.secondsPerScreen = 30.0,
    this.columnsPerSecond = 8.0,
    this.pixelsPerColumn,
  });

  final List<List<double>> columns;
  final List<SpectrogramMarker> markers;
  final double? playbackPosition;
  final ValueChanged<double>? onSeek;
  final double height;
  final int? durationMs;
  final double secondsPerScreen;
  final double columnsPerSecond;
  final double? pixelsPerColumn;

  @override
  State<ScrollableAudioSpectrogram> createState() =>
      _ScrollableAudioSpectrogramState();
}

class _ScrollableAudioSpectrogramState
    extends State<ScrollableAudioSpectrogram> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant ScrollableAudioSpectrogram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playbackPosition != null &&
        widget.playbackPosition != oldWidget.playbackPosition &&
        _scrollController.hasClients) {
      _autoScrollToPlayback(widget.playbackPosition!);
    }
  }

  void _autoScrollToPlayback(double position) {
    final double maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final double viewportWidth = _scrollController.position.viewportDimension;
    final double timelineWidth = maxScroll + viewportWidth;
    final double playbackX = position.clamp(0.0, 1.0) * timelineWidth;
    final double targetOffset = (playbackX - viewportWidth / 2).clamp(
      0.0,
      maxScroll,
    );

    if ((_scrollController.offset - targetOffset).abs() > 15) {
      _scrollController.jumpTo(targetOffset);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double screenWidth = constraints.maxWidth;
      final double totalSeconds =
          (widget.durationMs != null && widget.durationMs! > 0)
              ? widget.durationMs! / 1000.0
              : (widget.columns.length / widget.columnsPerSecond);

      final double calculatedWidth =
          widget.pixelsPerColumn != null
              ? math.max(
                screenWidth,
                widget.columns.length * widget.pixelsPerColumn!,
              )
              : math.max(
                screenWidth,
                screenWidth * (totalSeconds / widget.secondsPerScreen),
              );

      return SizedBox(
        height: widget.height,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: AudioSpectrogram(
            columns: widget.columns,
            markers: widget.markers,
            playbackPosition: widget.playbackPosition,
            onSeek: widget.onSeek,
            height: widget.height,
            width: calculatedWidth,
          ),
        ),
      );
    },
  );
}

class _SpectrogramPainter extends CustomPainter {
  const _SpectrogramPainter({
    required this.columns,
    required this.markers,
    this.playbackPosition,
    required this.liveCenter,
  });
  final List<List<double>> columns;
  final List<SpectrogramMarker> markers;
  final double? playbackPosition;
  final bool liveCenter;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = const Color(0xFF071A24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      background,
    );
    if (columns.isNotEmpty) {
      // Live mode is a rolling timeline: new audio is appended on the right
      // and older columns naturally move toward the left edge. The center
      // line remains the fixed "now" indicator, as in Merlin.
      final double cw = size.width / columns.length;
      for (int x = 0; x < columns.length; x++) {
        final List<double> bins = columns[x];
        final double bh = size.height / bins.length;
        for (int y = 0; y < bins.length; y++) {
          final double value = bins[y];
          if (value < 0.06) continue;
          final Color color = Color.lerp(
            const Color(0xFF0B3B46),
            const Color(0xFFFFD54F),
            value,
          )!;
          canvas.drawRect(
            Rect.fromLTWH(
              x * cw,
              size.height - (y + 1) * bh,
              cw + 0.5,
              bh + 0.5,
            ),
            Paint()..color = color,
          );
        }
      }
    }
    if (liveCenter) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 2,
      );
    }
    for (final SpectrogramMarker marker in markers) {
      final double x = marker.position.clamp(0, 1) * size.width;
      final Paint p = Paint()
        ..color = marker.confirmed ? Colors.greenAccent : Colors.orangeAccent
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      final TextPainter text = TextPainter(
        text: TextSpan(
          text: marker.label,
          style: TextStyle(
            color: p.color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 100);
      text.paint(
        canvas,
        Offset((x + 3).clamp(3, size.width - text.width - 3), 5),
      );
    }
    if (playbackPosition != null) {
      final double x = playbackPosition!.clamp(0, 1) * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrogramPainter oldDelegate) =>
      oldDelegate.columns != columns ||
      oldDelegate.markers != markers ||
      oldDelegate.playbackPosition != playbackPosition ||
      oldDelegate.liveCenter != liveCenter;
}
