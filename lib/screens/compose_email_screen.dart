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
    super.initState(); // Gọi super.initState() ở dòng đầu tiên
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    _fromController.text = currentUserEmail ?? "anonymous@example.com";

    if (widget.replyOrForwardEmail != null) {
      _populateFieldsForReplyForward();
    } else {
       WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
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
      // Sử dụng file_picker để chọn đa dạng file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachments.addAll(result.paths.map((path) => File(path!)).toList());
        });
      } else {
         // Người dùng có thể đã hủy chọn file, không cần thông báo lỗi
        print('No files selected or file_picker was cancelled.');
        // Hoặc nếu bạn muốn dùng image_picker cho ảnh:
        // final List<XFile> pickedImages = await _imagePicker.pickMultiImage(imageQuality: 70);
        // if (pickedImages.isNotEmpty) {
        //   setState(() {
        //     _attachments.addAll(pickedImages.map((xfile) => File(xfile.path)).toList());
        //   });
        // }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn tệp đính kèm: $e')),
        );
      }
    }
  }

  Future<void> _sendEmailAndSaveToFirestore() async {
    if (!mounted) return;

    if (_toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ người nhận (To).')),
      );
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      final sendAnyway = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gửi không có tiêu đề?'),
          content: const Text('Gửi thư này mà không có tiêu đề?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('HỦY')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('GỬI')),
          ],
        ),
      );
      if (sendAnyway != true) return;
    }

    setState(() { _isSending = true; });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      final userEmail = FirebaseAuth.instance.currentUser?.email ?? _fromController.text;

      if (userId == null) {
        throw Exception("Người dùng chưa đăng nhập.");
      }

      List<String> attachmentUrls = [];
      // Tải file đính kèm lên Firebase Storage
      for (File file in _attachments) {
        String fileName = 'attachments_v2/$userId/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        attachmentUrls.add(downloadUrl);
      }

      List<String> toRecipients = _toController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      List<String> ccRecipients = _ccController.text.isNotEmpty ? _ccController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : [];
      List<String> bccRecipients = _bccController.text.isNotEmpty ? _bccController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : [];
      Set<String> involvedUsers = {userEmail, ...toRecipients, ...ccRecipients, ...bccRecipients};

      final emailData = {
        'senderId': userId,
        'senderEmail': userEmail,
        'recipients': toRecipients,
        'ccRecipients': ccRecipients,
        'bccRecipients': bccRecipients,
        'involvedUsers': involvedUsers.toList(),
        'subject': _subjectController.text,
        'bodyContent': _bodyController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'attachments': attachmentUrls,
        'isReadBy': {userId: true},
        'labels': {userId: ['Sent']},
        'starredBy': [],
        'isTrashedBy': [],
      };

      DocumentReference docRef = await FirebaseFirestore.instance.collection('emails').add(emailData);
      print('Email saved to Firestore with ID: ${docRef.id}');

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thư đã được gửi và lưu!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu email: $e')),
        );
        print('Error sending email: $e'); // In lỗi ra console để debug
      }
    } finally {
      if(mounted) {
        setState(() { _isSending = false; });
      }
    }
  }

  Future<void> _saveDraft() async {
    if (!mounted) return;
    if (_bodyController.text.trim().isEmpty && _subjectController.text.trim().isEmpty && _toController.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("Người dùng chưa đăng nhập.");

      // Với nháp, bạn có thể chưa tải file đính kèm lên Storage.
      // Chỉ lưu đường dẫn file cục bộ. Khi gửi thật từ nháp, lúc đó mới tải lên.
      List<String> attachmentLocalPaths = _attachments.map((f) => f.path).toList();

      final draftData = {
        'senderId': userId, // Quan trọng để biết nháp này của ai
        'from': _fromController.text,
        'to': _toController.text,
        'cc': _ccController.text,
        'bcc': _bccController.text,
        'subject': _subjectController.text,
        'bodyContent': _bodyController.text, // Đổi tên cho nhất quán
        'timestamp': FieldValue.serverTimestamp(),
        'attachments_paths': attachmentLocalPaths,
        'isDraft': true,
      };

      // Lưu vào subcollection 'drafts' của người dùng
      await FirebaseFirestore.instance.collection('users').doc(userId).collection('drafts').add(draftData);

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu vào thư nháp')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu nháp: $e')),
        );
        print('Error saving draft: $e'); // In lỗi
      }
    }
  }

  void _discardEmail() {
     if (_bodyController.text.trim().isNotEmpty || _subjectController.text.trim().isNotEmpty || _toController.text.trim().isNotEmpty || _attachments.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hủy thư này?'),
            content: const Text('Tất cả thay đổi của bạn sẽ bị mất.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('TIẾP TỤC SOẠN'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('HỦY BỎ', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
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