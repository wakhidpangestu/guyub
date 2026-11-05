import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// The phone or laptop camera, reading QR codes.
///
/// On the web, mobile_scanner uses the browser's BarcodeDetector where it
/// exists (Chrome on Android) and a WebAssembly ZXing build otherwise. The
/// browser asks for camera permission the first time.
class CameraScanner extends StatefulWidget {
  const CameraScanner({super.key, required this.onCode});

  final ValueChanged<String> onCode;

  /// Replaces the camera in widget tests, where no camera plugin exists.
  @visibleForTesting
  static Widget Function(ValueChanged<String> onCode)? debugBuilder;

  @override
  State<CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends State<CameraScanner> {
  MobileScannerController? _controller;

  @override
  void initState() {
    super.initState();
    if (CameraScanner.debugBuilder == null) {
      _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
    }
  }

  @override
  void dispose() {
    // Turns the camera off when the door screen closes.
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debug = CameraScanner.debugBuilder;
    if (debug != null) return debug(widget.onCode);

    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final value = barcode.rawValue;
                  if (value != null && value.isNotEmpty) widget.onCode(value);
                }
              },
              errorBuilder: (context, error) => _CameraProblem(error.errorCode),
            ),
            // Aiming frame.
            IgnorePointer(
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.7,
                  heightFactor: 0.7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.primary, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem(this.code);

  final MobileScannerErrorCode code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = switch (code) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera access is blocked. Allow the camera for this site, or type or paste the code below.',
      MobileScannerErrorCode.unsupported => 'This browser cannot use a camera. Type or paste the code below.',
      _ => 'The camera did not start. Type or paste the code below.',
    };
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined, size: 40, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
