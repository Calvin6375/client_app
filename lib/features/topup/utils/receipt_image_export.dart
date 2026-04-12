import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

/// Captures a [RepaintBoundary] to PNG bytes and composites a Troupay logo watermark.
class ReceiptImageExport {
  ReceiptImageExport._();

  static Future<Uint8List?> captureRepaintBoundaryPng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd?.buffer.asUint8List();
  }

  /// Draws [logoPng] centered on [receiptPng] with reduced opacity for a watermark.
  static Uint8List applyTroupayWatermark({
    required Uint8List receiptPng,
    required Uint8List logoPng,
    double widthFraction = 0.44,
    double opacityFactor = 0.28,
  }) {
    final dst = img.decodePng(receiptPng);
    var wm = img.decodePng(logoPng);
    if (dst == null || wm == null) {
      throw StateError('Failed to decode receipt or watermark PNG');
    }
    final targetW = (dst.width * widthFraction).round().clamp(48, dst.width);
    wm = img.copyResize(wm, width: targetW);
    wm = wm.convert(numChannels: 4);
    for (var y = 0; y < wm.height; y++) {
      for (var x = 0; x < wm.width; x++) {
        final p = wm.getPixel(x, y);
        final na = (p.a * opacityFactor).round().clamp(0, 255);
        wm.setPixelRgba(x, y, p.r, p.g, p.b, na);
      }
    }
    img.compositeImage(dst, wm, center: true, blend: img.BlendMode.alpha);
    return Uint8List.fromList(img.encodePng(dst));
  }
}
