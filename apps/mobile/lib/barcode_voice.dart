import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'courier_home.dart';

bool get _widgetTest {
  try {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding') ||
        name.contains('AutomatedTest');
  } catch (_) {
    return true;
  }
}

/// Mikrofon yoksa veya izin verilmezse null. Ekranı kilitlemez.
Future<String?> listenForBarcode() async {
  if (_widgetTest) return null;
  SpeechToText? speech;
  try {
    speech = SpeechToText();
    final ok = await speech.initialize();
    if (!ok) return null;
    final done = Completer<String?>();
    await speech.listen(
      onResult: (result) {
        if (!result.finalResult || done.isCompleted) return;
        done.complete(barcodeFromSpeech(result.recognizedWords));
      },
      localeId: 'tr_TR',
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 6),
        pauseFor: const Duration(seconds: 2),
      ),
    );
    return await done.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
  } catch (_) {
    return null;
  } finally {
    try {
      await speech?.stop();
    } catch (_) {}
  }
}
