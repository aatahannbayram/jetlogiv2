import 'package:dijigoo_kurye/session.dart';
import 'package:dijigoo_kurye/signature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imza kanıtı finalize kuyruğuna yazılır', () {
    final session = SessionController();
    session.skipToDemo();
    final task = session.tasks.first;
    final proof = SignatureCapture(
      strokes: [
        [const Offset(10, 20), const Offset(40, 50)],
      ],
      size: const Size(100, 80),
      capturedAt: DateTime.utc(2026, 9, 7, 0, 42),
    ).toProof();

    session.deliverTask(task.id, receivedBy: 'Alıcının kendisi', proof: proof);

    expect(task.signed, isTrue);
    expect(task.status.name, 'delivered');
    final event = session.outbox.events.last;
    final body = event.payload['proof'] as Map;
    expect(body['type'], 'RECIPIENT_SIGNATURE');
    expect(body['channel'], 'WET_INK_CAPTURE');
    expect(body['pointCount'], 2);
    expect((body['btk'] as Map)['qualified'], isFalse);
    expect(((body['strokes'] as List).first as List).first, {
      'x': 0.1,
      'y': 0.25,
    });
  });
}
