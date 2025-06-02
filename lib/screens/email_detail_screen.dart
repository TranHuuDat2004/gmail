// lib/screens/email_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Make sure these paths are correct for your project structure
import '../widgets/action_button.dart';
import 'compose_email_screen.dart';

class EmailDetailScreen extends StatefulWidget {
  final Map<String, dynamic> email; // email should have 'id', and potentially 'senderId'
  const EmailDetailScreen({super.key, required this.email});

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  bool _showMetaDetails = false;
  late bool _isStarredLocally;
  late bool _isReadLocally;
  User? _currentUser;

  // For fetched sender details
  String? _fetchedSenderDisplayNameForDetail;
  String? _fetchedSenderAvatarUrlForDetail;
  String _senderInitialLetterForDetail = '?';
  bool _isLoadingSenderDetailsForDetail = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;

    // Initialize local star and read status based on current user and email data
    if (_currentUser != null) {
      final emailLabelsMap = widget.email['emailLabels'] as Map<String, dynamic>?;
      final userSpecificLabels = emailLabelsMap?[_currentUser!.uid] as List<dynamic>?;
      _isStarredLocally = userSpecificLabels?.contains('Starred') ?? false;

      final emailIsReadByMap = widget.email['emailIsReadBy'] as Map<String, dynamic>?;
      _isReadLocally = emailIsReadByMap?[_currentUser!.uid] as bool? ?? false;
    } else {
      _isStarredLocally = false;
      _isReadLocally = false; // Default if no user
    }

    _fetchSenderDetailsForDetailScreen();

