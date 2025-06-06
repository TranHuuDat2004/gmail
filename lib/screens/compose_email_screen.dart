// lib/screens/compose_email_screen.dart
import 'dart:convert';
import 'dart:io'; // For File
import 'dart:typed_data'; // For Uint8List (web bytes)
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:url_launcher/url_launcher.dart'; // Thêm import này
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart'; // Đảm bảo bạn đã thêm package này

// Conditional import for web PDF viewer
import '../utils/web_pdf_utils_stub.dart'
    if (dart.library.html) '../utils/web_pdf_utils_web.dart'
    as web_pdf_utils;


// Màn hình xem trước PDF cho Web
class WebPdfViewerScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;

  const WebPdfViewerScreen({Key? key, required this.pdfBytes, required this.fileName}) : super(key: key);

  @override
  _WebPdfViewerScreenState createState() => _WebPdfViewerScreenState();
}

class _WebPdfViewerScreenState extends State<WebPdfViewerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF202124) : Colors.white,
        iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.black54),
      ),
      body: const Center(child: Text('PDF viewer not supported on this platform')),
    );
  }
}


class ComposeEmailScreen extends StatefulWidget {
  final Map<String, dynamic>? replyOrForwardEmail;
  final String? composeMode;
  final String? recipientEmail;
  final String? subject;
  final String? initialBody;
  final bool isReply;
  final bool isReplyAll;
  final bool isForward;
  final Map<String, dynamic>? originalEmail;
  final Map<String, dynamic>? draftToLoad; // Added for loading draft data

  const ComposeEmailScreen({
    super.key,
    this.replyOrForwardEmail,
    this.composeMode,
    this.recipientEmail,
    this.subject,
    this.initialBody,
    this.isReply = false,
    this.isReplyAll = false,
    this.isForward = false,
    this.originalEmail,
    this.draftToLoad, // Added
  });

  @override
  State<ComposeEmailScreen> createState() => _ComposeEmailScreenState();
}

class _ComposeEmailScreenState extends State<ComposeEmailScreen> {
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _ccController = TextEditingController();
  final TextEditingController _bccController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  late quill.QuillController _quillController;
  final FocusNode _quillFocusNode = FocusNode();
  bool _showCcBcc = false;
  List<File> _attachments = [];
  Map<String, Uint8List> _webAttachmentData = {};  String? _draftId;
  Timer? _debounceTimer;
  bool _isSending = false;

  String _defaultFontFamily = 'Roboto';
  double _defaultEditorFontSize = 14.0;
  bool _isLoadingAppSettings = true;
  bool _toHasError = false;
  bool _ccHasError = false;
  bool _bccHasError = false;
  @override
  @override
@override
  void initState() {
    super.initState();
    _quillController = quill.QuillController.basic();
    _quillController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    // SỬA: Thêm các listeners để xóa lỗi khi người dùng nhập liệu
    _toController.addListener(() {
      if (_toHasError) setState(() => _toHasError = false);
    });
    _ccController.addListener(() {
      if (_ccHasError) setState(() => _ccHasError = false);
    });
    _bccController.addListener(() {
      if (_bccHasError) setState(() => _bccHasError = false);
    });
    
    _loadAppSettingsAndInitialize();
  }

  Future<void> _viewAttachmentPreview(File file) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    // Đối với web, file.path chính là fileName. Đối với mobile, cần trích xuất.
    final String fileName = kIsWeb ? file.path : file.path.split('/').last.split('\\\\').last;
    final String fileExtension = fileName.split('.').last.toLowerCase();

