import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

Future<void> actualDownloadFileForWeb(
  String url,
  String fileName,
  BuildContext context,
  Function(double) progressCallback,
) async {
  try {
    final dio = Dio();
    final response = await dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, total) {
        if (total != -1) {
          progressCallback(received / total);
        }
      },
    );

    final bytes = response.data as List<int>;
    final blob = html.Blob([bytes]);
    final url2 = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement()
      ..href = url2
      ..download = fileName
      ..style.display = 'none';
    
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    
    html.Url.revokeObjectUrl(url2);
    
    if (context.mounted) {
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tải xuống "$fileName"'),
          backgroundColor: theme.brightness == Brightness.dark ? Colors.green[700] : Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    throw Exception('Lỗi web download: $e');
  }
}
