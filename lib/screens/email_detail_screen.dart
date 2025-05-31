// lib/screens/email_detail_screen.dart
import 'package:flutter/material.dart';
import '../widgets/action_button.dart'; // Đảm bảo widget này tồn tại và đúng đường dẫn
import 'compose_email_screen.dart'; // Để điều hướng khi Reply/Forward

class EmailDetailScreen extends StatefulWidget {
  final Map<String, dynamic> email;
  const EmailDetailScreen({super.key, required this.email});

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  bool _showMetaDetails = false; // Đổi tên từ showDetails để rõ ràng hơn
  late bool _isStarredLocally;
  late bool _isReadLocally; // Quản lý trạng thái đọc/chưa đọc cục bộ

  @override
  void initState() {
    super.initState();
    // Khởi tạo trạng thái cục bộ từ dữ liệu email truyền vào
    _isStarredLocally = widget.email['starred'] ?? false;
    _isReadLocally = widget.email['read'] ?? true; // Mặc định là đã đọc khi mở chi tiết

    // Nếu email được đánh dấu là chưa đọc khi truyền vào,
    // thì ngay khi màn hình này được build xong, ta đánh dấu nó là đã đọc (chỉ cho UI)
    // và có thể gửi sự kiện ngược lại nếu cần
    if (widget.email['read'] == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Kiểm tra widget còn trong tree không
          setState(() {
            widget.email['read'] = true; // Cập nhật trạng thái trong map gốc
            _isReadLocally = true;
          });
          // TODO: Gửi sự kiện cập nhật trạng thái 'read' lên Firestore/backend nếu cần
          // Ví dụ: Provider.of<EmailProvider>(context, listen: false).markAsRead(widget.email['id']);
        }
      });
    }
  }

  void _toggleStarStatus() {
    setState(() {
      _isStarredLocally = !_isStarredLocally;
      widget.email['starred'] = _isStarredLocally; // Cập nhật map gốc cho UI
    });
    // TODO: Cập nhật trạng thái star lên Firestore/backend
    // Ví dụ: FirebaseFirestore.instance.collection('emails').doc(widget.email['id']).update({'starred': _isStarredLocally});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isStarredLocally ? 'Đã gắn dấu sao' : 'Đã bỏ dấu sao')),
    );
  }

  void _toggleReadStatus() {
    setState(() {
      _isReadLocally = !_isReadLocally;
      widget.email['read'] = _isReadLocally; // Cập nhật map gốc cho UI
    });
    // TODO: Cập nhật trạng thái read/unread lên Firestore/backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isReadLocally ? 'Đã đánh dấu là đã đọc' : 'Đã đánh dấu là chưa đọc')),
    );
    // Nếu đánh dấu là chưa đọc, có thể pop màn hình để quay lại danh sách
    if (!_isReadLocally) {
      Navigator.pop(context, {'markedAsUnread': true, 'emailId': widget.email['id']});
    }
  }

  void _deleteEmail() {
    // TODO:
    // 1. Di chuyển email này vào "Trash" trong Firestore/backend (thay đổi label hoặc cờ isTrashed)
    // 2. Hoặc xóa hẳn nếu logic nghiệp vụ cho phép
    print("Email '${widget.email['subject']}' moved to trash (simulated)");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã chuyển vào Thùng rác (Mô phỏng)')),
    );
    Navigator.pop(context, {'deleted': true, 'emailId': widget.email['id']}); // Trả về để màn hình danh sách cập nhật
  }

  void _assignLabels() {
    // TODO: Hiển thị một dialog hoặc màn hình mới cho phép người dùng:
    // 1. Chọn từ các nhãn hiện có (userLabels từ GmailUI)
    // 2. Tạo nhãn mới
    // 3. Cập nhật trường 'label' của widget.email và lưu lên Firestore/backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chức năng gán nhãn (chưa triển khai)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email; // Để code ngắn gọn hơn

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black54),
        actions: [
          IconButton( // Nút Lưu trữ (Archive) - ví dụ
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Lưu trữ',
            onPressed: () {
              // TODO: Implement archive logic
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
            // Thay đổi icon dựa trên _isReadLocally
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
              const PopupMenuItem<String>(
                value: 'snooze', // Tạm ẩn
                child: Text('Tạm ẩn'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'print',
                child: Text('In'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView( // Sử dụng ListView để nội dung dài có thể cuộn
          children: [
            // Tiêu đề email và nút Star
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    email["subject"] ?? '(Không có chủ đề)',
                    style: const TextStyle(
                        fontWeight: FontWeight.normal, // Gmail thường không in đậm tiêu đề ở đây
                        fontSize: 22, // Kích thước lớn hơn cho tiêu đề
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
            const SizedBox(height: 20), // Tăng khoảng cách

            // Thông tin người gửi và thời gian
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[200], // Màu nền nhạt hơn
                  backgroundImage: email["avatar"] != null
                      ? AssetImage(email["avatar"])
                      : null,
                  child: email["avatar"] == null
                      ? Text(
                          (email["sender"] ?? "?")[0].toUpperCase(),
                          style: TextStyle(
                              color: Theme.of(context).primaryColorDark, // Màu chữ tương phản
                              fontWeight: FontWeight.w500,
                              fontSize: 18),
                        )
                      : null,
                  radius: 22, // Giảm nhẹ bán kính avatar
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            email["sender"] ?? 'Không rõ người gửi',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, // Đậm hơn chút
                                fontSize: 16,
                                color: Colors.black87),
                          ),
                          const Spacer(), // Đẩy thời gian sang phải
                          Text(
                            email["time"] ?? '',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2), // Giảm khoảng cách
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showMetaDetails = !_showMetaDetails;
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "tới tôi", // Hoặc "tới: bạn, người khác"
                              style: TextStyle(
                                color: Colors.black54, // Nhạt hơn
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showMetaDetails
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down, // Icon phù hợp hơn
                              size: 22,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Nút Reply (nhỏ) ở góc - tùy chọn, vì đã có ở bottom bar
                // IconButton(
                //   icon: const Icon(Icons.reply_outlined, color: Colors.black54),
                //   tooltip: 'Reply',
                //   onPressed: () {
                //     Navigator.push(context, MaterialPageRoute(builder: (context) => ComposeEmailScreen(replyOrForwardEmail: email, composeMode: 'reply')));
                //   },
                // ),
              ],
            ),

            // View metadata
            if (_showMetaDetails) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16), // Tăng padding
                decoration: BoxDecoration(
                  // color: Colors.grey[50], // Màu nền rất nhạt
                  borderRadius: BorderRadius.circular(8), // Bo tròn ít hơn
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetaDetailRow("From", email["sender"] ?? ""),
                    _buildMetaDetailRow("To", "you@example.com"), // Thay bằng email người nhận thật
                    // if (email["cc"] != null && (email["cc"] as List).isNotEmpty)
                    //   _buildMetaDetailRow("Cc", (email["cc"] as List).join(", ")),
                    // if (email["bcc"] != null && (email["bcc"] as List).isNotEmpty)
                    //   _buildMetaDetailRow("Bcc", "(Bcc recipients)"), // Thường không hiển thị BCC
                    _buildMetaDetailRow("Date", email["time"] ?? ""), // Hoặc format lại ngày giờ đầy đủ
                  ],
                ),
              ),
            ],
            const Divider(height: 32, thickness: 0.5), // Divider mỏng hơn

            // Nội dung email
            SelectableText( // Cho phép chọn và sao chép nội dung
              email["preview"] ?? "(Không có nội dung)", // Nên là nội dung đầy đủ
              style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6), // Tăng line height
            ),

            // Tệp đính kèm
            if (email["hasAttachment"] == true)
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tệp đính kèm", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    // TODO: Hiển thị danh sách các tệp đính kèm thực tế
                    // Ví dụ:
                    Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300)
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.blueAccent),
                        title: const Text("Attachment_name.pdf", style: TextStyle(color: Colors.black87)),
                        subtitle: const Text("1.2 MB - PDF"),
                        trailing: IconButton(icon: Icon(Icons.download_outlined, color: Colors.grey[700]), onPressed: (){
                           // TODO: Implement download
                        }),
                        onTap: () {
                          // TODO: Implement open/preview attachment
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 80), // Khoảng trống cho BottomNavigationBar
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
              child: ActionButton( // Sử dụng ActionButton bạn đã định nghĩa
                icon: Icons.reply_outlined, // Icon outline
                label: "Trả lời",
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ComposeEmailScreen(
                              replyOrForwardEmail: email, composeMode: 'reply')));
                },
                // backgroundColor: Colors.white, // ActionButton của bạn có thể không cần cái này
              ),
            ),
            const SizedBox(width: 10),
             Expanded( // Nút Trả lời tất cả
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

  Widget _buildMetaDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50, // Độ rộng cố định cho label
            child: Text(
              "$label:",
              style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}