    if (fileExtension == 'pdf') {
      if (kIsWeb) {
        final Uint8List? pdfData = _webAttachmentData[fileName];
        if (pdfData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => web_pdf_utils.createWebPdfViewer(pdfData, fileName),
            ),
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Không tìm thấy dữ liệu cho file PDF: $fileName')),
            );
          }
        }
      } else { // Mobile PDF
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(fileName),
                backgroundColor: isDarkMode ? const Color(0xFF202124) : Colors.white,
                iconTheme: IconThemeData(color: isDarkMode ? Colors.grey[400] : Colors.black54),
              ),
              body: SfPdfViewer.file(file), // 'file' ở đây là File object với full path cho mobile
            ),
          ),
        );
      }
    } else if (['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(fileExtension)) {
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xem trước file Office trên web cần giải pháp viewer chuyên dụng hoặc tải file về máy.')),
          );
        }
      } else { // Mobile Office
        // 'file' ở đây là File object với full path cho mobile
        final uri = Uri.file(file.path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Không tìm thấy ứng dụng để mở file $fileName')),
            );
          }
        }
      }
    } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(fileExtension)) {
        // Xem trước ảnh (đã hoạt động theo mô tả của bạn, nếu cần code cụ thể thì cung cấp thêm)
        // Ví dụ:
        Navigator.push(context, MaterialPageRoute(builder: (_) {
          return Scaffold(
            appBar: AppBar(title: Text(fileName)),
            body: Center(
              child: kIsWeb 
                ? (_webAttachmentData[fileName] != null ? Image.memory(_webAttachmentData[fileName]!) : Text("Không thể tải ảnh"))
                : Image.file(file),
            ),
          );
        }));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chưa hỗ trợ xem trước cho loại file này: $fileExtension')),
        );
      }
    }
  }

  final FocusNode _toFocusNode = FocusNode();
  Future<void> _loadAppSettingsAndInitialize() async {
    setState(() {
      _isLoadingAppSettings = true;
    });

    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userSettings = await FirebaseFirestore.instance
            .collection('user_settings')
            .doc(currentUser.uid)
            .get();
        if (userSettings.exists && userSettings.data() != null) {
          Map<String, dynamic> data = userSettings.data() as Map<String, dynamic>;
          _defaultFontFamily = data['editorFontFamily'] ?? 'Roboto';
          _defaultEditorFontSize = (data['editorFontSize'] as num?)?.toDouble() ?? 14.0;
        }
      } catch (e) {
        print("Error loading user settings: $e");
      }
    }

    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    _fromController.text = currentUserEmail ?? "anonymous@example.com";    // Priority: draftToLoad > replyOrForwardEmail > new email
    if (widget.draftToLoad != null) {
      // Load draft data
      _draftId = widget.draftToLoad!['id'];
      _toController.text = (widget.draftToLoad!['toRecipients'] as List<dynamic>?)?.join(', ') ?? '';
      _ccController.text = (widget.draftToLoad!['ccRecipients'] as List<dynamic>?)?.join(', ') ?? '';
      _bccController.text = (widget.draftToLoad!['bccRecipients'] as List<dynamic>?)?.join(', ') ?? '';
      _subjectController.text = widget.draftToLoad!['subject'] ?? '';
      _showCcBcc = widget.draftToLoad!['showCcBcc'] ?? false;
      
      if (widget.draftToLoad!['bodyDeltaJson'] != null) {
        try {
          final deltaJson = jsonDecode(widget.draftToLoad!['bodyDeltaJson'] as String);
          _quillController = quill.QuillController(
            document: quill.Document.fromJson(deltaJson),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } catch (e) {
          print("Error loading draft bodyDeltaJson: $e");
          final plainText = widget.draftToLoad!['bodyPlainText'] ?? widget.draftToLoad!['body'] ?? '';
          _quillController.document = quill.Document()..insert(0, plainText);
        }
      } else if (widget.draftToLoad!['bodyPlainText'] != null || widget.draftToLoad!['body'] != null) {
        final plainText = widget.draftToLoad!['bodyPlainText'] ?? widget.draftToLoad!['body'] ?? '';
        _quillController.document = quill.Document()..insert(0, plainText);
      }
      
      final attachmentPaths = List<String>.from(widget.draftToLoad!['attachmentLocalPaths'] ?? []);
      _attachments = attachmentPaths.map((path) => File(path)).toList();
    } else if (widget.replyOrForwardEmail != null) {
      _populateFieldsForReplyForward();
      if (widget.replyOrForwardEmail!.containsKey('isDraft') &&
          widget.replyOrForwardEmail!['isDraft'] == true) {
        _draftId = widget.replyOrForwardEmail!['id'];
        _toController.text = (widget.replyOrForwardEmail!['toRecipients'] as List<dynamic>?)?.join(', ') ?? '';
        _ccController.text = (widget.replyOrForwardEmail!['ccRecipients'] as List<dynamic>?)?.join(', ') ?? '';
        _bccController.text = (widget.replyOrForwardEmail!['bccRecipients'] as List<dynamic>?)?.join(', ') ?? '';
        _subjectController.text = widget.replyOrForwardEmail!['subject'] ?? '';
        _showCcBcc = widget.replyOrForwardEmail!['showCcBcc'] ?? false;
        
        if (widget.replyOrForwardEmail!['bodyDeltaJson'] != null) {
          try {
            final deltaJson = jsonDecode(widget.replyOrForwardEmail!['bodyDeltaJson'] as String);
            _quillController = quill.QuillController(
              document: quill.Document.fromJson(deltaJson),
              selection: const TextSelection.collapsed(offset: 0),
            );
          } catch (e) {
            print("Error loading draft bodyDeltaJson: $e");
            final plainText = widget.replyOrForwardEmail!['bodyPlainText'] ?? widget.replyOrForwardEmail!['body'] ?? '';
            _quillController.document = quill.Document()..insert(0, plainText);
          }
        } else if (widget.replyOrForwardEmail!['bodyPlainText'] != null || widget.replyOrForwardEmail!['body'] != null){
          final plainText = widget.replyOrForwardEmail!['bodyPlainText'] ?? widget.replyOrForwardEmail!['body'] ?? '';
          _quillController.document = quill.Document()..insert(0, plainText);
        }
        final attachmentPaths = List<String>.from(widget.replyOrForwardEmail!['attachmentLocalPaths'] ?? []);
        _attachments = attachmentPaths.map((path) => File(path)).toList();
      }
    } else {
      // New email, don't add any default formatting - let Quill handle it naturally
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.replyOrForwardEmail == null && widget.draftToLoad == null) {
          FocusScope.of(context).requestFocus(_toFocusNode);
        }
      });
    }_toController.addListener(_onTextChanged);
    _ccController.addListener(_onTextChanged);
    _bccController.addListener(_onTextChanged);
    _subjectController.addListener(_onTextChanged);
    
    setState(() {
      _isLoadingAppSettings = false;
    });
  }  void _onTextChanged() {
    // Track changes for potential future use
  }
  void _populateFieldsForReplyForward() {
    final email = widget.replyOrForwardEmail!;
    String originalSender = email['senderEmail'] ?? email['from'] ?? '';
    String originalSubject = email['subject'] ?? '';
    
    // Try to load rich text formatting from bodyDeltaJson first
    quill.Document? quotedDocument;
    if (email['bodyDeltaJson'] != null) {
      try {
        final deltaJson = jsonDecode(email['bodyDeltaJson'] as String);
        quotedDocument = quill.Document.fromJson(deltaJson);
      } catch (e) {
        print("Error loading original bodyDeltaJson for reply/forward: $e");
      }
    }
    
    // Fallback to plain text if rich text failed
    if (quotedDocument == null) {
      String originalBody = email['bodyPlainText'] ?? email['body'] ?? email['bodyContent'] ?? '';
      quotedDocument = quill.Document()..insert(0, originalBody);
    }

    if (widget.composeMode == 'reply') {
      _toController.text = originalSender;
      _subjectController.text = originalSubject.toLowerCase().startsWith("re:")
          ? originalSubject
          : "Re: $originalSubject";
      
      // Create new document with quoted content
      _quillController.document = quill.Document()..insert(0, "\n\n");
      _quillController.document.compose(quotedDocument.toDelta(), quill.ChangeSource.local);
    } else if (widget.composeMode == 'replyAll') {
      _toController.text = originalSender;
      List<String> originalCc = List<String>.from(email['ccRecipients'] ?? []);
      _ccController.text = originalCc.join(', ');
      _subjectController.text = originalSubject.toLowerCase().startsWith("re:")
          ? originalSubject
          : "Re: $originalSubject";
      
      // Create new document with quoted content
      _quillController.document = quill.Document()..insert(0, "\n\n");
      _quillController.document.compose(quotedDocument.toDelta(), quill.ChangeSource.local);
    } else if (widget.composeMode == 'forward') {
      _subjectController.text = originalSubject.toLowerCase().startsWith("fwd:")
          ? originalSubject
          : "Fwd: $originalSubject";
      
      // Create new document with quoted content
      _quillController.document = quill.Document()..insert(0, "\n\n");
      _quillController.document.compose(quotedDocument.toDelta(), quill.ChangeSource.local);
    }
    _quillController.moveCursorToPosition(0);
  }

  Future<void> _pickAttachments() async {
    if (!mounted) return;
    final theme = Theme.of(context);

    // Gmail-like restrictions
    const int maxFiles = 25; // Gmail limit
    const int maxFileSizeMB = 25; // Gmail limit per file
    const int maxFileSizeBytes = maxFileSizeMB * 1024 * 1024;

    if (_attachments.length >= maxFiles) {      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chỉ có thể đính kèm tối đa $maxFiles tệp'),
          backgroundColor: theme.brightness == Brightness.dark
              ? Colors.orange[700]
              : Colors.orange[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          // Documents
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf',
          // Images
          'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg',
          // Videos
          'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm',
          // Audio
          'mp3', 'wav', 'aac', 'ogg', 'flac', 'm4a',
          // Archives
          'zip', 'rar', '7z', 'tar', 'gz',
          // Other
          'csv', 'json', 'xml', 'html', 'css', 'js'
        ],
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        List<String> errors = [];
        int filesAdded = 0;

        for (var file in result.files) {
          // Check if we've reached the limit
          if (_attachments.length + filesAdded >= maxFiles) {
            errors.add('Đã đạt giới hạn $maxFiles tệp');
            break;
          }

          // Check file size
          int fileSize = kIsWeb ? (file.bytes?.length ?? 0) : (file.size);
          if (fileSize > maxFileSizeBytes) {
            errors.add('${file.name}: Quá ${maxFileSizeMB}MB');
            continue;
          }

          // Check for duplicates
          bool isDuplicate = _attachments.any((existingFile) =>
              (kIsWeb
                  ? existingFile.path
                  : existingFile.path.split('/').last) ==
              file.name);
          if (isDuplicate) {
            errors.add('${file.name}: Đã tồn tại');
            continue;
          }

          // Add file
          if (kIsWeb) {
            if (file.bytes != null) {
              final tempFile = File(file.name);
              _attachments.add(tempFile);
              _webAttachmentData[file.name] = file.bytes!;
              filesAdded++;
            }
          } else {
            if (file.path != null) {
              _attachments.add(File(file.path!));
              filesAdded++;
            }
          }
        }

        setState(() {});

        if (errors.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Một số tệp không thể thêm:\n${errors.join('\n')}'),
              backgroundColor: theme.brightness == Brightness.dark
                  ? Colors.orange[700]
                  : Colors.orange[800],
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        } else if (filesAdded > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã thêm $filesAdded tệp đính kèm'),
              backgroundColor: theme.brightness == Brightness.dark
                  ? Colors.green[700]
                  : Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chọn tệp: $e'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  Future<void> _sendEmailAndSaveToFirestore() async {
    if (!mounted) return;
    final theme = Theme.of(context); // Get theme for SnackBar & Dialog

    setState(() { _isSending = true; }); // Báo hiệu đang xử lý
    final bool areRecipientsValid = await _validateRecipients();
    if (!areRecipientsValid) {
      setState(() { _isSending = false; }); // Dừng xử lý
      return; // Dừng hàm nếu có email không hợp lệ
    }


    if (_toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter at least one recipient.'),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() { _isSending = false; });
      return;
    }

    // Check if subject is empty and ask for confirmation
    if (_subjectController.text.trim().isEmpty) {
      final bool? sendAnyway = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          final bool isDialogDark = theme.brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDialogDark ? const Color(0xFF2C2C2C) : Colors.white,
            title: Text('Send without subject?',
                style: TextStyle(
                    color: isDialogDark ? Colors.grey[200] : Colors.black87)),
            content: Text('The subject is empty. Send the email anyway?',
                style: TextStyle(
                    color: isDialogDark ? Colors.grey[400] : Colors.black54)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('CANCEL',
                    style: TextStyle(
                        color: isDialogDark
                            ? Colors.blue[300]
                            : Colors.blue[700])),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text('SEND',
                    style: TextStyle(
                        color: isDialogDark
                            ? Colors.blue[300]
                            : Colors.blue[700])),
              ),
            ],
          );
        });
      if (sendAnyway != true) return;
    }

    setState(() {
      _isSending = true;
    });

    DocumentReference docRef = FirebaseFirestore.instance
        .collection('emails')
        .doc(); // Generate ID upfront

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final userEmail =
          FirebaseAuth.instance.currentUser?.email ?? _fromController.text;

      if (userId == null) {
        // MODIFIED
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('User not logged in. Cannot send email.'),
              backgroundColor: theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      List<String> attachmentUrls = [];
      if (_attachments.isNotEmpty) {
        for (int i = 0; i < _attachments.length; i++) {
          File file = _attachments[i];
          String fileName = file.path
              .split('/')
              .last
              .split('\\')
              .last; // Handle both / and \ separators
          try {
            Reference ref = FirebaseStorage.instance
                .ref()
                .child('email_attachments')
                .child(docRef.id)
                .child(fileName);

            UploadTask uploadTask;
            if (kIsWeb && _webAttachmentData.containsKey(fileName)) {
              // For web, use bytes data
              uploadTask = ref.putData(_webAttachmentData[fileName]!);
            } else {
              // For mobile, use file
              uploadTask = ref.putFile(file);
            }

            TaskSnapshot snapshot = await uploadTask;
            String downloadUrl = await snapshot.ref.getDownloadURL();
            attachmentUrls.add(downloadUrl);
          } catch (e) {
            print('Error uploading attachment ${file.path}: $e');
          }
        }
      }

      List<String> toRecipients = _toController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      List<String> ccRecipients = _ccController.text.isNotEmpty
          ? _ccController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : [];
      List<String> bccRecipients = _bccController.text.isNotEmpty
          ? _bccController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : [];

      // final userId = FirebaseAuth.instance.currentUser?.uid; // Already defined and checked for null
      // final userEmail = FirebaseAuth.instance.currentUser?.email ?? _fromController.text; // Already defined
      final String currentSenderId =
          userId; // Removed the unnecessary '!' operator

      // Initialize email properties
      Map<String, List<String>> emailLabels = {};
      Map<String, bool> emailIsReadBy = {};
      List<String> involvedUserIds = [];

      // 1. Handle Sender
      // The sender's ID should already be in involvedUserIds if they are a recipient.
      // If not, add them now. The primary label for the sender is 'Sent'.
      if (!involvedUserIds.contains(currentSenderId)) {
        involvedUserIds.add(currentSenderId);
      }
      emailLabels[currentSenderId] = ['Sent'];
      emailIsReadBy[currentSenderId] =
          true; // Sent mail is initially marked as read for the sender.      // 2. Handle Recipients (TO, CC, BCC separately to ensure all get proper labels)

      // Process TO recipients
      for (String recipientEmail in toRecipients) {
        if (recipientEmail.isEmpty) continue;

        try {
          var userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: recipientEmail)
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            String recipientId = userQuery.docs.first.id;

            if (!involvedUserIds.contains(recipientId)) {
              involvedUserIds.add(recipientId);
            }

            // Add 'Inbox' label for TO recipients
            List<String> currentLabels = emailLabels[recipientId] ?? [];
            if (!currentLabels.contains('Inbox')) {
              currentLabels.add('Inbox');
            }
            emailLabels[recipientId] = currentLabels.toSet().toList();
            emailIsReadBy[recipientId] = false;

            print(
                '✅ TO recipient processed: $recipientEmail -> $recipientId with Inbox label');
          } else {
            print(
                '❌ TO recipient email $recipientEmail not found in users collection.');
          }
        } catch (e) {
          print('❌ Error fetching TO recipient UID for $recipientEmail: $e');
        }
      }

      // Process CC recipients
      for (String recipientEmail in ccRecipients) {
        if (recipientEmail.isEmpty) continue;

        try {
          var userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: recipientEmail)
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            String recipientId = userQuery.docs.first.id;

            if (!involvedUserIds.contains(recipientId)) {
              involvedUserIds.add(recipientId);
            }

            // Add 'Inbox' label for CC recipients
            List<String> currentLabels = emailLabels[recipientId] ?? [];
            if (!currentLabels.contains('Inbox')) {
              currentLabels.add('Inbox');
            }
            emailLabels[recipientId] = currentLabels.toSet().toList();
            emailIsReadBy[recipientId] = false;

            print(
                '✅ CC recipient processed: $recipientEmail -> $recipientId with Inbox label');
          } else {
            print(
                '❌ CC recipient email $recipientEmail not found in users collection.');
          }
        } catch (e) {
          print('❌ Error fetching CC recipient UID for $recipientEmail: $e');
        }
      }

      // Process BCC recipients
      for (String recipientEmail in bccRecipients) {
        if (recipientEmail.isEmpty) continue;

        try {
          var userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: recipientEmail)
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            String recipientId = userQuery.docs.first.id;

            if (!involvedUserIds.contains(recipientId)) {
              involvedUserIds.add(recipientId);
            }

            // Add 'Inbox' label for BCC recipients
            List<String> currentLabels = emailLabels[recipientId] ?? [];
            if (!currentLabels.contains('Inbox')) {
              currentLabels.add('Inbox');
            }
            emailLabels[recipientId] = currentLabels.toSet().toList();
            emailIsReadBy[recipientId] = false;

            print(
                '✅ BCC recipient processed: $recipientEmail -> $recipientId with Inbox label');
          } else {
            print(
                '❌ BCC recipient email $recipientEmail not found in users collection.');
          }
        } catch (e) {
          print('❌ Error fetching BCC recipient UID for $recipientEmail: $e');
        }
      }

      final bodyPlainText = _quillController.document.toPlainText();
      final bodyDeltaJson = jsonEncode(_quillController.document.toDelta().toJson());

      final String? finalSubject = _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim();
      final String? finalBodyPlainText = bodyPlainText.trim().isEmpty ? null : bodyPlainText.trim();

      final emailData = {
        'senderId': currentSenderId,
        'from': userEmail,
        'toRecipients': toRecipients,
        'ccRecipients': ccRecipients,
        'bccRecipients': bccRecipients,
        'subject': finalSubject,
        'body': finalBodyPlainText, // Ensure this key is 'body' if that's what email_list_item expects for bodyPlainText
        'bodyPlainText': finalBodyPlainText, // Keeping this for explicit storage if needed elsewhere
        'bodyDeltaJson': bodyDeltaJson,
        'timestamp': FieldValue.serverTimestamp(),
        'attachments': attachmentUrls,
        'hasAttachment': attachmentUrls.isNotEmpty, // Added this line
        'emailLabels': emailLabels,
        'emailIsReadBy': emailIsReadBy,
        'involvedUserIds': involvedUserIds.toSet().toList(),
      };

      await docRef.set(emailData);

      // Xóa nháp nếu đang chỉnh sửa
      if (_draftId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('drafts')
            .doc(_draftId)
            .delete();
        _draftId = null;
      }

      print('Email saved to Firestore with ID: ${docRef.id}');

      if (mounted) {
        // MODIFIED
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email sent successfully!'),
            backgroundColor: theme.brightness == Brightness.dark
                ? Colors.green[700]
                : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }

      // After successful email save, check for auto reply
      await _checkAndSendAutoReply(toRecipients, ccRecipients, bccRecipients, 
          _subjectController.text.trim(), userEmail);

    } catch (e) {
      if (mounted) {
        // MODIFIED
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email: $e'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        // MODIFIED
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<bool> _validateRecipients() async {
    // Reset trạng thái lỗi trước mỗi lần kiểm tra
    setState(() {
      _toHasError = false;
      _ccHasError = false;
      _bccHasError = false;
    });

    List<String> parseEmails(String text) {
      return text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final toEmails = parseEmails(_toController.text);
    final ccEmails = parseEmails(_ccController.text);
    final bccEmails = parseEmails(_bccController.text);

    final allUniqueEmails = {...toEmails, ...ccEmails, ...bccEmails}.toList();

    if (allUniqueEmails.isEmpty) {
      // Logic kiểm tra trường "To" rỗng đã có ở hàm send, nên ở đây ta coi là hợp lệ
      return true;
    }
    
    Set<String> validEmailsInDB = {};
    
    // Firestore "whereIn" chỉ hỗ trợ tối đa 30 item mỗi lần, nên ta phải chia nhỏ nếu cần
    for (var i = 0; i < allUniqueEmails.length; i += 30) {
      var chunk = allUniqueEmails.sublist(i, i + 30 > allUniqueEmails.length ? allUniqueEmails.length : i + 30);
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', whereIn: chunk)
            .get();
        
        for (var doc in querySnapshot.docs) {
          validEmailsInDB.add(doc['email'] as String);
        }
      } catch (e) {
        print("Error validating emails: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi khi kiểm tra email: $e")),
        );
        return false; // Dừng lại nếu có lỗi truy vấn DB
      }
    }
    
    final invalidEmails = allUniqueEmails.where((email) => !validEmailsInDB.contains(email)).toSet();

    if (invalidEmails.isNotEmpty) {
      setState(() {
        _toHasError = toEmails.any((email) => invalidEmails.contains(email));
        _ccHasError = ccEmails.any((email) => invalidEmails.contains(email));
        _bccHasError = bccEmails.any((email) => invalidEmails.contains(email));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Một số email người nhận không hợp lệ: ${invalidEmails.join(", ")}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false; // Có email không hợp lệ
    }

    return true; // Tất cả email đều hợp lệ
  }


  Future<void> _checkAndSendAutoReply(List<String> toRecipients, List<String> ccRecipients, 
      List<String> bccRecipients, String originalSubject, String senderEmail) async {
    try {
      // Get all recipient emails
      List<String> allRecipients = [...toRecipients, ...ccRecipients, ...bccRecipients];
      
      for (String recipientEmail in allRecipients) {
        // Check if recipient has auto reply enabled
        final userQuery = await FirebaseFirestore.instance
            .collection('user_settings')
            .where('email', isEqualTo: recipientEmail)
            .where('autoReplyEnabled', isEqualTo: true)
            .limit(1)
            .get();
            
        if (userQuery.docs.isNotEmpty) {
          final autoReplySettings = userQuery.docs.first.data();
          final String autoReplySubject = autoReplySettings['autoReplySubject'] ?? 'Automatic Reply';
          final String autoReplyMessage = autoReplySettings['autoReplyMessage'] ?? 
              'I am currently unavailable and will get back to you soon.';
          
          // Get recipient user details
          final recipientUserQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: recipientEmail)
              .limit(1)
              .get();
              
          if (recipientUserQuery.docs.isNotEmpty) {
            final recipientUser = recipientUserQuery.docs.first;
            final recipientUserId = recipientUser.id;
            final recipientDisplayName = recipientUser.data()['displayName'] ?? recipientEmail;
            
            // Send auto reply email
            await _sendAutoReplyEmail(
              fromUserId: recipientUserId,
              fromEmail: recipientEmail,
              fromDisplayName: recipientDisplayName,
              toEmail: senderEmail,
              subject: autoReplySubject,
              message: autoReplyMessage,
              originalSubject: originalSubject,
            );
          }
        }
      }
    } catch (e) {
      print('Error checking auto reply: $e');
    }
  }

  Future<void> _sendAutoReplyEmail({
    required String fromUserId,
    required String fromEmail,
    required String fromDisplayName,
    required String toEmail,
    required String subject,
    required String message,
    required String originalSubject,
  }) async {
    try {
      // Get sender user ID
      String? senderUserId;
      final senderQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: toEmail)
          .limit(1)
          .get();
          
      if (senderQuery.docs.isNotEmpty) {
        senderUserId = senderQuery.docs.first.id;
      }

      // Create auto reply email document
      final autoReplyEmailData = {
        'from': fromEmail,
        'senderEmail': fromEmail,
        'senderId': fromUserId,
        'senderDisplayName': fromDisplayName,
        'toRecipients': [toEmail],
        'ccRecipients': [],
        'bccRecipients': [],
        'subject': subject,
        'body': message,
        'bodyPlainText': message,
        'timestamp': FieldValue.serverTimestamp(),
        'attachmentUrls': [],
        'isAutoReply': true, // Mark as auto reply
        'originalSubject': originalSubject,
        'involvedUserIds': senderUserId != null ? [fromUserId, senderUserId] : [fromUserId],
        'emailLabels': senderUserId != null ? {
          fromUserId: ['Sent'],
          senderUserId: ['Inbox']
        } : {
          fromUserId: ['Sent']
        },
        'emailIsReadBy': senderUserId != null ? {
          fromUserId: true,
          senderUserId: false
        } : {
          fromUserId: true
        },
        'isTrashedBy': [],
        'permanentlyDeletedBy': [],
      };

      // Add recipient details
      if (senderUserId != null) {
        autoReplyEmailData['recipientIds'] = [senderUserId];
        autoReplyEmailData['recipientEmails'] = [toEmail];
        
        // Get sender display name
        final senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(senderUserId)
            .get();
        if (senderDoc.exists) {
          final senderDisplayName = senderDoc.data()?['displayName'] ?? toEmail;
          autoReplyEmailData['recipientDisplayNames'] = [senderDisplayName];
        } else {
          autoReplyEmailData['recipientDisplayNames'] = [toEmail];
        }
      } else {
        autoReplyEmailData['recipientIds'] = [];
        autoReplyEmailData['recipientEmails'] = [toEmail];
        autoReplyEmailData['recipientDisplayNames'] = [toEmail];
      }

      // Save auto reply email to Firestore
      await FirebaseFirestore.instance
          .collection('emails')
          .add(autoReplyEmailData);

      print('Auto reply sent from $fromEmail to $toEmail');

    } catch (e) {
      print('Error sending auto reply: $e');
    }
  }

  Future<void> _saveDraft() async {
    if (!mounted) return;
    final theme = Theme.of(context);

    final bodyPlainText = _quillController.document.toPlainText().trim();
    final bodyDeltaJson = jsonEncode(_quillController.document.toDelta().toJson());

    final String? finalSubject = _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim();
    final String? finalBodyPlainText = bodyPlainText.isEmpty ? null : bodyPlainText;

    if (finalBodyPlainText == null &&
        finalSubject == null &&
        _toController.text.trim().isEmpty &&
        _attachments.isEmpty) {
      Navigator.pop(context);
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in.");

      List<String> attachmentLocalPaths = _attachments.map((f) => f.path).toList();

      final draftData = {
        'from': _fromController.text,
        'toRecipients': _toController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'ccRecipients': _ccController.text.isNotEmpty
            ? _ccController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : [],
        'bccRecipients': _bccController.text.isNotEmpty
            ? _bccController.text.split(',').map((e) => e.trim()).toList()
            : [],
        'subject': finalSubject,
        'bodyPlainText': finalBodyPlainText,
        'bodyDeltaJson': bodyDeltaJson,
        'attachmentLocalPaths': attachmentLocalPaths,
        'timestamp': FieldValue.serverTimestamp(),
        'showCcBcc': _showCcBcc,
      };

      if (_draftId != null) {
        // Cập nhật nháp hiện có
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('drafts')
            .doc(_draftId)
            .set(draftData, SetOptions(merge: true));
      } else {
        // Tạo nháp mới
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('drafts')
            .add(draftData);
        _draftId = docRef.id;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Draft saved.'),
            backgroundColor: theme.brightness == Brightness.dark
                ? Colors.grey[700]
                : Colors.black87,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, {'draftUpdated': true, 'draftId': _draftId});
      }
    } catch (e) {
      print("Error saving draft: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save draft: $e'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  void _discardEmail() {
    final bodyPlainText = _quillController.document.toPlainText().trim();
    if (bodyPlainText.isNotEmpty ||
        _subjectController.text.trim().isNotEmpty ||
        _toController.text.trim().isNotEmpty ||
        _attachments.isNotEmpty) {
      // Auto-save as draft when closing with content
      _saveDraft();
    } else {
      // Just close if no content
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _fromController.dispose();
    _subjectController.dispose();
    _quillController.dispose();
    _quillFocusNode.dispose();
    _toFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAppSettings) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF121212)
            : Colors.white,
        appBar: AppBar(
          title: const Text('Loading...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Đảm bảo các biến này nằm trong build
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final dividerColor = isDarkMode ? Colors.grey[700]! : const Color(0xFFE0E0E0);
    final textFieldTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final cursorColor = isDarkMode ? Colors.blue[300]! : Colors.black;
    final attachmentHeaderColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final attachmentChipBackgroundColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final attachmentChipLabelColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final attachmentChipDeleteIconColor = isDarkMode ? Colors.red[300] : Colors.red[700];
    final linearProgressIndicatorColor = isDarkMode ? Colors.blue[300] : Colors.blueAccent;
    final appBarIconColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final appBarTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final sendIconColor = isDarkMode ? Colors.blue[300] : Colors.blue[700];
    final popupMenuIconColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final popupMenuBackgroundColor = isDarkMode ? Colors.grey[800] : Colors.white;
    final popupMenuTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
        elevation: isDarkMode ? 0.5 : 1.0,
        leading: IconButton(
          icon: Icon(Icons.close, color: appBarIconColor),
          tooltip: 'Hủy thư',
          onPressed: _discardEmail,
        ),
        title: Text(
            widget.composeMode == 'reply'
                ? 'Trả lời'
                : widget.composeMode == 'replyAll'
                    ? 'Trả lời tất cả'
                    : widget.composeMode == 'forward'
                        ? 'Chuyển tiếp'
                        : 'Soạn thư',
            style: TextStyle(
                color: appBarTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
              icon: Icon(Icons.attach_file_outlined, color: appBarIconColor),
              tooltip: 'Đính kèm tệp',
              onPressed: _pickAttachments),
          IconButton(
              icon: Icon(Icons.send_outlined, color: sendIconColor),
              tooltip: 'Gửi',
              onPressed: _isSending ? null : _sendEmailAndSaveToFirestore),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: popupMenuIconColor),
            color: popupMenuBackgroundColor,
            onSelected: (value) async {
              if (value == 'save_draft') {
                _saveDraft();
              } else if (value == 'discard_popup') {
                if (_draftId != null) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Hủy bản nháp này?'),
                      content: const Text('Bản nháp sẽ bị xóa vĩnh viễn.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Hủy'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('drafts')
                          .doc(_draftId)
                          .delete();
                        if (mounted) {
                          Navigator.pop(context, {'draftDeleted': true, 'draftId': _draftId});
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi xóa bản nháp: $e')),
                        );
                      }
                    }
                  }
                } else {
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'save_draft',
                child: Text('Lưu bản nháp',
                    style: TextStyle(color: popupMenuTextColor)),
              ),
              PopupMenuItem<String>(
                value: 'discard_popup',
                child:
                    Text('Hủy bỏ', style: TextStyle(color: popupMenuTextColor)),
              ),            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSending)
            LinearProgressIndicator(
                color: linearProgressIndicatorColor,
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[300]),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(0),
              children: [
                _buildRecipientField(
                  context: context,
                  label: "Đến",
                  controller: _toController,
                  focusNode: _toFocusNode,
                  isInvalid: _toHasError, // Sửa: Thêm dòng này
                  onToggleCcBcc: () {
                    setState(() {
                      _showCcBcc = !_showCcBcc;
                    });
                  },
                ),
                if (_showCcBcc) ...[
                  Divider(
                      height: 0,
                      indent: 16,
                      endIndent: 16,
                      color: dividerColor),
                  _buildRecipientField(
                      context: context,
                      label: "Cc",
                      controller: _ccController,
                      isInvalid: _ccHasError), // Sửa: Thêm dòng này
                  Divider(
                      height: 0,
                      indent: 16,
                      endIndent: 16,
                      color: dividerColor),
                  _buildRecipientField(
                      context: context,
                      label: "Bcc",
                      controller: _bccController,
                      isInvalid: _bccHasError), // Sửa: Thêm dòng này
                ],
                Divider(
                    height: 0, indent: 16, endIndent: 16, color: dividerColor),
                _buildFromField(
                    context: context,
                    controller: _fromController),
                Divider(
                    height: 0, indent: 16, endIndent: 16, color: dividerColor),

                // Sửa 1: Thay thế Row "Chủ đề" bằng một TextField duy nhất
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _subjectController,
                    cursorColor: cursorColor,
                    style: TextStyle(color: textFieldTextColor, fontSize: 16),
                    maxLines: 1, // Đảm bảo chủ đề chỉ nằm trên 1 dòng
                    decoration: InputDecoration(
                      // Sử dụng labelText để tạo placeholder động
                      labelText: 'Chủ đề', 
                      labelStyle: TextStyle(fontSize: 16, color: cursorColor),
                      // Xóa các đường viền
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                  ),
                ),
                Divider(height: 0, color: dividerColor),
             
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(                    children: [
                     const SizedBox(height: 10.0),
                      // Custom simplified toolbar to prevent freezing
                      Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
// Font Family Dropdown
Container(
  margin: const EdgeInsets.all(4),
  padding: const EdgeInsets.symmetric(horizontal: 8),
  decoration: BoxDecoration(
    border: Border.all(color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!),
    borderRadius: BorderRadius.circular(4),
  ),
  child: DropdownButtonHideUnderline(
    child: DropdownButton<String>(
      // Lấy font hiện tại từ selection hoặc typing attributes
      value: _getCurrentFontFamily(),
      style: TextStyle(color: textFieldTextColor, fontSize: 12),
      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
      // Chỉ hiển thị các font bạn đã khai báo trong pubspec.yaml
      // Đảm bảo tên 'TimesNewRoman' khớp với 'family' trong pubspec.yaml
      items: ['Arial', 'Roboto', 'TimesNewRoman'].map((font) {
        return DropdownMenuItem(
          value: font,
          child: Text(font, style: TextStyle(fontFamily: font, fontSize: 12))
        );
      }).toList(),
      onChanged: (font) {
        if (font != null) {
          // Áp dụng font cho selection hoặc typing attributes
          _applyFontAndSizeToSelection(fontFamily: font);
        }
      },
    ),
  ),
),
// Font Size Dropdown
Container(
  margin: const EdgeInsets.all(4),
  padding: const EdgeInsets.symmetric(horizontal: 8),
  decoration: BoxDecoration(
    border: Border.all(color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!),
    borderRadius: BorderRadius.circular(4),
  ),
  child: DropdownButtonHideUnderline(
    child: DropdownButton<double>(
      // Lấy font size hiện tại từ selection hoặc typing attributes
      value: _getCurrentFontSize(),
      style: TextStyle(color: textFieldTextColor, fontSize: 12),
      dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
      items: [10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 24.0].map((size) {
        return DropdownMenuItem(
            value: size,
            // Hiển thị 'pt' cho rõ ràng hơn
            child: Text('${size.toInt()}pt')
        );
      }).toList(),
      onChanged: (size) {
        if (size != null) {
          // Áp dụng font size cho selection hoặc typing attributes
          _applyFontAndSizeToSelection(fontSize: size);
        }
      },
    ),
  ),
),                              // Basic formatting buttons
                              _buildToolbarButton(Icons.format_bold, () {
                                _formatText('bold');
                                setState(() {}); // Update button states immediately
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted) _quillFocusNode.requestFocus();
                                });
                              }, isDarkMode, isToggled: _isFormatActive('bold')),
                              _buildToolbarButton(Icons.format_italic, () {
                                _formatText('italic');
                                setState(() {}); // Update button states immediately
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted) _quillFocusNode.requestFocus();
                                });
                              }, isDarkMode, isToggled: _isFormatActive('italic')),
                              _buildToolbarButton(Icons.format_underlined, () {
                                _formatText('underline');
                                setState(() {}); // Update button states immediately
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted) _quillFocusNode.requestFocus();
                                });
                              }, isDarkMode, isToggled: _isFormatActive('underline')),
                              const VerticalDivider(width: 1),
                              _buildToolbarButton(Icons.format_align_left, () {
                                _formatText('align-left');
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted) _quillFocusNode.requestFocus();
                                });
                              }, isDarkMode),
                              _buildToolbarButton(Icons.format_align_center, () {
                                _formatText('align-center');
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted) _quillFocusNode.requestFocus();
                                });
                              }, isDarkMode),
                              _buildToolbarButton(Icons.format_align_right, () {
                                _formatText('align-right');
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted) _quillFocusNode.requestFocus();
                                });
                              }, isDarkMode),
                              const VerticalDivider(width: 1),
                              _buildToolbarButton(Icons.format_list_bulleted, () {
                                _formatText('list-bullet');
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted) _quillFocusNode.requestFocus();
                                });
                              }, isDarkMode),
                              _buildToolbarButton(Icons.format_list_numbered, () {
                                _formatText('list-numbered');
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted) _quillFocusNode.requestFocus();
                                });
                              }, isDarkMode),
                              const VerticalDivider(width: 1),
                              _buildToolbarButton(Icons.format_clear, () {
                                _formatText('clear');
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted) _quillFocusNode.requestFocus();
                                });
                              }, isDarkMode),
                            ],
                          ),
                        ),
                      ),                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: 200,
                          maxHeight: 400,
                        ),                        child: quill.QuillEditor.basic(
                          focusNode: _quillFocusNode,
                          configurations: quill.QuillEditorConfigurations(
                            controller: _quillController,
                            placeholder: "Soạn email...",
                            sharedConfigurations: quill.QuillSharedConfigurations(
                              locale: const Locale('vi'),
                            ),
                            scrollable: true,
                            autoFocus: false,
                            padding: const EdgeInsets.all(16),
                            expands: false,
                            customStyles: quill.DefaultStyles(
                              paragraph: quill.DefaultTextBlockStyle(
                                TextStyle(
                                  fontSize: _defaultEditorFontSize,
                                  fontFamily: _defaultFontFamily,
                                  color: textFieldTextColor,
                                ),
                                const quill.VerticalSpacing(0, 8),
                                const quill.VerticalSpacing(0, 0),
                                null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_attachments.isNotEmpty) ...[
                  Divider(height: 1, color: dividerColor),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, top: 16.0, bottom: 8.0),
                    child: Text("Tệp đính kèm (${_attachments.length}):",
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: attachmentHeaderColor)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _attachments.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final File fileEntry = entry.value; // Đổi tên biến để tránh nhầm lẫn với 'file' trong scope khác
                        String currentFileName = kIsWeb
                            ? fileEntry.path
                            : fileEntry.path.split('/').last.split('\\\\').last;

                        Widget chipContent = Chip(
                          backgroundColor: attachmentChipBackgroundColor,
                          avatar: Icon(_getFileIcon(currentFileName),
                              size: 18, color: attachmentChipLabelColor),
                          label: Text(
                            currentFileName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: attachmentChipLabelColor,
                                fontSize: 12),
                          ),
                          onDeleted: () {
                            setState(() {
                              // fileKey cho _webAttachmentData phải là fileName
                              String fileKeyForWebData = kIsWeb ? fileEntry.path : fileEntry.path.split('/').last.split('\\\\').last;
                              _webAttachmentData.remove(fileKeyForWebData);
                              _attachments.removeAt(index);
                            });
                          },
                          deleteIconColor: attachmentChipDeleteIconColor,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                        
                        return GestureDetector(
                          onTap: () {
                            // fileEntry ở đây là File object đã được lưu trong _attachments
                            // Đối với web, path của nó là fileName. Đối với mobile, path là full path.
                            _viewAttachmentPreview(fileEntry);
                          },
                          child: Container( // Container đã có sẵn trong code của bạn
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.4),
                            child: chipContent,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildRecipientField(
      {required BuildContext context,
      required String label,
      required TextEditingController controller,
      FocusNode? focusNode,
      VoidCallback? onToggleCcBcc,
      bool isInvalid = false}) { // SỬA: Thêm tham số isInvalid
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textFieldTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final cursorColor = isDarkMode ? Colors.blue[300]! : Colors.black;
    final iconColor = isDarkMode ? Colors.grey[400] : Colors.black54;

    return Container(
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            child: Text(label,
                style: TextStyle(
                  fontSize: 16,
                  // SỬA: Dùng isInvalid để đổi màu thành đỏ nếu có lỗi
                  color: isInvalid ? Colors.red.shade400 : cursorColor,
                )),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorColor: cursorColor,
              style: TextStyle(color: textFieldTextColor, fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16.0),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          if (label == "Đến")
            IconButton(
              icon: Icon(_showCcBcc ? Icons.expand_less : Icons.expand_more,
                  color: iconColor),
              tooltip: _showCcBcc ? 'Hide Cc/Bcc' : 'Show Cc/Bcc',
              onPressed: onToggleCcBcc,
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
  Widget _buildFromField(
      {required BuildContext context,
      required TextEditingController controller}) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textFieldTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final cursorColor = isDarkMode ? Colors.blue[300]! : Colors.black;
    final iconColor = isDarkMode ? Colors.grey[400] : Colors.black54;

    return Container(
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            child:
                Text("Từ", style: TextStyle(fontSize: 16, color: cursorColor)),
          ),          Expanded(
            child: TextField(
              controller: controller,
              readOnly: true,
              cursorColor: cursorColor,
              style: TextStyle(color: textFieldTextColor, fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16.0),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.expand_more, color: iconColor),
            tooltip: 'Đổi tài khoản gửi',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text("Chọn tài khoản gửi..."),
                backgroundColor: isDarkMode ? Colors.grey[700] : Colors.black87,
                behavior: SnackBarBehavior.floating,
              ));
            },
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          )
        ],
      ),
    );
  }  // Helper methods for custom toolbar
  // Helper: lấy font hiện tại tại vị trí con trỏ hoặc selection (giống Gmail)
