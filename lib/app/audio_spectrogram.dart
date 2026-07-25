import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

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
    int maxColumns = 180,
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
    final int hop = math.max(256, sampleCount ~/ maxColumns);
    final List<List<double>> columns = <List<double>>[];
    for (int start = 0; start + 512 <= sampleCount; start += hop) {
      final List<double> real = List<double>.filled(512, 0);
      final List<double> imag = List<double>.filled(512, 0);
      for (int i = 0; i < 512; i++) {
        final double window = 0.5 - 0.5 * math.cos(2 * math.pi * i / 511);
        real[i] = data.getInt16(dataOffset + (start + i) * 2, Endian.little) / 32768 * window;
      }
      _fft(real, imag);
      final List<double> column = List<double>.filled(bins, 0);
      for (int bin = 0; bin < bins; bin++) {
        final int from = 1 + (math.pow(bin / bins, 1.7) * 254).floor();
        final int to = math.max(from + 1, 1 + (math.pow((bin + 1) / bins, 1.7) * 254).floor());
        double peak = 0;
        for (int k = from; k < math.min(to, 256); k++) {
          peak = math.max(peak, math.sqrt(real[k] * real[k] + imag[k] * imag[k]));
        }
        column[bin] = ((math.log(1 + peak * 28) / math.log(29))).clamp(0.0, 1.0);
      }
      columns.add(column);
      if (columns.length >= maxColumns) break;
    }
    return columns;
  }

  static int _findDataOffset(Uint8List bytes) {
    for (int i = 12; i + 8 < bytes.length; i++) {
      if (bytes[i] == 100 && bytes[i + 1] == 97 && bytes[i + 2] == 116 && bytes[i + 3] == 97) {
        return i + 8;
      }
    }
    return -1;
  }

  static void _fft(List<double> real, List<double> imag) {
    final int n = real.length;
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final double tr = real[i]; real[i] = real[j]; real[j] = tr;
      }
    }
    for (int len = 2; len <= n; len <<= 1) {
      final double angle = -2 * math.pi / len;
      final double wLenR = math.cos(angle);
      final double wLenI = math.sin(angle);
      for (int i = 0; i < n; i += len) {
        double wr = 1;
        double wi = 0;
        for (int k = 0; k < len ~/ 2; k++) {
          final int even = i + k;
          final int odd = even + len ~/ 2;
          final double vr = real[odd] * wr - imag[odd] * wi;
          final double vi = real[odd] * wi + imag[odd] * wr;
          final double ur = real[even];
          final double ui = imag[even];
          real[even] = ur + vr; imag[even] = ui + vi;
          real[odd] = ur - vr; imag[odd] = ui - vi;
          final double nextWr = wr * wLenR - wi * wLenI;
          wi = wr * wLenI + wi * wLenR;
          wr = nextWr;
        }
      }
    }
  }
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
  });

  final List<List<double>> columns;
  final List<SpectrogramMarker> markers;
  final double? playbackPosition;
  final ValueChanged<double>? onSeek;
  final double height;
  final bool liveCenter;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: onSeek == null
            ? null
            : (details) {
                final RenderBox box = context.findRenderObject()! as RenderBox;
                onSeek!((details.localPosition.dx / box.size.width).clamp(0, 1));
              },
        child: SizedBox(
          width: double.infinity,
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

class _SpectrogramPainter extends CustomPainter {
  const _SpectrogramPainter({required this.columns, required this.markers, this.playbackPosition, required this.liveCenter});
  final List<List<double>> columns;
  final List<SpectrogramMarker> markers;
  final double? playbackPosition;
  final bool liveCenter;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = const Color(0xFF071A24);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)), background);
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
          final Color color = Color.lerp(const Color(0xFF0B3B46), const Color(0xFFFFD54F), value)!;
          canvas.drawRect(Rect.fromLTWH(x * cw, size.height - (y + 1) * bh, cw + 0.5, bh + 0.5), Paint()..color = color);
        }
      }
    }
    if (liveCenter) {
      canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), Paint()..color = Colors.white.withValues(alpha: 0.9)..strokeWidth = 2);
    }
    for (final SpectrogramMarker marker in markers) {
      final double x = marker.position.clamp(0, 1) * size.width;
      final Paint p = Paint()..color = marker.confirmed ? Colors.greenAccent : Colors.orangeAccent..strokeWidth = 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      final TextPainter text = TextPainter(
        text: TextSpan(text: marker.label, style: TextStyle(color: p.color, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 100);
      text.paint(canvas, Offset((x + 3).clamp(3, size.width - text.width - 3), 5));
    }
    if (playbackPosition != null) {
      final double x = playbackPosition!.clamp(0, 1) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()..color = Colors.white..strokeWidth = 2.5);
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrogramPainter oldDelegate) =>
      oldDelegate.columns != columns || oldDelegate.markers != markers || oldDelegate.playbackPosition != playbackPosition || oldDelegate.liveCenter != liveCenter;
}
