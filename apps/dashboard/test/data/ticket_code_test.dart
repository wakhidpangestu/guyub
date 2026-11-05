import 'package:flutter_test/flutter_test.dart';
import 'package:guyub_dashboard/data/ticket_code.dart';

void main() {
  // Shared with functions/test/registration.test.mts (and checked with
  // `openssl dgst -sha256 -hmac`). Change both together.
  test('matches the server signature for the shared vector', () {
    expect(ticketSignature('test-token-123', 'evt_u1', 59000000), 'dd5bbd670685b044');
    expect(ticketPayload('test-token-123', 'evt_u1', 59000000), 'G1.evt_u1.59000000.dd5bbd670685b044');
  });

  test('window is 30-second buckets of unix time', () {
    final t = DateTime.fromMillisecondsSinceEpoch(59000000 * 30 * 1000, isUtc: true);
    expect(ticketWindowAt(t), 59000000);
    expect(ticketWindowAt(t.add(const Duration(seconds: 29))), 59000000);
    expect(ticketWindowAt(t.add(const Duration(seconds: 30))), 59000001);
  });

  test('countdown runs from 30 down to 1', () {
    final t = DateTime.fromMillisecondsSinceEpoch(59000000 * 30 * 1000, isUtc: true);
    expect(secondsUntilNextWindow(t), 30);
    expect(secondsUntilNextWindow(t.add(const Duration(seconds: 29))), 1);
  });

  test('the code changes between windows', () {
    expect(ticketPayload('tok', 'e_u', 1), isNot(ticketPayload('tok', 'e_u', 2)));
    expect(ticketPayload('tok', 'e_u', 1), isNot(ticketPayload('other', 'e_u', 1)));
  });
}