    // Automatically mark as read in Firestore if not already read by this user
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
                    // Update local email data immediately
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
    String fallbackDisplayName = widget.email['senderDisplayName'] as String? ??
                                 widget.email['senderEmail'] as String? ??
                                 widget.email['from'] as String? ??
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
                               : fallbackInitial;
        } else {
          _fetchedSenderDisplayNameForDetail = fallbackDisplayName;
          _fetchedSenderAvatarUrlForDetail = fallbackAvatarUrl;
          _senderInitialLetterForDetail = fallbackInitial;
        }
      } catch (e) {
        print('Error fetching sender details for EmailDetailScreen (email ID ${widget.email['id']}, senderId $senderId): $e');
        _fetchedSenderDisplayNameForDetail = fallbackDisplayName;
        _fetchedSenderAvatarUrlForDetail = fallbackAvatarUrl;
        _senderInitialLetterForDetail = fallbackInitial;
      }
    } else {
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
      Map<String, dynamic> emailLabelsMap = Map<String, dynamic>.from(widget.email['emailLabels'] ?? {});
      List<dynamic> currentUserLabels = List<dynamic>.from(emailLabelsMap[userId] ?? []);

      if (newStarStatus) {
        if (!currentUserLabels.contains('Starred')) currentUserLabels.add('Starred');
      } else {
        currentUserLabels.remove('Starred');
      }
      emailLabelsMap[userId] = currentUserLabels;

      await emailRef.update({'emailLabels': emailLabelsMap});

      if (mounted) {
        setState(() {
          _isStarredLocally = newStarStatus;
          widget.email['emailLabels'] = emailLabelsMap;
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
        if (!newReadStatus) { // If marked as unread
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
      await FirebaseFirestore.instance
          .collection('emails')
          .doc(emailId)
          .update({
              // Add current user's ID to 'isTrashedBy' list (or create if it doesn't exist)
              'isTrashedBy': FieldValue.arrayUnion([userId]),
              // Remove current user's ID from 'emailLabels.userId' list to untag it from inbox/other labels
              // This ensures it doesn't show up in other views if it's only trashed by this user
              'emailLabels.$userId': FieldValue.delete(), // Example: Delete all labels for this user for this email
              // Or more specifically:
              // 'emailLabels.$userId': FieldValue.arrayRemove(['Inbox', 'Starred', ...other labels this user might have applied])
            });

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chức năng gán nhãn (chưa triển khai)')),
    );
  }
  
  void _archiveEmail() {
     if (_currentUser == null || widget.email['id'] == null) return;
    final String userId = _currentUser!.uid;
    final String emailId = widget.email['id'];

    // Example: Move to an "Archived" label and remove "Inbox"
    // This is a conceptual implementation. Your actual label logic might vary.
    FirebaseFirestore.instance.collection('emails').doc(emailId).set({
      'emailLabels': {
        userId: FieldValue.arrayUnion(['Archived']),
      },
      // To remove from Inbox, you might remove the 'Inbox' label specifically
      // 'emailLabels.$userId': FieldValue.arrayRemove(['Inbox']),
      // Or ensure 'involvedUserIds' still includes the user if archived emails are shown in 'All mail'
    }, SetOptions(merge: true)) // Use merge to update existing labels without overwriting other users'
    .then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu trữ')));
        Navigator.pop(context, {'archived': true, 'emailId': emailId});
      }
    }).catchError((e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu trữ: $e')));
       }
    });
  }

  Widget _buildMetaDetailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              "$label:",
              style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText( // Made value selectable
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
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
                                email["from"] as String? ??
                                'Đang tải...';
      senderInitialToShow = '?';
      senderAvatarUrlToShow = null;
    } else {
      senderDisplayNameToShow = _fetchedSenderDisplayNameForDetail ??
                                email["senderEmail"] as String? ??
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
    List<String> bccRecipients = List<String>.from(email['bccRecipients'] ?? email['bcc'] ?? []); // Usually not shown
    List<String> attachments = List<String>.from(email['attachments'] ?? []);


    String formattedDate;
    String displayTime = '';
    if (email['timestamp'] is Timestamp) {
      DateTime dt = (email['timestamp'] as Timestamp).toDate().toLocal();
      formattedDate = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      displayTime = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } else {
      formattedDate = 'Unknown date';
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
            onPressed: _archiveEmail,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Chuyển vào Thùng rác',
            onPressed: _deleteEmail,
          ),
          IconButton(
            icon: Icon(_isReadLocally ? Icons.mark_email_unread_outlined : Icons.drafts_outlined), // Using drafts_outlined for unread
            tooltip: _isReadLocally ? 'Đánh dấu là chưa đọc' : 'Đánh dấu là đã đọc',
            onPressed: _toggleReadStatus,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black54),
            onSelected: (value) {
              if (value == 'assign_labels') _assignLabels();
              else if (value == 'move_to') ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Di chuyển đến... (chưa triển khai)')));
              // Star toggle is handled by direct icon button, but can be added here too
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'move_to', child: Text('Di chuyển đến')),
              const PopupMenuDivider(),
              PopupMenuItem<String>( // Star/Unstar in menu
                onTap: _toggleStarStatus, // Call directly
                child: Row(
                  children: [
                    Icon(_isStarredLocally ? Icons.star : Icons.star_border, color: _isStarredLocally ? Colors.amber[600] : Colors.grey),
                    const SizedBox(width: 8),
                    Text(_isStarredLocally ? 'Bỏ gắn dấu sao' : 'Gắn dấu sao'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(value: 'assign_labels', child: Text('Thay đổi nhãn')),
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
                      ? Text(senderInitialToShow, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70))
                      : null,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderDisplayNameToShow,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF3c4043)),
                      ),
                      GestureDetector( // Make "tới tôi" tappable to show details
                        onTap: () {
                           if (mounted) setState(() => _showMetaDetails = !_showMetaDetails);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "tới tôi", // This can be dynamic based on recipients
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                             Icon(
                              _showMetaDetails ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                              color: Colors.grey[700], size: 20
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  displayTime,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            // const SizedBox(height: 16), // Adjusted by meta details visibility
            if (_showMetaDetails)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Container( // Added a container for better visual grouping
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetaDetailRow("From", _fetchedSenderDisplayNameForDetail ?? email['senderEmail'] ?? email['from'] ?? 'Không rõ'),
                      _buildMetaDetailRow("To", toRecipients.join(', ')),
                      if (ccRecipients.isNotEmpty) _buildMetaDetailRow("Cc", ccRecipients.join(', ')),
                      // if (bccRecipients.isNotEmpty) _buildMetaDetailRow("Bcc", bccRecipients.join(', ')), // Not shown to recipients
                      _buildMetaDetailRow("Date", formattedDate),
                    ],
                  ),
                ),
              ),
            const Divider(height: 32),
            SelectableText( // Made body selectable
              email['body'] ?? email['bodyContent'] ?? '(Không có nội dung)',
              style: const TextStyle(fontSize: 15, color: Color(0xFF1f1f1f), height: 1.5),
            ),
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tệp đính kèm (${attachments.length})", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: attachments.length,
                      itemBuilder: (context, index) {
                        final attachmentUrl = attachments[index];
                        String fileName = attachmentUrl.split('/').last.split('?').first;
                        try { // Decode URL component to get a readable file name
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
                            title: Text(fileName, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                            trailing: IconButton(icon: Icon(Icons.download_outlined, color: Colors.grey[700]), onPressed: (){
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tải $fileName... (chưa triển khai)")));
                               // TODO: Implement download using url_launcher or similar
                            }),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Mở $fileName... (chưa triển khai)")));
                              // TODO: Implement open/preview attachment
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
            border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5))),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
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
                        replyOrForwardEmail: widget.email, // Pass the full email map
                        composeMode: 'reply',
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ActionButton(
                icon: Icons.reply_all_outlined,
                label: "Trả lời tất cả",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ComposeEmailScreen(
                        replyOrForwardEmail: widget.email,
                        composeMode: 'replyAll',
                      ),
                    ),
                  );
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
                        replyOrForwardEmail: widget.email,
                        composeMode: 'forward',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}