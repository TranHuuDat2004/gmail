// lib/screens/compose_email_screen.dart
import 'dart:io'; // For File
import 'dart:typed_data'; // For Uint8List (web bytes)
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; // Bạn có thể dùng một trong hai hoặc cả hai
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComposeEmailScreen extends StatefulWidget {
  final Map<String, dynamic>?
      replyOrForwardEmail;
  final String?
      composeMode;

  const ComposeEmailScreen({
    super.key,
    this.replyOrForwardEmail,
    this.composeMode,
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
  final TextEditingController _bodyController = TextEditingController();
  bool _showCcBcc = false;
  List<File> _attachments = []; // Sử dụng List<File> cho cả image_picker và file_picker
  Map<String, Uint8List> _webAttachmentData = {}; // Store file bytes for web
  final ImagePicker _imagePicker = ImagePicker(); // Đổi tên để tránh nhầm lẫn nếu dùng cả hai

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    _fromController.text = currentUserEmail ?? "anonymous@example.com";

    if (widget.replyOrForwardEmail != null) {
      _populateFieldsForReplyForward();
    } else {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.replyOrForwardEmail == null) { // MODIFIED
          FocusScope.of(context).requestFocus(_toFocusNode);
        }
      });
    }
  }

  final FocusNode _toFocusNode = FocusNode();

  void _populateFieldsForReplyForward() {
    final email = widget.replyOrForwardEmail!;
    String originalSender = email['senderEmail'] ?? email['from'] ?? '';
    String originalSubject = email['subject'] ?? '';
    String originalBody = email['body'] ?? email['bodyContent'] ?? '';

    String quotedBody =
        "\n\n\n-------- ${widget.composeMode == 'forward' ? 'Forwarded Message' : 'Original Message'} --------\n"
        "From: $originalSender\n"
        "Date: ${email['timestamp'] != null ? email['timestamp'].toString() : 'Unknown date'}\n"
        "Subject: $originalSubject\n"
        "\n$originalBody";

    if (widget.composeMode == 'reply') {
      _toController.text = originalSender;
      _subjectController.text =
          originalSubject.toLowerCase().startsWith("re:")
              ? originalSubject
              : "Re: $originalSubject";
      _bodyController.text = quotedBody;
    } else if (widget.composeMode == 'replyAll') {
      _toController.text = originalSender;
      List<String> originalCc = List<String>.from(email['ccRecipients'] ?? []);
      _ccController.text = originalCc.join(', ');
      _subjectController.text =
          originalSubject.toLowerCase().startsWith("re:")
              ? originalSubject
              : "Re: $originalSubject";
      _bodyController.text = quotedBody;
    } else if (widget.composeMode == 'forward') {
      _subjectController.text =
          originalSubject.toLowerCase().startsWith("fwd:")
              ? originalSubject
              : "Fwd: $originalSubject";
      _bodyController.text = quotedBody;
    }
    _bodyController.selection =
        TextSelection.fromPosition(const TextPosition(offset: 0));
  }  Future<void> _pickAttachments() async {
    if (!mounted) return;
    final theme = Theme.of(context);
    
    // Gmail-like restrictions
    const int maxFiles = 25; // Gmail limit
    const int maxFileSizeMB = 25; // Gmail limit per file
    const int maxFileSizeBytes = maxFileSizeMB * 1024 * 1024;
    
    if (_attachments.length >= maxFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chỉ có thể đính kèm tối đa $maxFiles tệp'),
          backgroundColor: theme.brightness == Brightness.dark ? Colors.orange[700] : Colors.orange[800],
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
            (kIsWeb ? existingFile.path : existingFile.path.split('/').last) == file.name
          );
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
              backgroundColor: theme.brightness == Brightness.dark ? Colors.orange[700] : Colors.orange[800],
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        } else if (filesAdded > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã thêm $filesAdded tệp đính kèm'),
              backgroundColor: theme.brightness == Brightness.dark ? Colors.green[700] : Colors.green,
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

    if (_toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter at least one recipient.'), // MODIFIED
          backgroundColor: theme.brightness == Brightness.dark ? Colors.orange[700] : Colors.orange[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      final sendAnyway = await showDialog<bool>(
        context: context, // MODIFIED
        builder: (dialogContext) {
          final dialogTheme = Theme.of(dialogContext);
          final isDialogDark = dialogTheme.brightness == Brightness.dark;
          return AlertDialog( // MODIFIED
            backgroundColor: isDialogDark ? const Color(0xFF2C2C2C) : Colors.white,
            title: Text('Send without subject?', style: TextStyle(color: isDialogDark ? Colors.grey[200] : Colors.black87)),
            content: Text('The subject is empty. Send the email anyway?', style: TextStyle(color: isDialogDark ? Colors.grey[400] : Colors.black54)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('CANCEL', style: TextStyle(color: isDialogDark ? Colors.blue[300] : Colors.blue[700])),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text('SEND', style: TextStyle(color: isDialogDark ? Colors.blue[300] : Colors.blue[700])),
              ),
            ],
          );
        }
      );
      if (sendAnyway != true) return;
    }

    setState(() { _isSending = true; });

    DocumentReference docRef = FirebaseFirestore.instance.collection('emails').doc(); // Generate ID upfront

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final userEmail = FirebaseAuth.instance.currentUser?.email ?? _fromController.text;

      if (userId == null) { // MODIFIED
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
      }      List<String> attachmentUrls = [];
      if (_attachments.isNotEmpty) {
        for (int i = 0; i < _attachments.length; i++) {
          File file = _attachments[i];
          String fileName = file.path.split('/').last.split('\\').last; // Handle both / and \ separators
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
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Lỗi tải lên tệp $fileName: $e'),
                  backgroundColor: theme.colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      }

      List<String> toRecipients = _toController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      List<String> ccRecipients = _ccController.text.isNotEmpty ? _ccController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : [];
      List<String> bccRecipients = _bccController.text.isNotEmpty ? _bccController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : [];
      
      // final userId = FirebaseAuth.instance.currentUser?.uid; // Already defined and checked for null
      // final userEmail = FirebaseAuth.instance.currentUser?.email ?? _fromController.text; // Already defined
      final String currentSenderId = userId; // Removed the unnecessary '!' operator

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
      emailIsReadBy[currentSenderId] = true; // Sent mail is initially marked as read for the sender.      // 2. Handle Recipients (TO, CC, BCC separately to ensure all get proper labels)
      
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
            
            print('✅ TO recipient processed: $recipientEmail -> $recipientId with Inbox label');
          } else {
            print('❌ TO recipient email $recipientEmail not found in users collection.');
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
            
            print('✅ CC recipient processed: $recipientEmail -> $recipientId with Inbox label');
          } else {
            print('❌ CC recipient email $recipientEmail not found in users collection.');
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
            
            print('✅ BCC recipient processed: $recipientEmail -> $recipientId with Inbox label');
          } else {
            print('❌ BCC recipient email $recipientEmail not found in users collection.');
          }
        } catch (e) {
          print('❌ Error fetching BCC recipient UID for $recipientEmail: $e');
        }
      }
      
      final emailData = {
        'senderId': currentSenderId, // Use currentSenderId
        'from': userEmail,
        'toRecipients': toRecipients,
        'ccRecipients': ccRecipients,
        'bccRecipients': bccRecipients,
        'subject': _subjectController.text.trim(),
        'body': _bodyController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'attachments': attachmentUrls,
        'emailLabels': emailLabels,
        'emailIsReadBy': emailIsReadBy,
        'involvedUserIds': involvedUserIds.toSet().toList(), // Ensure unique UIDs
      };

      await docRef.set(emailData); // MODIFIED - use set with pre-generated docRef
      print('Email saved to Firestore with ID: ${docRef.id}');

      if(mounted) { // MODIFIED
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email sent successfully!'),
            backgroundColor: theme.brightness == Brightness.dark ? Colors.green[700] : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
       if(mounted) { // MODIFIED
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send email: $e'),
              backgroundColor: theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
    } finally {
      if(mounted) { // MODIFIED
        setState(() { _isSending = false; });
      }
    }
  }

  Future<void> _saveDraft() async {
    if (!mounted) return;
    final theme = Theme.of(context); // Get theme for SnackBar
    if (_bodyController.text.trim().isEmpty && _subjectController.text.trim().isEmpty && _toController.text.trim().isEmpty && _attachments.isEmpty) {
      Navigator.pop(context); // Nothing to save
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in.");

      List<String> attachmentLocalPaths = _attachments.map((f) => f.path).toList();

      final draftData = { // MODIFIED
        'from': _fromController.text,
        'toRecipients': _toController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'ccRecipients': _ccController.text.isNotEmpty ? _ccController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : [],
        'bccRecipients': _bccController.text.isNotEmpty ? _bccController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : [],
        'subject': _subjectController.text.trim(),
        'body': _bodyController.text.trim(),
        'attachmentLocalPaths': attachmentLocalPaths,
        'timestamp': FieldValue.serverTimestamp(),
        'showCcBcc': _showCcBcc,
      };

      await FirebaseFirestore.instance.collection('users').doc(userId).collection('drafts').add(draftData);

      if(mounted) { // MODIFIED
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Draft saved.'),
            backgroundColor: theme.brightness == Brightness.dark ? Colors.grey[700] : Colors.black87,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if(mounted) { // MODIFIED
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
     if (_bodyController.text.trim().isNotEmpty || 
         _subjectController.text.trim().isNotEmpty || 
         _toController.text.trim().isNotEmpty || 
         _attachments.isNotEmpty) {
        showDialog( // MODIFIED
          context: context,
          builder: (BuildContext dialogContext) {
            final dialogTheme = Theme.of(dialogContext);
            final isDialogDark = dialogTheme.brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDialogDark ? const Color(0xFF2C2C2C) : Colors.white,
              title: Text('Discard email?', style: TextStyle(color: isDialogDark ? Colors.grey[200] : Colors.black87)),
              content: Text('Are you sure you want to discard this email and lose your changes?', style: TextStyle(color: isDialogDark ? Colors.grey[400] : Colors.black54)),
              actions: <Widget>[
                TextButton(
                  child: Text('CANCEL', style: TextStyle(color: isDialogDark ? Colors.blue[300] : Colors.blue[700])),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  child: Text('DISCARD', style: TextStyle(color: isDialogDark ? Colors.red[300] : Colors.red[700])),
                  style: TextButton.styleFrom(foregroundColor: isDialogDark ? Colors.red[300] : Colors.red[700]), // Ensure foreground color is also themed
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); 
                    Navigator.of(context).pop(); 
                  },
                ),
              ],
            );
          },
        );
     } else {
        Navigator.pop(context);
     }
  }

  @override
  void dispose() {
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _fromController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _toFocusNode.dispose();
    super.dispose();
  }

  // Phần Widget build(BuildContext context) giữ nguyên như bạn đã cung cấp
  // Chỉ cần đảm bảo nút "Gửi" gọi _sendEmailAndSaveToFirestore
  // và các nút/menu khác gọi đúng hàm (_saveDraft, _discardEmail, _pickAttachments)
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define colors based on theme
    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final appBarBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final appBarTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final appBarIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final sendIconColor = _isSending ? (isDarkMode ? Colors.grey[600] : Colors.grey) : (isDarkMode ? Colors.blue[300] : Colors.blueAccent);
    final popupMenuIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final popupMenuBackgroundColor = isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
    final popupMenuTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final dividerColor = isDarkMode ? Colors.grey[700]! : const Color(0xFFE0E0E0);
    final textFieldTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final textFieldHintColor = isDarkMode ? Colors.grey[500] : Colors.black54;
    final cursorColor = isDarkMode ? Colors.blue[300]! : Colors.black;
    final attachmentChipBackgroundColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final attachmentChipLabelColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final attachmentChipDeleteIconColor = isDarkMode ? Colors.red[300] : Colors.red[700];
    final attachmentHeaderColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final linearProgressIndicatorColor = isDarkMode ? Colors.blue[300] : Colors.blueAccent;

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor,
        elevation: isDarkMode ? 0.5 : 1.0, // Slightly different elevation for dark mode
        leading: IconButton(
          icon: Icon(Icons.close, color: appBarIconColor),
          tooltip: 'Hủy thư',
          onPressed: _discardEmail,
        ),
        title: Text(
           widget.composeMode == 'reply' ? 'Trả lời' :
           widget.composeMode == 'replyAll' ? 'Trả lời tất cả' :
           widget.composeMode == 'forward' ? 'Chuyển tiếp' :
           'Soạn thư',
        style: TextStyle(color: appBarTextColor, fontSize: 18, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
              icon: Icon(Icons.attach_file_outlined,
                  color: appBarIconColor),
              tooltip: 'Đính kèm tệp',
              onPressed: _pickAttachments),
          IconButton(
              icon: Icon(Icons.send_outlined,
                  color: sendIconColor),
              tooltip: 'Gửi',
              onPressed: _isSending ? null : _sendEmailAndSaveToFirestore), 
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: popupMenuIconColor),
            color: popupMenuBackgroundColor, // Theme for popup menu background
            onSelected: (value) {
              if (value == 'save_draft') {
                _saveDraft();
              } else if (value == 'discard_popup') {
                _discardEmail();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'save_draft',
                child: Text('Lưu bản nháp', style: TextStyle(color: popupMenuTextColor)),
              ),
              PopupMenuItem<String>(
                value: 'discard_popup',
                child: Text('Hủy bỏ', style: TextStyle(color: popupMenuTextColor)),
              ),
              const PopupMenuDivider(), // Removed color property
              PopupMenuItem<String>(
                value: 'schedule_send',
                child: Text('Lên lịch gửi', style: TextStyle(color: popupMenuTextColor)),
              ),
              PopupMenuItem<String>(
                value: 'confidential_mode',
                child: Text('Chế độ bảo mật', style: TextStyle(color: popupMenuTextColor)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSending) LinearProgressIndicator(color: linearProgressIndicatorColor, backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300]),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(0),
              children: [
                _buildRecipientField(
                  context: context, // Pass context
                  label: "Đến",
                  controller: _toController,
                  focusNode: _toFocusNode,
                  onToggleCcBcc: () {
                    setState(() {
                      _showCcBcc = !_showCcBcc;
                    });
                  },
                ),
                if (_showCcBcc) ...[
                  Divider(height: 0, indent: 16, endIndent: 16, color: dividerColor),
                  _buildRecipientField(context: context, label: "Cc", controller: _ccController), // Pass context
                  Divider(height: 0, indent: 16, endIndent: 16, color: dividerColor),
                  _buildRecipientField(context: context, label: "Bcc", controller: _bccController), // Pass context
                ],
                Divider(height: 0, indent: 16, endIndent: 16, color: dividerColor),
                _buildFromField(context: context, controller: _fromController), // Pass context
                Divider(height: 0, indent: 16, endIndent: 16, color: dividerColor),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _subjectController,
                    cursorColor: cursorColor,
                    style: TextStyle(color: textFieldTextColor, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: "Chủ đề",
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none, // Ensure no border when enabled
                      focusedBorder: InputBorder.none, // Ensure no border when focused
                      disabledBorder: InputBorder.none, // Ensure no border when disabled
                      errorBorder: InputBorder.none, // Ensure no border on error
                      focusedErrorBorder: InputBorder.none, // Ensure no border on focused error
                      hintStyle: TextStyle(color: textFieldHintColor),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                  ),
                ),
                Divider(height: 0, color: dividerColor),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _bodyController,
                    cursorColor: cursorColor,
                    style: TextStyle(color: textFieldTextColor, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: "Soạn email",
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none, // Ensure no border when enabled
                      focusedBorder: InputBorder.none, // Ensure no border when focused
                      disabledBorder: InputBorder.none, // Ensure no border when disabled
                      errorBorder: InputBorder.none, // Ensure no border on error
                      focusedErrorBorder: InputBorder.none, // Ensure no border on focused error
                      hintStyle: TextStyle(color: textFieldHintColor),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    autofocus: widget.replyOrForwardEmail == null, 
                  ),
                ),                if (_attachments.isNotEmpty) ...[
                  Divider(height: 1, color: dividerColor),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
                    child: Text("Tệp đính kèm (${_attachments.length}):", style: TextStyle(fontWeight: FontWeight.w500, color: attachmentHeaderColor)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _attachments.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final File file = entry.value;
                        String fileName = kIsWeb ? file.path : file.path.split('/').last.split('\\').last;
                        
                        return Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4),
                          child: Chip(
                            backgroundColor: attachmentChipBackgroundColor,
                            avatar: Icon(_getFileIcon(fileName), size: 18, color: attachmentChipLabelColor),
                            label: Text(
                              fileName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: attachmentChipLabelColor, fontSize: 12),
                            ),
                            onDeleted: () {
                              setState(() {
                                String fileKey = kIsWeb ? file.path : file.path.split('/').last.split('\\').last;
                                _webAttachmentData.remove(fileKey);
                                _attachments.removeAt(index);
                              });
                            },
                            deleteIconColor: attachmentChipDeleteIconColor,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
      {required BuildContext context, // Add context
      required String label,
      required TextEditingController controller,
      FocusNode? focusNode,
      VoidCallback? onToggleCcBcc}) {
    final theme = Theme.of(context); // Get theme
    final isDarkMode = theme.brightness == Brightness.dark;
    final textFieldTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final cursorColor = isDarkMode ? Colors.blue[300]! : Colors.black;
    final iconColor = isDarkMode ? Colors.grey[400] : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            child: Text(label,
                style: TextStyle(fontSize: 16, color: cursorColor)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorColor: cursorColor,
              style: TextStyle(color: textFieldTextColor, fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none, // Ensure no border when enabled
                focusedBorder: InputBorder.none, // Ensure no border when focused
                disabledBorder: InputBorder.none, // Ensure no border when disabled
                errorBorder: InputBorder.none, // Ensure no border on error
                focusedErrorBorder: InputBorder.none, // Ensure no border on focused error
                contentPadding: EdgeInsets.symmetric(vertical: 16.0),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          if (label == "Đến")
            IconButton(
              icon: Icon(
                  _showCcBcc ? Icons.expand_less : Icons.expand_more,
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

  Widget _buildFromField({required BuildContext context, required TextEditingController controller}) { // Add context
    final theme = Theme.of(context); // Get theme
    final isDarkMode = theme.brightness == Brightness.dark;
    final textFieldTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final cursorColor = isDarkMode ? Colors.blue[300]! : Colors.black;
    final iconColor = isDarkMode ? Colors.grey[400] : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            child: Text("Từ",
                style: TextStyle(fontSize: 16, color: cursorColor)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: true,
              cursorColor: cursorColor, // Though readonly, good to have for consistency
              style: TextStyle(color: textFieldTextColor, fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none, // Ensure no border when enabled
                focusedBorder: InputBorder.none, // Ensure no border when focused
                disabledBorder: InputBorder.none, // Ensure no border when disabled
                errorBorder: InputBorder.none, // Ensure no border on error
                focusedErrorBorder: InputBorder.none, // Ensure no border on focused error
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