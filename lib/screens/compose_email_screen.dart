// lib/screens/compose_email_screen.dart
import 'dart:io'; // For File
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
    String originalSender = email['sender'] ?? '';
    String originalSubject = email['subject'] ?? '';
    String originalBody = email['bodyContent'] ?? email['preview'] ?? '';

    String quotedBody =
        "\n\n\n-------- ${widget.composeMode == 'forward' ? 'Forwarded Message' : 'Original Message'} --------\n"
        "From: $originalSender\n"
        "Date: ${email['time'] ?? 'Unknown date'}\n"
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
      // TODO: Thêm logic để lấy danh sách CC gốc và điền vào _ccController
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
      // TODO: Xử lý việc đính kèm lại các file từ email gốc nếu cần (phức tạp hơn)
      // List<String> originalAttachmentUrls = List<String>.from(email['attachments'] ?? []);
      // // Bạn cần logic để tải các file này về rồi thêm vào _attachments,
      // // hoặc chỉ hiển thị link nếu là forward.
    }
    _bodyController.selection =
        TextSelection.fromPosition(const TextPosition(offset: 0));
  }

  Future<void> _pickAttachments() async {
    if (!mounted) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachments.addAll(result.paths.map((path) => File(path!)).toList());
        });
      } else {
        // User canceled the picker or no files selected
        if (mounted) { // MODIFIED
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No files selected.')),
          );
        }
      }
    } catch (e) {
      if (mounted) { // MODIFIED
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    }
  }

  Future<void> _sendEmailAndSaveToFirestore() async {
    if (!mounted) return;

    if (_toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one recipient.')), // MODIFIED
      );
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      final sendAnyway = await showDialog<bool>(
        context: context, // MODIFIED
        builder: (dialogContext) => AlertDialog( // MODIFIED
          title: const Text('Send without subject?'),
          content: const Text('The subject is empty. Send the email anyway?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('SEND'),
            ),
          ],
        ),
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
            const SnackBar(content: Text('User not logged in. Cannot send email.')),
          );
          // No need to set _isSending to false here, finally block will handle it.
        }
        // Ensure finally block still runs to set _isSending = false
        // by not returning from inside the try if possible, or rethrow to be caught by outer catch.
        // However, for this specific case, returning is fine as `finally` will execute.
        // The `setState` for `_isSending` should be in `finally` or after this check.
        // Let's adjust: move `setState` for `_isSending` to be conditional or in finally.
        // For now, this return is fine, `finally` will execute.
        return; 
      }

      List<String> attachmentUrls = [];
      if (_attachments.isNotEmpty) {
        for (File file in _attachments) {
          String fileName = file.path.split('/').last; // Declare fileName here
          try {
            Reference ref = FirebaseStorage.instance
                .ref()
                .child('email_attachments')
                .child(docRef.id) 
                .child(fileName);
            UploadTask uploadTask = ref.putFile(file);
            TaskSnapshot snapshot = await uploadTask;
            String downloadUrl = await snapshot.ref.getDownloadURL();
            attachmentUrls.add(downloadUrl);
          } catch (e) {
            print('Error uploading attachment ${file.path}: $e');
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to upload attachment: $fileName. Email will be sent without it.')),
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
      emailIsReadBy[currentSenderId] = true; // Sent mail is initially marked as read for the sender.

      // 2. Handle Recipients (including sender if they are a recipient)
      Set<String> allUniqueRecipientEmails = {...toRecipients, ...ccRecipients, ...bccRecipients}.toSet();

      for (String recipientEmail in allUniqueRecipientEmails) {
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

            // Add 'Inbox' label for this recipient
            List<String> currentLabels = emailLabels[recipientId] ?? [];
            if (!currentLabels.contains('Inbox')) {
              currentLabels.add('Inbox');
            }
            emailLabels[recipientId] = currentLabels.toSet().toList(); // Ensure unique labels

            // Emails appearing in an 'Inbox' should be marked as unread for that recipient.
            // This will override the sender's 'isRead = true' if they send to themselves.
            emailIsReadBy[recipientId] = false;
          } else {
            print('Recipient email $recipientEmail not found in users collection.');
            // Note: Emails to external users won't have an 'Inbox' label for them in this system
            // and their recipientId won't be added to involvedUserIds unless they are also users of this app.
            // The email will still contain their email address in toRecipients/ccRecipients/bccRecipients.
          }
        } catch (e) {
          print('Error fetching recipient UID for $recipientEmail or processing labels: $e');
          // Consider if this error should halt sending or just skip this recipient's special handling.
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
          const SnackBar(content: Text('Email sent successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
       if(mounted) { // MODIFIED
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send email: $e')),
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
          const SnackBar(content: Text('Draft saved.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if(mounted) { // MODIFIED
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save draft: $e')),
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
            return AlertDialog(
              title: const Text('Discard email?'),
              content: const Text('Are you sure you want to discard this email and lose your changes?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('CANCEL'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  child: const Text('DISCARD'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          tooltip: 'Hủy thư',
          onPressed: _discardEmail,
        ),
        title: Text(
           widget.composeMode == 'reply' ? 'Trả lời' :
           widget.composeMode == 'replyAll' ? 'Trả lời tất cả' :
           widget.composeMode == 'forward' ? 'Chuyển tiếp' :
           'Soạn thư',
        style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
              icon: const Icon(Icons.attach_file_outlined,
                  color: Colors.black54),
              tooltip: 'Đính kèm tệp',
              onPressed: _pickAttachments),
          IconButton(
              icon: Icon(Icons.send_outlined,
                  color: _isSending ? Colors.grey : Colors.blueAccent),
              tooltip: 'Gửi',
              onPressed: _isSending ? null : _sendEmailAndSaveToFirestore), // SỬA Ở ĐÂY
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            onSelected: (value) {
              if (value == 'save_draft') {
                _saveDraft();
              } else if (value == 'discard_popup') {
                _discardEmail();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'save_draft',
                child: Text('Lưu bản nháp'),
              ),
              const PopupMenuItem<String>(
                value: 'discard_popup',
                child: Text('Hủy bỏ'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'schedule_send',
                child: Text('Lên lịch gửi'),
              ),
              const PopupMenuItem<String>(
                value: 'confidential_mode',
                child: Text('Chế độ bảo mật'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSending) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(0),
              children: [
                _buildRecipientField(
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
                  const Divider(height: 0, indent: 16, endIndent: 16, color: Color(0xFFE0E0E0)),
                  _buildRecipientField(label: "Cc", controller: _ccController),
                  const Divider(height: 0, indent: 16, endIndent: 16, color: Color(0xFFE0E0E0)),
                  _buildRecipientField(label: "Bcc", controller: _bccController),
                ],
                const Divider(height: 0, indent: 16, endIndent: 16, color: Color(0xFFE0E0E0)),
                _buildFromField(controller: _fromController),
                const Divider(height: 0, indent: 16, endIndent: 16, color: Color(0xFFE0E0E0)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _subjectController,
                    cursorColor: Colors.black,
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: "Chủ đề",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.black54),
                      contentPadding: EdgeInsets.symmetric(vertical: 16.0),
                    ),
                  ),
                ),
                const Divider(height: 0, color: Color(0xFFE0E0E0)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _bodyController,
                    cursorColor: Colors.black,
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: "Soạn email",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.black54),
                      contentPadding: EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    autofocus: widget.replyOrForwardEmail == null, // Đã sửa ở đây
                  ),
                ),
                if (_attachments.isNotEmpty) ...[
                  const Divider(height: 1, color: Color(0xFFE0E0E0)),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top:16.0, bottom: 8.0),
                    child: Text("Tệp đính kèm (${_attachments.length}):", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attachments.length,
                    itemBuilder: (context, index) {
                      final file = _attachments[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Chip(
                          avatar: const Icon(Icons.attach_file, size: 18),
                          label: Text(
                            file.path.split('/').last,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: () {
                            setState(() {
                              _attachments.removeAt(index);
                            });
                          },
                          deleteIconColor: Colors.red[700],
                        ),
                      );
                    },
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
      {required String label,
      required TextEditingController controller,
      FocusNode? focusNode,
      VoidCallback? onToggleCcBcc}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            child: Text(label,
                style: TextStyle(fontSize: 16, color: Colors.grey[800])),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorColor: Colors.black,
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16.0),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          if (label == "Đến")
            IconButton(
              icon: Icon(
                  _showCcBcc ? Icons.expand_less : Icons.expand_more,
                  color: Colors.black54),
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

  Widget _buildFromField({required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            child: Text("Từ",
                style: TextStyle(fontSize: 16, color: Colors.grey[800])),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: true,
              cursorColor: Colors.black,
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16.0),
              ),
            ),
          ),
           IconButton(
            icon: const Icon(Icons.expand_more, color: Colors.black54),
            tooltip: 'Đổi tài khoản gửi',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chọn tài khoản gửi...")));
            },
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          )
        ],
      ),
    );
  }
}