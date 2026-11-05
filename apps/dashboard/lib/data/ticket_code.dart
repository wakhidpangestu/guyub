import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Dynamic QR ticket codes. Mirror of functions/src/tickets.ts; both are
/// tested against the same vector, so change them together.
///
///     G1.{attendanceId}.{window}.{signature}
///
/// window    = floor(unix seconds / [ticketWindowSeconds])
/// signature = first 16 hex chars of HMAC-SHA256(key: qrToken, message: "{attendanceId}.{window}")
const ticketWindowSeconds = 30;

int ticketWindowAt(DateTime time) => time.millisecondsSinceEpoch ~/ 1000 ~/ ticketWindowSeconds;

String ticketSignature(String qrToken, String attendanceId, int window) {
  final hmac = Hmac(sha256, utf8.encode(qrToken));
  return hmac.convert(utf8.encode('$attendanceId.$window')).toString().substring(0, 16);
}

String ticketPayload(String qrToken, String attendanceId, int window) =>
    'G1.$attendanceId.$window.${ticketSignature(qrToken, attendanceId, window)}';

/// Seconds until the code on screen changes.
int secondsUntilNextWindow(DateTime time) {
  final seconds = time.millisecondsSinceEpoch ~/ 1000;
  return ticketWindowSeconds - seconds % ticketWindowSeconds;
}
