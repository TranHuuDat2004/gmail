// lib/screens/email_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';       // Để lấy UID người dùng hiện tại
import 'package:cloud_firestore/cloud_firestore.dart'; // Để cập nhật Firestore

import '../widgets/action_button.dart'; // Đảm bảo widget này tồn tại và đúng đường dẫn
import 'compose_email_screen.dart';   // Để điều hướng khi Reply/Forward

class EmailDetailScreen extends StatefulWidget {
  final Map<String, dynamic> email; // email này nên có trường 'id' của document
  const EmailDetailScreen({super.key, required this.email});

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  bool _showMetaDetails = false;
  late bool _isStarredLocally;
  late bool _isReadLocally;
  User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _isStarredLocally = widget.email['starredBy']?.contains(_currentUser?.uid) ?? false; // Kiểm tra từ mảng starredBy
    _isReadLocally = widget.email['isReadBy']?[_currentUser?.uid] ?? true; // Mặc định là đã đọc khi mở

    // Tự động đánh dấu là đã đọc trên Firestore khi màn hình được build xong
    // (chỉ khi nó chưa được đọc bởi người dùng này)
    if (!_isReadLocally && _currentUser != null && widget.email['id'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FirebaseFirestore.instance
              .collection('emails')
              .doc(widget.email['id'])
              .update({'isReadBy.${_currentUser!.uid}': true})
              .then((_) => print("Email marked as read in Firestore."))
              .catchError((error) => print("Failed to mark email as read: $error"));
          setState(() { // Cập nhật UI cục bộ ngay lập tức
            _isReadLocally = true;
          });
        }
      });
    }
  }

  Future<void> _toggleStarStatus() async {
    if (_currentUser == null || widget.email['id'] == null) return;
    final newStarStatus = !_isStarredLocally;

    try {
      FieldValue updateValue = newStarStatus
          ? FieldValue.arrayUnion([_currentUser!.uid])
          : FieldValue.arrayRemove([_currentUser!.uid]);

      await FirebaseFirestore.instance
          .collection('emails')
          .doc(widget.email['id'])
          .update({'starredBy': updateValue});

      if (mounted) {
        setState(() {
          _isStarredLocally = newStarStatus;
          widget.email['starred'] = newStarStatus; // Cập nhật map widget để UI phản ánh
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStarStatus ? 'Đã gắn dấu sao' : 'Đã bỏ dấu sao')),
        );
      }
    } catch (e) {
      print("Error updating star status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật dấu sao: $e')),
        );
      }
    }
  }

  Future<void> _toggleReadStatus() async {
    if (_currentUser == null || widget.email['id'] == null) return;
    final newReadStatus = !_isReadLocally; // Nếu đang là đã đọc -> muốn đánh dấu chưa đọc

    try {
      await FirebaseFirestore.instance
          .collection('emails')
          .doc(widget.email['id'])
          .update({'isReadBy.${_currentUser!.uid}': newReadStatus}); // Cập nhật trạng thái đọc của người dùng này

      if (mounted) {
        setState(() {
          _isReadLocally = newReadStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newReadStatus ? 'Đã đánh dấu là đã đọc' : 'Đã đánh dấu là chưa đọc')),
        );
        // Nếu đánh dấu là chưa đọc, pop và trả về kết quả để GmailUI có thể làm đậm lại
        if (!newReadStatus) {
          Navigator.pop(context, {'markedAsUnread': true, 'emailId': widget.email['id']});
        }
      }
    } catch (e) {
      print("Error updating read status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật trạng thái đọc: $e')),
        );
      }
    }
  }

  Future<void> _deleteEmail() async {
    if (_currentUser == null || widget.email['id'] == null) return;
    try {
      // Thêm UID của người dùng vào mảng isTrashedBy
      await FirebaseFirestore.instance
          .collection('emails')
          .doc(widget.email['id'])
          .update({'isTrashedBy': FieldValue.arrayUnion([_currentUser!.uid])});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chuyển vào Thùng rác')),
        );
        Navigator.pop(context, {'deleted': true, 'emailId': widget.email['id']});
      }
    } catch (e) {
      print("Error moving email to trash: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chuyển vào thùng rác: $e')),
        );
      }
    }
  }

  void _assignLabels() {
    if (_currentUser == null || widget.email['id'] == null) return;
    // TODO: Hiển thị một dialog hoặc màn hình mới cho phép người dùng:
    // 1. Chọn từ các nhãn hiện có (userLabels có thể lấy từ Firestore/user_profile)
    // 2. Tạo nhãn mới
    // 3. Cập nhật trường 'labels.<_currentUser.uid>' của widget.email trên Firestore
    // Ví dụ: await FirebaseFirestore.instance.collection('emails').doc(widget.email['id']).update({'labels.${_currentUser!.uid}': FieldValue.arrayUnion(['NewLabel'])});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chức năng gán nhãn (chưa triển khai)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    String senderDisplayName = email["senderEmail"] ?? email["sender"] ?? 'Không rõ';
    // Cố gắng lấy phần tên từ email (trước dấu @) nếu chỉ có email
    if (senderDisplayName.contains('@') && (email["sender"] == null || email["sender"] == email["senderEmail"])) {
        senderDisplayName = senderDisplayName.split('@')[0];
    }


    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black54),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Lưu trữ',
            onPressed: () {
              // TODO: Implement archive (thêm label 'Archived', xóa khỏi 'Inbox')
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu trữ (Mô phỏng)')));
              Navigator.pop(context, {'archived': true, 'emailId': email['id']});
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Chuyển vào Thùng rác',
            onPressed: _deleteEmail,
          ),
          IconButton(
            icon: Icon(_isReadLocally ? Icons.mark_email_unread_outlined : Icons.mark_as_unread_outlined),
            tooltip: _isReadLocally ? 'Đánh dấu là chưa đọc' : 'Đánh dấu là đã đọc',
            onPressed: _toggleReadStatus,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            onSelected: (value) {
              if (value == 'assign_labels') {
                _assignLabels();
              } else if (value == 'move_to') {
                // TODO: Implement move to folder/label
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Di chuyển đến... (chưa triển khai)')));
              }
              // Thêm các hành động khác
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'move_to',
                child: Text('Di chuyển đến'),
              ),
              // const PopupMenuItem<String>(
              //   value: 'snooze',
              //   child: Text('Tạm ẩn'),
              // ),
              const PopupMenuDivider(),
              PopupMenuItem<String>( // Thêm Star/Unstar vào menu này cũng là một lựa chọn
                value: 'toggle_star', // Không trùng với value nào khác
                onTap: _toggleStarStatus, // Gọi trực tiếp hàm khi nhấn
                child: Row(
                  children: [
                    Icon(_isStarredLocally ? Icons.star : Icons.star_border, color: _isStarredLocally ? Colors.amber.shade700 : Colors.grey),
                    const SizedBox(width: 8),
                    Text(_isStarredLocally ? 'Bỏ gắn dấu sao' : 'Gắn dấu sao'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'assign_labels',
                child: Text('Thay đổi nhãn'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    email["subject"] ?? '(Không có chủ đề)',
                    style: const TextStyle(
                        fontSize: 22,
                        color: Color(0xFF1f1f1f)),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isStarredLocally ? Icons.star : Icons.star_border,
                    color: _isStarredLocally ? Colors.amber.shade700 : Colors.grey,
                    size: 24,
                  ),
                  tooltip: _isStarredLocally ? 'Bỏ gắn dấu sao' : 'Gắn dấu sao',
                  onPressed: _toggleStarStatus,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage: email["avatar"] != null && (email["avatar"] as String).isNotEmpty
                      ? AssetImage(email["avatar"])
                      : null,
                  child: (email["avatar"] == null || (email["avatar"] as String).isEmpty)
                      ? Text(
                          senderDisplayName.isNotEmpty ? senderDisplayName[0].toUpperCase() : "?",
                          style: TextStyle(
                              color: Theme.of(context).primaryColorDark,
                              fontWeight: FontWeight.w500,
                              fontSize: 18),
                        )
                      : null,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                           Text(
                            senderDisplayName, // Sử dụng senderDisplayName
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black87),
                          ),
                          const Spacer(),
                          Text(
                            email["time"] ?? (email["timestamp"] as Timestamp?)?.toDate().toString().substring(0,16) ?? '', // Hiển thị timestamp nếu có
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showMetaDetails = !_showMetaDetails;
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "tới tôi ${email['ccRecipients'] != null && (email['ccRecipients'] as List).isNotEmpty ? 'và CC' : ''}",
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showMetaDetails
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              size: 22,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_showMetaDetails) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetaDetailRow("From", email["senderEmail"] ?? email["sender"] ?? ""),
                    _buildMetaDetailRow("To", (email["recipients"] as List<dynamic>?)?.join(", ") ?? "you@example.com"),
                    if (email["ccRecipients"] != null && (email["ccRecipients"] as List).isNotEmpty)
                      _buildMetaDetailRow("Cc", (email["ccRecipients"] as List<dynamic>).join(", ")),
                    // Không hiển thị BCC cho người nhận thông thường
                    _buildMetaDetailRow("Date", (email["timestamp"] as Timestamp?)?.toDate().toLocal().toString().substring(0,19) ?? email["time"] ?? ""),
                  ],
                ),
              ),
            ],
            const Divider(height: 32, thickness: 0.5),
            SelectableText(
              email["bodyContent"] ?? email["preview"] ?? "(Không có nội dung)",
              style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
            ),
            if (email["attachments"] != null && (email["attachments"] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tệp đính kèm (${(email["attachments"] as List).length})", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: (email["attachments"] as List).length,
                      itemBuilder: (context, index) {
                        final attachmentUrl = (email["attachments"] as List)[index] as String;
                        // Lấy tên file từ URL (cách đơn giản, có thể cần cải thiện)
                        String fileName = attachmentUrl.split('/').last.split('?').first;
                        try {
                          fileName = Uri.decodeComponent(fileName.split('%2F').last);
                        } catch (_) {}

                        return Card(
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300)
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.blueAccent),
                            title: Text(fileName, style: TextStyle(color: Colors.black87, fontSize: 14)),
                            // subtitle: Text("1.2 MB - PDF"), // TODO: Lấy kích thước và loại file từ metadata Storage
                            trailing: IconButton(icon: Icon(Icons.download_outlined, color: Colors.grey[700]), onPressed: (){
                               // TODO: Implement download attachment (có thể dùng url_launcher)
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đang tải $fileName... (Mô phỏng)")));
                            }),
                            onTap: () {
                              // TODO: Implement open/preview attachment
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Mở $fileName... (Mô phỏng)")));
                            },
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 0.5))),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ActionButton(
                icon: Icons.reply_outlined,
                label: "Trả lời",
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ComposeEmailScreen(
                              replyOrForwardEmail: email, composeMode: 'reply')));
                },
              ),
            ),
            const SizedBox(width: 10),
             Expanded(
              child: ActionButton(
                icon: Icons.reply_all_outlined,
                label: "Trả lời tất cả",
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => ComposeEmailScreen(replyOrForwardEmail: email, composeMode: 'replyAll')));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ActionButton(
                icon: Icons.forward_outlined,
                label: "Chuyển tiếp",
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ComposeEmailScreen(
                              replyOrForwardEmail: email, composeMode: 'forward')));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (Phần còn lại của class _EmailDetailScreenState ở trên) ...

  Widget _buildMetaDetailRow(String label, String value) {
    if (value.isEmpty) { // Nếu giá trị rỗng thì không hiển thị dòng đó
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0), // Khoảng cách giữa các dòng metadata
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Căn chỉnh văn bản từ đầu nếu value dài
        children: [
          SizedBox(
            width: 60, // Độ rộng cố định cho label (ví dụ: From, To, Date)
            child: Text(
              "$label:",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700], // Màu chữ cho label
                fontWeight: FontWeight.w500, // Hơi đậm một chút
              ),
            ),
          ),
          const SizedBox(width: 8), // Khoảng cách giữa label và value
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87, // Màu chữ cho value
              ),
            ),
          ),
        ],
      ),
    );
  }
} // Đóng class _EmailDetailScreenState
