// lib/screens/email_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';       // Để lấy UID người dùng hiện tại
import 'package:cloud_firestore/cloud_firestore.dart'; // Để cập nhật Firestore

// import '../widgets/action_button.dart'; // Keep if you plan to use ActionButton soon
// import 'compose_email_screen.dart';   // Keep if you plan to implement Reply/Forward soon

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
  // String _senderInitialForAvatar = ''; // Will be replaced by _senderInitialLetterForDetail

  // New state variables for fetched sender details
  String? _fetchedSenderDisplayNameForDetail;
  String? _fetchedSenderAvatarUrlForDetail;
  String _senderInitialLetterForDetail = '?'; 
  bool _isLoadingSenderDetailsForDetail = true;
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Already defined in _fetchSenderDetailsForDetailScreen

  @override
  void initState() {
    super.initState();

    _currentUser = FirebaseAuth.instance.currentUser; // Ensure _currentUser is initialized first

    if (_currentUser != null) {
      final emailLabelsMap = widget.email['emailLabels'] as Map<String, dynamic>?;
      final userSpecificLabels = emailLabelsMap?[_currentUser!.uid] as List<dynamic>?;
      _isStarredLocally = userSpecificLabels?.contains('Starred') ?? false;
      
      final emailIsReadByMap = widget.email['emailIsReadBy'] as Map<String, dynamic>?;
      _isReadLocally = emailIsReadByMap?[_currentUser!.uid] as bool? ?? false;
    } else {
      _isStarredLocally = false;
      _isReadLocally = false;
    }

    _fetchSenderDetailsForDetailScreen();

    if (!_isReadLocally && _currentUser != null && widget.email['id'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FirebaseFirestore.instance
              .collection('emails')
              .doc(widget.email['id'])
              .update({'emailIsReadBy.${_currentUser!.uid}': true})
              .then((_) {
                print("Email marked as read in Firestore for user ${_currentUser!.uid}.");
                if (mounted) {
                  setState(() { 
                    _isReadLocally = true;
                    // Update local email data to reflect the change
                    if (widget.email['emailIsReadBy'] is Map) {
                      (widget.email['emailIsReadBy'] as Map<String, dynamic>)[_currentUser!.uid] = true;
                    } else {
                       widget.email['emailIsReadBy'] = <String, dynamic>{_currentUser!.uid: true};
                    }
                  });
                }
              })
              .catchError((error) {
                print("Failed to mark email as read for user ${_currentUser!.uid}: $error");
                // Optionally show a message to the user
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Failed to mark email as read: $error')),
                // );
                return null; 
              });
        }
      });
    }
  }

  Future<void> _fetchSenderDetailsForDetailScreen() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSenderDetailsForDetail = true;
    });

    String? senderId = widget.email['senderId'] as String?;
    
    // Fallback display name and avatar from the email document itself (if available)
    // These might have been populated at send time for non-app users or as a quick cache
    String fallbackDisplayName = widget.email['senderDisplayName'] as String? ??
                                 widget.email['senderEmail'] as String? ??
                                 widget.email['from'] as String? ?? // 'from' might contain the email address
                                 'Không rõ';
    String fallbackInitial = fallbackDisplayName.isNotEmpty && fallbackDisplayName != 'Không rõ'
                             ? fallbackDisplayName[0].toUpperCase()
                             : '?';
    String? fallbackAvatarUrl = widget.email['senderAvatarUrl'] as String?;


    if (senderId != null && senderId.isNotEmpty) {
      try {
        DocumentSnapshot senderDoc = await FirebaseFirestore.instance.collection('users').doc(senderId).get();
        if (mounted && senderDoc.exists) {
          final data = senderDoc.data() as Map<String, dynamic>;
          _fetchedSenderDisplayNameForDetail = data['displayName'] as String? ?? data['name'] as String? ?? fallbackDisplayName;
          _fetchedSenderAvatarUrlForDetail = data['avatarUrl'] as String?;
          _senderInitialLetterForDetail = (_fetchedSenderDisplayNameForDetail != null && _fetchedSenderDisplayNameForDetail!.isNotEmpty)
                               ? _fetchedSenderDisplayNameForDetail![0].toUpperCase()
                               : fallbackInitial; // Use fallback initial if display name is empty after fetch
        } else {
          // Sender document not found in 'users' collection, use fallbacks from email
          _fetchedSenderDisplayNameForDetail = fallbackDisplayName;
          _fetchedSenderAvatarUrlForDetail = fallbackAvatarUrl;
          _senderInitialLetterForDetail = fallbackInitial;
        }
      } catch (e) {
        print('Error fetching sender details for EmailDetailScreen (email ID ${widget.email['id']}, senderId $senderId): $e');
        // On error, use fallbacks from email
        _fetchedSenderDisplayNameForDetail = fallbackDisplayName;
        _fetchedSenderAvatarUrlForDetail = fallbackAvatarUrl;
        _senderInitialLetterForDetail = fallbackInitial;
      }
    } else {
      // No senderId in the email document, use fallbacks from email
      // This case might occur for emails from external systems not fully integrated
      print('No senderId found in email document (email ID ${widget.email['id']}). Using fallback display info.');
      _fetchedSenderDisplayNameForDetail = fallbackDisplayName;
      _fetchedSenderAvatarUrlForDetail = fallbackAvatarUrl;
      _senderInitialLetterForDetail = fallbackInitial;
    }

    if (mounted) {
      setState(() {
        _isLoadingSenderDetailsForDetail = false;
      });
    }
  }

  Future<void> _toggleStarStatus() async {
    if (_currentUser == null || widget.email['id'] == null) return;
    final newStarStatus = !_isStarredLocally;
    final String userId = _currentUser!.uid;
    final String emailId = widget.email['id'];

    try {
      DocumentReference emailRef = FirebaseFirestore.instance.collection('emails').doc(emailId);
      
      // Get current labels for the user, or initialize if null
      Map<String, dynamic> emailLabelsMap = Map<String, dynamic>.from(widget.email['emailLabels'] ?? {});
      List<dynamic> currentUserLabels = List<dynamic>.from(emailLabelsMap[userId] ?? []);

      if (newStarStatus) {
        if (!currentUserLabels.contains('Starred')) {
          currentUserLabels.add('Starred');
        }
      } else {
        currentUserLabels.remove('Starred');
      }
      
      emailLabelsMap[userId] = currentUserLabels;

      await emailRef.update({'emailLabels': emailLabelsMap});

      if (mounted) {
        setState(() {
          _isStarredLocally = newStarStatus;
          // Update local email data
          widget.email['emailLabels'] = emailLabelsMap; 
          // The 'starred' field at the root of the email was a legacy field, 
          // we now rely on 'Starred' in emailLabels[userId]
          // widget.email['starred'] = newStarStatus; 
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStarStatus ? 'Đã gắn dấu sao' : 'Đã bỏ dấu sao')),
        );
      }
    } catch (e) {
      print("Error updating star status for user $userId on email $emailId: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật dấu sao: $e')),
        );
      }
    }
  }

  Future<void> _toggleReadStatus() async {
    if (_currentUser == null || widget.email['id'] == null) return;
    final newReadStatus = !_isReadLocally;

    try {
      await FirebaseFirestore.instance
          .collection('emails')
          .doc(widget.email['id'])
          .update({'emailIsReadBy.${_currentUser!.uid}': newReadStatus});

      if (mounted) {
        setState(() {
          _isReadLocally = newReadStatus;
          if (widget.email['emailIsReadBy'] is Map) {
            (widget.email['emailIsReadBy'] as Map)[_currentUser!.uid] = newReadStatus;
          } else {
            widget.email['emailIsReadBy'] = {_currentUser!.uid: newReadStatus};
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newReadStatus ? 'Đã đánh dấu là đã đọc' : 'Đã đánh dấu là chưa đọc')),
        );
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
    final String userId = _currentUser!.uid;
    final String emailId = widget.email['id'];
    
    try {
      // This assumes 'isTrashedBy' is an array field in your Firestore document
      await FirebaseFirestore.instance
          .collection('emails')
          .doc(emailId)
          .update({'isTrashedBy': FieldValue.arrayUnion([userId])});

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
    // Placeholder for label assignment logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chức năng gán nhãn (chưa triển khai)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    String senderDisplayNameToShow;
    String senderInitialToShow;
    String? senderAvatarUrlToShow;

    if (_isLoadingSenderDetailsForDetail) {
      senderDisplayNameToShow = email["senderDisplayName"] as String? ?? 
                                email["senderEmail"] as String? ?? 
                                email["from"] as String? ?? // Check 'from' field
                                'Đang tải...';
      senderInitialToShow = '?';
      senderAvatarUrlToShow = null;
    } else {
      senderDisplayNameToShow = _fetchedSenderDisplayNameForDetail ?? 
                                email["senderEmail"] as String? ?? // Fallback to email if display name is null
                                'Không rõ';
      senderInitialToShow = _senderInitialLetterForDetail;
      senderAvatarUrlToShow = _fetchedSenderAvatarUrlForDetail;
    }

    // If display name is an email, show only the part before @
    if (senderDisplayNameToShow.contains('@') && (senderDisplayNameToShow == _fetchedSenderDisplayNameForDetail || senderDisplayNameToShow == email["senderEmail"])) {
        senderDisplayNameToShow = senderDisplayNameToShow.split('@')[0];
    }


    List<String> toRecipients = List<String>.from(email['toRecipients'] ?? email['to'] ?? []);
    List<String> ccRecipients = List<String>.from(email['ccRecipients'] ?? email['cc'] ?? []);
    List<String> bccRecipients = List<String>.from(email['bccRecipients'] ?? email['bcc'] ?? []);
    
    String formattedDate;
    if (email['timestamp'] is Timestamp) {
      DateTime dt = (email['timestamp'] as Timestamp).toDate();
      // You can format this further, e.g., using the intl package
      formattedDate = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } else if (email['formattedDate'] is String) {
      formattedDate = email['formattedDate'];
    } else {
      formattedDate = 'Unknown date';
    }
    
    String displayTime = email['time'] ?? ''; // Assuming 'time' is pre-formatted like "04:00" or from timestamp

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
            icon: Icon(_isReadLocally ? Icons.mark_email_unread_outlined : Icons.mark_as_unread_outlined), // Corrected icon logic
            tooltip: _isReadLocally ? 'Đánh dấu là chưa đọc' : 'Đánh dấu là đã đọc',
            onPressed: _toggleReadStatus,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            onSelected: (value) {
              if (value == 'assign_labels') {
                _assignLabels();
              } else if (value == 'move_to') {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Di chuyển đến... (chưa triển khai)')));
              } else if (value == 'toggle_star_popup') { // Ensure this value is unique
                _toggleStarStatus();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'move_to',
                child: Text('Di chuyển đến'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'toggle_star_popup', // Changed value to avoid conflict if onTap is also used
                child: Text(_isStarredLocally ? 'Bỏ gắn dấu sao' : 'Gắn dấu sao'),
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
                    email['subject'] ?? '(Không có tiêu đề)',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Color(0xFF1f1f1f)),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isStarredLocally ? Icons.star : Icons.star_border,
                    color: _isStarredLocally ? Colors.amber[600] : Colors.grey[600],
                    size: 24,
                  ),
                  onPressed: _toggleStarStatus,
                  tooltip: _isStarredLocally ? 'Bỏ gắn dấu sao' : 'Gắn dấu sao',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  backgroundImage: senderAvatarUrlToShow != null && senderAvatarUrlToShow.isNotEmpty
                      ? NetworkImage(senderAvatarUrlToShow)
                      : null,
                  child: (senderAvatarUrlToShow == null || senderAvatarUrlToShow.isEmpty)
                      ? Text(
                          senderInitialToShow,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)
                        )
                      : null,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderDisplayNameToShow, // Use the processed display name
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF3c4043)),
                      ),
                      Row(
                        children: [
                          Text(
                            "tới tôi", // This should be dynamic if there are multiple recipients or CC/BCC
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                          // Potentially add a dropdown icon here if there are CC/BCC or multiple recipients
                          // Icon(Icons.arrow_drop_down, color: Colors.grey[700], size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  displayTime.isNotEmpty ? displayTime : formattedDate.split(' ')[1].substring(0,5), // Show time part of formattedDate if displayTime is empty
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 16), // Reduced from 20
            // Meta details (To, Date) - toggleable
            InkWell(
              onTap: () {
                setState(() {
                  _showMetaDetails = !_showMetaDetails;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Text(
                      _showMetaDetails ? "Ẩn chi tiết" : "Hiện chi tiết",
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    Icon(
                      _showMetaDetails ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: Colors.grey[700], size: 20
                    ),
                  ],
                ),
              ),
            ),
            if (_showMetaDetails)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 0), // Align with sender info
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (toRecipients.isNotEmpty)
                      Text("Tới: ${toRecipients.join(', ')}", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    if (ccRecipients.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text("Cc: ${ccRecipients.join(', ')}", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                      ),
                    if (bccRecipients.isNotEmpty) // Usually BCC is not shown to recipients
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text("Bcc: ${bccRecipients.join(', ')}", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text("Ngày: $formattedDate", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    ),
                  ],
                ),
              ),
            const Divider(height: 32), // Increased height for more spacing
            Text(
              email['body'] ?? '(Không có nội dung)',
              style: const TextStyle(fontSize: 15, color: Color(0xFF1f1f1f), height: 1.5),
            ),
            const SizedBox(height: 80), // Keep space at the bottom
          ],
        ),
      ),
      // Example for bottom action buttons:
      // bottomNavigationBar: Padding(
      //   padding: const EdgeInsets.all(8.0),
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.spaceAround,
      //     children: [
      //       TextButton.icon(icon: Icon(Icons.reply), label: Text('Reply'), onPressed: () {/* Navigate to ComposeEmailScreen with reply data */}),
      //       TextButton.icon(icon: Icon(Icons.reply_all), label: Text('Reply all'), onPressed: () {/* ... */}),
      //       TextButton.icon(icon: Icon(Icons.forward), label: Text('Forward'), onPressed: () {/* ... */}),
      //     ],
      //   ),
      // ),
    );
  }
}
