import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class FileViewerScreen extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final String fileExtension;

  const FileViewerScreen({
    super.key,
    required this.fileUrl,
    required this.fileName,
    required this.fileExtension,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _textContent;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (_isTextFile(widget.fileExtension)) {
        _textContent = 'File URL: ${widget.fileUrl}\n\nFile này có thể được mở trực tiếp bằng cách sao chép URL trên.';
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải file: $e';
      });
    }
  }

  bool _isTextFile(String extension) {
    const textExtensions = ['txt', 'json', 'xml', 'html', 'css', 'js'];
    return textExtensions.contains(extension.toLowerCase());
  }

  bool _isImageFile(String extension) {
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    return imageExtensions.contains(extension.toLowerCase());
  }  Future<void> _downloadFile() async {
    try {
      if (kIsWeb) {
        // For web - copy URL to clipboard as fallback
        await Clipboard.setData(ClipboardData(text: widget.fileUrl));
        
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Link file "${widget.fileName}" đã được sao chép. Dán vào trình duyệt để tải xuống.'),
              backgroundColor: theme.brightness == Brightness.dark ? Colors.blue[700] : Colors.blue,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // For mobile - download to device storage
        await _downloadFileForMobile();
      }
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải xuống file: $e'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _downloadFileForMobile() async {
    try {
      // Request storage permission
      var status = await Permission.storage.request();
      if (status != PermissionStatus.granted) {
        status = await Permission.manageExternalStorage.request();
        if (status != PermissionStatus.granted) {
          throw Exception('Cần quyền truy cập bộ nhớ để tải file');
        }
      }

      // Get Downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir != null) {
            downloadsDir = Directory('${downloadsDir.path}/Download');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
          }
        }
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Không thể truy cập thư mục tải xuống');
      }

      // Create unique filename if file exists
      String fileName = widget.fileName;
      String savePath = '${downloadsDir.path}/$fileName';
      
      int counter = 1;
      String nameWithoutExt = fileName.contains('.') 
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      String extension = fileName.contains('.') 
          ? fileName.substring(fileName.lastIndexOf('.'))
          : '';
      
      while (await File(savePath).exists()) {
        fileName = '${nameWithoutExt}_$counter$extension';
        savePath = '${downloadsDir.path}/$fileName';
        counter++;
      }

      // Download with Dio
      Dio dio = Dio();
      
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Đang tải xuống ${widget.fileName}...'),
            ],
          ),
        ),
      );

      await dio.download(
        widget.fileUrl,
        savePath,
        onReceiveProgress: (received, total) {
          // Update progress if needed
        },
      );

      // Close progress dialog
      Navigator.pop(context);

      // Show success message
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tải xuống "$fileName" vào thư mục Downloads'),
            backgroundColor: theme.brightness == Brightness.dark ? Colors.green[700] : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Close progress dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      throw Exception('Lỗi mobile download: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF202124) : Colors.white,
        elevation: isDarkMode ? 0.5 : 1.0,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.grey[400] : Colors.black54),
        title: Text(
          widget.fileName,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[200] : Colors.black87,
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: _downloadFile,
            tooltip: 'Tải xuống',
          ),
        ],
      ),
      body: _buildBody(isDarkMode),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDarkMode ? Colors.red[300] : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : Colors.black87,
                fontSize: 16,
              ),              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _downloadFile,
              child: const Text('Tải xuống'),
            ),
          ],
        ),
      );
    }

    // Handle different file types
    if (_isImageFile(widget.fileExtension)) {
      return Center(
        child: InteractiveViewer(
          child: Image.network(
            widget.fileUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Không thể tải hình ảnh',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : Colors.black87,
                      ),
                    ),                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _downloadFile,
                      child: const Text('Tải xuống'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    if (_isTextFile(widget.fileExtension) && _textContent != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: SelectableText(
            _textContent!,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300] : Colors.black87,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
      );
    }

    // For unsupported file types
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 64,
            color: isDarkMode ? Colors.grey[500] : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Không thể xem file loại này',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300] : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'File: ${widget.fileName}',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _downloadFile,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Tải xuống file'),
          ),
        ],
      ),
    );
  }
}