// Helper: lấy font hiện tại tại vị trí con trỏ hoặc selection
String _getCurrentFontFamily() {
  // _defaultFontFamily là font được load từ user_settings, dùng làm fallback
  // hoặc font mặc định của editor.
  final attrs = _quillController.getSelectionStyle().attributes;
  return attrs[quill.Attribute.font.key]?.value ?? _defaultFontFamily;
}

// Helper: lấy font size hiện tại tại vị trí con trỏ hoặc selection
double _getCurrentFontSize() {
  // _defaultEditorFontSize là size được load từ user_settings, dùng làm fallback.
  final attrs = _quillController.getSelectionStyle().attributes;
  final sizeValue = attrs[quill.Attribute.size.key]?.value;

  if (sizeValue != null) {
    // Quill có thể lưu size dạng string "12" hoặc "16px"
    // Chuyển đổi an toàn về double
    final String sizeString = sizeValue.toString().replaceAll('px', '');
    final double? parsedSize = double.tryParse(sizeString);
    if (parsedSize != null) {
      return parsedSize;
    }
  }
  return _defaultEditorFontSize;
}

  // Sửa lại _isFormatActive: kiểm tra thực sự selection có định dạng không (giống Gmail)
  // Sửa lại _isFormatActive: kiểm tra thực sự selection có định dạng không (giống Gmail)
