import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/ticket_code.dart';

/// The ticket QR. Its content changes every [ticketWindowSeconds], so a
/// screenshot shared in a chat stops working within about a minute.
class RotatingTicketQr extends StatefulWidget {
  const RotatingTicketQr({super.key, required this.qrToken, required this.attendanceId, this.clock = DateTime.now, this.size = 260});

  final String qrToken;
  final String attendanceId;

  /// Injected in tests.
  final DateTime Function() clock;
  final double size;

  @override
  State<RotatingTicketQr> createState() => _RotatingTicketQrState();
}

class _RotatingTicketQrState extends State<RotatingTicketQr> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // One tick per second drives the countdown; the payload changes when the window does.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock();
    final payload = ticketPayload(widget.qrToken, widget.attendanceId, ticketWindowAt(now));
    final remaining = secondsUntilNextWindow(now);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // White quiet zone: scanners need dark modules on a light background,
        // also in dark mode.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: QrImageView(
            key: ValueKey(payload),
            data: payload,
            size: widget.size,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
            dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
            semanticsLabel: 'Ticket QR code',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: widget.size,
          child: LinearProgressIndicator(
            value: remaining / ticketWindowSeconds,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text('New code in ${remaining}s', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
