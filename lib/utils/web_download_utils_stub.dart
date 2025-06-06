// Stub implementation for non-web platforms
import 'package:flutter/material.dart';

Future<void> actualDownloadFileForWeb(
  String url,
  String fileName,
  BuildContext context,
  Function(double) progressCallback,
) async {
  throw UnsupportedError('Web download is only supported on web platforms');
}
