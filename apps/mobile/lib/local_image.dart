import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Kamerayla çekilen fotoğrafın önizlemesi. Mobilde dosya yolu, web'de
/// image_picker'ın verdiği `blob:` adresi.
Widget localImage(String path, {BoxFit? fit}) =>
    kIsWeb ? Image.network(path, fit: fit) : Image.file(File(path), fit: fit);

/// Web'de dosya sistemi yok; blob adresi sayfa açık kaldıkça geçerlidir.
bool localFileExists(String path) => kIsWeb || File(path).existsSync();
