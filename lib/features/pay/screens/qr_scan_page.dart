import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretium/core/constants/app_colors.dart';

/// Live camera QR scanner with optional gallery upload.
/// Pops with the scanned/selected code [String], or null if cancelled.
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key, this.title = 'Scan QR'});

  final String title;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  late final MobileScannerController _controller;
  final _codeCtrl = TextEditingController();
  var _handling = false;
  var _pickingGallery = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handling) return;
    final code = capture.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (code.isEmpty) return;
    _handling = true;
    _controller.stop();
    if (!mounted) return;
    Navigator.of(context).pop(code);
  }

  Future<void> _pickFromGallery() async {
    if (_pickingGallery || _handling) return;
    setState(() => _pickingGallery = true);
    try {
      // Release the camera before PHPicker — iOS will fail if both are active.
      await _controller.stop();
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (!mounted) return;
      if (file == null) {
        await _safeStartCamera();
        return;
      }

      final capture = await _controller.analyzeImage(file.path);
      if (!mounted) return;

      final code = capture?.barcodes
              .map((b) => b.rawValue?.trim() ?? '')
              .firstWhere((v) => v.isNotEmpty, orElse: () => '') ??
          '';

      if (code.isEmpty) {
        _snack('No QR code found in that image');
        await _safeStartCamera();
        return;
      }

      _handling = true;
      Navigator.of(context).pop(code);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final channelError = e.code == 'channel-error' ||
          (e.message?.contains('Unable to establish connection') ?? false);
      _snack(
        channelError
            ? 'Gallery picker is not ready. Stop the app and run a full restart (not hot reload).'
            : 'Could not open gallery. Check Photos permission and try again.',
      );
      await _safeStartCamera();
    } catch (_) {
      if (!mounted) return;
      _snack('Could not read QR from that image');
      await _safeStartCamera();
    } finally {
      if (mounted) setState(() => _pickingGallery = false);
    }
  }

  Future<void> _safeStartCamera() async {
    try {
      await _controller.start();
    } catch (_) {}
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _useManualCode() {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan a QR code or paste one below')),
      );
      return;
    }
    _handling = true;
    _controller.stop();
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.getThemeColors(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.transparent : primary.withValues(alpha: 0.08),
        elevation: 0,
        title: Text(widget.title, style: TextStyle(color: colors.textPrimary)),
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Upload from gallery',
            onPressed: _pickingGallery ? null : _pickFromGallery,
            icon: _pickingGallery
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                  )
                : Icon(Icons.photo_library_outlined, color: colors.textPrimary),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                          errorBuilder: (context, error) {
                            return ColoredBox(
                              color: isDark ? colors.surface : Colors.black87,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.videocam_off_outlined,
                                        size: 48,
                                        color: colors.textSecondary,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Camera unavailable. Allow camera access or upload a QR from gallery.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _QrFramePainter(color: primary),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Text(
                            'Position QR code in frame',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              shadows: const [
                                Shadow(blurRadius: 8, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickingGallery ? null : _pickFromGallery,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Upload QR from gallery'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeCtrl,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'QR code',
                    hintText: 'Or paste code manually',
                    filled: true,
                    fillColor: colors.inputBackground,
                    labelStyle: TextStyle(color: colors.textSecondary),
                    hintStyle: TextStyle(color: colors.inputPlaceholder),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            color: colors.background,
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _useManualCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Use Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrFramePainter extends CustomPainter {
  _QrFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const inset = 36.0;
    const corner = 28.0;
    const left = inset;
    const top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;

    // Top-left
    canvas.drawLine(Offset(left, top + corner), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + corner, top), paint);
    // Top-right
    canvas.drawLine(Offset(right - corner, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + corner), paint);
    // Bottom-left
    canvas.drawLine(Offset(left, bottom - corner), Offset(left, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + corner, bottom), paint);
    // Bottom-right
    canvas.drawLine(Offset(right - corner, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - corner), paint);
  }

  @override
  bool shouldRepaint(covariant _QrFramePainter oldDelegate) =>
      oldDelegate.color != color;
}
