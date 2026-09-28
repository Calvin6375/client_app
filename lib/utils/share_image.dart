import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [pngBytes] to the photo library.
Future<void> savePngToGallery({
  required Uint8List pngBytes,
  required String fileBaseName,
  String album = 'TruePay',
  required void Function(String message) onMessage,
}) async {
  if (kIsWeb) {
    await sharePngImage(
      pngBytes: pngBytes,
      fileBaseName: fileBaseName,
      subject: fileBaseName,
      onMessage: onMessage,
    );
    return;
  }

  try {
    var ok = await Gal.hasAccess(toAlbum: true);
    if (!ok) {
      ok = await Gal.requestAccess(toAlbum: true);
    }
    if (!ok) {
      onMessage('Photo library access is required to save this image.');
      return;
    }
    await Gal.putImageBytes(pngBytes, name: fileBaseName, album: album);
    onMessage('Saved to gallery');
  } on MissingPluginException {
    onMessage('Could not save to gallery on this device.');
  } on GalException catch (e) {
    onMessage(e.type.message);
  } catch (e) {
    onMessage('Could not save image: $e');
  }
}

/// Opens the system share sheet with [pngBytes] as an image attachment.
Future<void> sharePngImage({
  required Uint8List pngBytes,
  required String fileBaseName,
  String? subject,
  String? text,
  Rect? sharePositionOrigin,
  required void Function(String message) onMessage,
}) async {
  try {
    final name = fileBaseName.endsWith('.png') ? fileBaseName : '$fileBaseName.png';
    late final XFile xf;
    if (kIsWeb) {
      xf = XFile.fromData(pngBytes, mimeType: 'image/png', name: name);
    } else {
      final path = '${Directory.systemTemp.path}/$name';
      final file = File(path);
      await file.writeAsBytes(pngBytes, flush: true);
      xf = XFile(path, mimeType: 'image/png', name: name);
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [xf],
        subject: subject,
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  } catch (e) {
    onMessage('Could not share image: $e');
  }
}