bool _isFormatActive(String format) {
  final attrs = _quillController.getSelectionStyle().attributes;
  switch (format) {
    case 'bold':
      return attrs[quill.Attribute.bold.key]?.value == true;
    case 'italic':
      return attrs[quill.Attribute.italic.key]?.value == true;
    case 'underline':
      return attrs[quill.Attribute.underline.key]?.value == true;
    // Bạn có thể thêm các case khác nếu cần, ví dụ:
    // case 'strike':
    //   return attrs[quill.Attribute.strikeThrough.key]?.value == true;
    // case 'code-block':
    //   return attrs[quill.Attribute.codeBlock.key]?.value == true;
  }
  return false;
}

  // Sửa lại _applyFontToSelection: chỉ áp dụng cho selection, nếu không thì chỉ set cho future typing
  // Hàm mới để áp dụng font và/hoặc size
void _applyFontAndSizeToSelection({String? fontFamily, double? fontSize}) {
  final selection = _quillController.selection;

  if (!_quillFocusNode.hasFocus) {
    FocusScope.of(context).requestFocus(_quillFocusNode);
  }

  if (fontFamily != null) {
    if (selection.isValid && !selection.isCollapsed) {
      _quillController.formatText(selection.start, selection.end - selection.start, quill.Attribute.fromKeyValue('font', fontFamily));
    } else {
      _quillController.formatSelection(quill.Attribute.fromKeyValue('font', fontFamily));
    }
  }

  if (fontSize != null) {
    final fontSizeString = fontSize.toStringAsFixed(0);
    if (selection.isValid && !selection.isCollapsed) {
      _quillController.formatText(selection.start, selection.end - selection.start, quill.Attribute.fromKeyValue('size', fontSizeString));
    } else {
      _quillController.formatSelection(quill.Attribute.fromKeyValue('size', fontSizeString));
    }
  }

  if (mounted) {
    setState(() {});
  }
}

  void _formatText(String format) {
  // Đảm bảo editor có focus
  if (!_quillFocusNode.hasFocus) {
    FocusScope.of(context).requestFocus(_quillFocusNode);
  }

  quill.Attribute? attributeToToggle; // Thuộc tính cần bật/tắt (Bold, Italic, Underline)
  bool isCurrentlyActive = false; // Trạng thái hiện tại của thuộc tính đó (active hay không)

  switch (format) {
    case 'bold':
      attributeToToggle = quill.Attribute.bold;
      isCurrentlyActive = _isFormatActive('bold');
      break;
    case 'italic':
      attributeToToggle = quill.Attribute.italic;
      isCurrentlyActive = _isFormatActive('italic');
      break;
    case 'underline':
      attributeToToggle = quill.Attribute.underline;
      isCurrentlyActive = _isFormatActive('underline');
      break;
    case 'align-left':
      _quillController.formatSelection(quill.Attribute.leftAlignment);
      break;
    case 'align-center':
      _quillController.formatSelection(quill.Attribute.centerAlignment);
      break;
    case 'align-right':
      _quillController.formatSelection(quill.Attribute.rightAlignment);
      break;
    case 'list-bullet':
      // Toggle list: nếu đang là list thì bỏ, không thì áp dụng
      // Flutter Quill xử lý việc này khi bạn truyền Attribute.ul
      _quillController.formatSelection(quill.Attribute.ul);
      break;
    case 'list-numbered':
      _quillController.formatSelection(quill.Attribute.ol);
      break;
    case 'clear':
      final selection = _quillController.selection;
      if (selection.isValid && !selection.isCollapsed) { // Nếu có bôi đen
        final int len = selection.end - selection.start;
        // Xóa các định dạng cơ bản cho vùng chọn
        _quillController.formatText(selection.start, len, quill.Attribute.clone(quill.Attribute.bold, null));
        _quillController.formatText(selection.start, len, quill.Attribute.clone(quill.Attribute.italic, null));
        _quillController.formatText(selection.start, len, quill.Attribute.clone(quill.Attribute.underline, null));
        // Tùy chọn: Xóa cả font và size nếu muốn "Clear All Formatting"
        // _quillController.formatText(selection.start, len, quill.Attribute.clone(quill.Attribute.font, null));
        // _quillController.formatText(selection.start, len, quill.Attribute.clone(quill.Attribute.size, null));
      } else { // Nếu chỉ là con trỏ, xóa định dạng cho typing attributes
        _quillController.formatSelection(quill.Attribute.clone(quill.Attribute.bold, null));
        _quillController.formatSelection(quill.Attribute.clone(quill.Attribute.italic, null));
        _quillController.formatSelection(quill.Attribute.clone(quill.Attribute.underline, null));
        // _quillController.formatSelection(quill.Attribute.clone(quill.Attribute.font, null));
        // _quillController.formatSelection(quill.Attribute.clone(quill.Attribute.size, null));
      }
      break;
    default:
      return; // Không làm gì nếu format không xác định
  }

  // Nếu là thuộc tính cần toggle (Bold, Italic, Underline)
  if (attributeToToggle != null) {
    // Nếu đang active, truyền giá trị null để loại bỏ thuộc tính đó (toggle off)
    // Nếu không active, truyền chính thuộc tính đó để áp dụng (toggle on)
    _quillController.formatSelection(isCurrentlyActive ? quill.Attribute.clone(attributeToToggle, null) : attributeToToggle);
  }

  // setState để cập nhật trạng thái nút ngay lập tức.
  // Listener của controller cũng sẽ làm điều này, nhưng có thể có độ trễ nhỏ.
  if (mounted) {
    setState(() {});
  }
}

  Widget _buildToolbarButton(IconData icon, VoidCallback onPressed, bool isDarkMode, {bool isToggled = false}) {
    return Container(
      margin: const EdgeInsets.all(2),
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(
          icon, 
          size: 18,
          color: isToggled 
              ? (isDarkMode ? Colors.blue[300] : Colors.blue[600])
              : (isDarkMode ? Colors.grey[300] : Colors.black87),
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: isToggled 
              ? (isDarkMode ? Colors.blue[900]?.withOpacity(0.3) : Colors.blue[100])
              : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          minimumSize: const Size(36, 36),
          maximumSize: const Size(36, 36),
        ),
      ),
    );
  }

 

  IconData _getFileIcon(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      // Images
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'svg':
        return Icons.image_outlined;

      // Videos
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'webm':
        return Icons.videocam_outlined;

      // Audio
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'ogg':
      case 'flac':
      case 'm4a':
        return Icons.audiotrack_outlined;

      // Documents
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'txt':
      case 'rtf':
        return Icons.article_outlined;

      // Archives
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_outlined;

      // Code files
      case 'html':
      case 'css':
      case 'js':
      case 'json':
      case 'xml':
        return Icons.code_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
