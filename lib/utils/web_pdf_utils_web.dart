import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class WebPdfViewerScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const WebPdfViewerScreen({Key? key, required this.pdfBytes, required this.fileName}) : super(key: key);

  @override
  _WebPdfViewerScreenState createState() => _WebPdfViewerScreenState();
}

class _WebPdfViewerScreenState extends State<WebPdfViewerScreen> {
  late String _objectUrl;
  final String _viewType = 'pdf-viewer-iframe';

  @override
  void initState() {
    super.initState();
    final blob = html.Blob([widget.pdfBytes], 'application/pdf');
    _objectUrl = html.Url.createObjectUrlFromBlob(blob);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => html.IFrameElement()
        ..src = _objectUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%',
    );
  }

  @override
  void dispose() {
    html.Url.revokeObjectUrl(_objectUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF202124) : Colors.white,
        iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.black54),
      ),
      body: HtmlElementView(viewType: _viewType),
    );
  }
}

// Factory function for creating web PDF viewer
Widget createWebPdfViewer(Uint8List pdfBytes, String fileName) {
  return WebPdfViewerScreen(pdfBytes: pdfBytes, fileName: fileName);
}