import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'secure.dart';

/// Performanslı çok katmanlı saha günlüğü.
///
/// Sıcak yol O(1): halka tampon (800 kayıt). Disk I/O her satırda değil,
/// 400ms debounce + tek append. Dosya ~256KB'ı aşınca rotate.
enum LogLayer { boot, ui, session, shift, sync, route, net }

class LogRec {
  const LogRec({
    required this.at,
    required this.level,
    required this.layer,
    required this.message,
  });

  final DateTime at;
  final String level;
  final LogLayer layer;
  final String message;

  String get line =>
      '${at.toIso8601String().substring(11, 23)} ${level.padRight(5)} ${layer.name.padRight(7)} $message';
}

class DgLog {
  DgLog._();

  static const _cap = 800;
  static const _fileBudget = 256 * 1024;
  static final ListQueue<LogRec> _ring = ListQueue(_cap);
  static final Map<LogLayer, int> counts = {for (final l in LogLayer.values) l: 0};
  static File? _file;
  static final StringBuffer _pending = StringBuffer();
  static Timer? _flush;
  static bool _writing = false;

  static void d(LogLayer layer, String message) =>
      _add('debug', layer, message);
  static void i(LogLayer layer, String message) =>
      _add('info', layer, message);
  static void w(LogLayer layer, String message) =>
      _add('warn', layer, message);
  static void e(LogLayer layer, String message) =>
      _add('error', layer, message);

  static List<LogRec> snapshot({int last = 40}) {
    if (_ring.length <= last) return List<LogRec>.from(_ring);
    return _ring.toList(growable: false).sublist(_ring.length - last);
  }

  static Future<void> attach() async {
    if (kIsWeb || kReleaseMode) return;
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File('${dir.path}/dijigoo.log');
      _scheduleFlush();
    } catch (_) {}
  }

  static void _add(String level, LogLayer layer, String message) {
    final rec = LogRec(
      at: DateTime.now(),
      level: level,
      layer: layer,
      message: redactForLog(message),
    );
    if (_ring.length == _cap) _ring.removeFirst();
    _ring.addLast(rec);
    counts[layer] = (counts[layer] ?? 0) + 1;
    _pending.writeln(rec.line);
    if (kDebugMode) debugPrint('[${layer.name}] $message');
    _scheduleFlush();
  }

  static void _scheduleFlush() {
    _flush?.cancel();
    _flush = Timer(const Duration(milliseconds: 400), unawaitedFlush);
  }

  static Future<void> unawaitedFlush() async {
    if (_writing || _pending.isEmpty || _file == null) return;
    final chunk = _pending.toString();
    _pending.clear();
    _writing = true;
    try {
      final f = _file!;
      await f.writeAsString(chunk, mode: FileMode.append, flush: false);
      if (await f.length() > _fileBudget) {
        final keep = await f.readAsBytes();
        final cut = keep.length > _fileBudget ~/ 2
            ? keep.sublist(keep.length - _fileBudget ~/ 2)
            : keep;
        await f.writeAsBytes(cut, flush: false);
      }
    } catch (_) {
    } finally {
      _writing = false;
    }
  }
}
