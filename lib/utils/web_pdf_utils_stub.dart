import 'dart:typed_data';
import 'package:flutter/material.dart';

class WebPdfViewerScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const WebPdfViewerScreen({Key? key, required this.pdfBytes, required this.fileName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: const Center(
        child: Text('PDF viewer is only supported on web platforms'),
      ),
    );
  }
}

Widget createWebPdfViewer(Uint8List pdfBytes, String fileName) {
  return WebPdfViewerScreen(pdfBytes: pdfBytes, fileName: fileName);
}