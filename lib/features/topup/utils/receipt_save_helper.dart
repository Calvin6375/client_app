import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Saves a receipt PNG to the photo library via [gal], or opens the system share
/// sheet when the plugin is missing (hot reload / unsupported host) so the user
/// can still save to Photos or Files.
Future<void> saveReceiptPngToGalleryOrShare({
  required Uint8List pngBytes,
  required String fileBaseName,
  required void Function(String message) onMessage,
}) async {
  if (kIsWeb) {
    await _shareReceipt(pngBytes, fileBaseName, onMessage);
    return;
  }

  try {
    var ok = await Gal.hasAccess();
    if (!ok) {
      ok = await Gal.requestAccess();
    }
    if (!ok) {
      onMessage('Photo library access is required to save your receipt.');
      return;
    }
    await Gal.putImageBytes(pngBytes, name: fileBaseName, album: 'Troupay');
    onMessage('Receipt saved to gallery');
  } on MissingPluginException {
    await _shareReceipt(pngBytes, fileBaseName, onMessage);
  } on GalException catch (e) {
    onMessage(e.type.message);
  } catch (e) {
    final s = e.toString();
    if (e is MissingPluginException || s.contains('MissingPluginException')) {
      await _shareReceipt(pngBytes, fileBaseName, onMessage);
    } else {
      onMessage('Could not save receipt: $e');
    }
  }
}

Future<void> _shareReceipt(
  Uint8List pngBytes,
  String fileBaseName,
  void Function(String message) onMessage,
) async {
  try {
    final xf = XFile.fromData(
      pngBytes,
      mimeType: 'image/png',
      name: '$fileBaseName.png',
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [xf],
        subject: 'Troupay receipt',
      ),
    );
    onMessage('Choose Save to Photos or Files in the share sheet, if available.');
  } catch (e) {
    onMessage('Could not share receipt: $e');
  }
}
