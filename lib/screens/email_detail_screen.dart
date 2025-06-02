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
          SnackBar(
            content: Text(newStarStatus ? 'Đã gắn dấu sao' : 'Đã bỏ dấu sao'),
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.black87, // Themed SnackBar
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("Error updating star status for user $userId on email $emailId: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật dấu sao: $e'),
            backgroundColor: Theme.of(context).colorScheme.error, // Themed SnackBar
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleReadStatus() async {
    if (_currentUser == null || widget.email['id'] == null) return;
    final newReadStatus = !_isReadLocally;
    final theme = Theme.of(context); // Get theme for SnackBar

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
          SnackBar(
            content: Text(newReadStatus ? 'Đã đánh dấu là đã đọc' : 'Đã đánh dấu là chưa đọc'),
            backgroundColor: theme.brightness == Brightness.dark ? Colors.grey[700] : Colors.black87, // Themed SnackBar
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (!newReadStatus) { // If marked as unread
          Navigator.pop(context, {'markedAsUnread': true, 'emailId': widget.email['id']});
        }
      }
    } catch (e) {
      print("Error updating read status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật trạng thái đọc: $e'),
            backgroundColor: theme.colorScheme.error, // Themed SnackBar
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteEmail() async {
    if (_currentUser == null || widget.email['id'] == null) return;
    final String userId = _currentUser!.uid;
    final String emailId = widget.email['id'];
    final theme = Theme.of(context); // Get theme for SnackBar

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
          SnackBar(
            content: const Text('Đã chuyển vào Thùng rác'),
            backgroundColor: theme.brightness == Brightness.dark ? Colors.grey[700] : Colors.black87, // Themed SnackBar
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, {'deleted': true, 'emailId': widget.email['id']});
      }
    } catch (e) {
      print("Error moving email to trash: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi chuyển vào thùng rác: $e'),
            backgroundColor: theme.colorScheme.error, // Themed SnackBar
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _assignLabels() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Chức năng gán nhãn (chưa triển khai)'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.black87, // Themed SnackBar
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _archiveEmail() {
     if (_currentUser == null || widget.email['id'] == null) return;
    final String userId = _currentUser!.uid;
    final String emailId = widget.email['id'];
    final theme = Theme.of(context); // Get theme for SnackBar

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã lưu trữ'),
            backgroundColor: theme.brightness == Brightness.dark ? Colors.grey[700] : Colors.black87, // Themed SnackBar
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, {'archived': true, 'emailId': emailId});
      }
    }).catchError((e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu trữ: $e'),
            backgroundColor: theme.colorScheme.error, // Themed SnackBar
            behavior: SnackBarBehavior.floating,
          ),
        );
       }
    });
  }

  Widget _buildMetaDetailRow(BuildContext context, String label, String value) { // Added context
    if (value.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final labelColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final valueColor = isDarkMode ? Colors.grey[200] : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              "$label:",
              style: TextStyle(fontSize: 14, color: labelColor, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText( // Made value selectable
              value,
              style: TextStyle(fontSize: 14, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define colors based on theme
    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final appBarBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final appBarIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final popupMenuIconColor = appBarIconColor;
    final popupMenuBackgroundColor = isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
    final popupMenuTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final subjectColor = isDarkMode ? Colors.grey[100] : const Color(0xFF1f1f1f);
    final starColor = isDarkMode ? Colors.yellow[600] : Colors.amber[600];
    final unstarColor = isDarkMode ? Colors.grey[500] : Colors.grey[600];
    final avatarBackgroundColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final avatarTextColor = isDarkMode ? Colors.grey[300] : Colors.white70;
    final senderNameColor = isDarkMode ? Colors.grey[200] : const Color(0xFF3c4043);
    final recipientMetaColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final timeColor = recipientMetaColor;
    final metaDetailBorderColor = isDarkMode ? Colors.grey[700]! : Colors.grey.shade300;
    final dividerColor = isDarkMode ? Colors.grey[700]! : Colors.grey.shade300;
    final bodyTextColor = isDarkMode ? Colors.grey[200] : const Color(0xFF1f1f1f);
    final attachmentHeaderColor = recipientMetaColor;
    final attachmentCardBackgroundColor = isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
    final attachmentCardBorderColor = metaDetailBorderColor;
    final attachmentIconColor = isDarkMode ? Colors.blue[300] : Colors.blueAccent;
    final attachmentTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final attachmentActionIconColor = recipientMetaColor;
    final bottomNavBarBackgroundColor = appBarBackgroundColor;
    final bottomNavBarBorderColor = isDarkMode ? Colors.grey[700]! : Colors.grey.shade300;
    
    // Colors for ActionButton based on the screenshot for dark mode
    final actionButtonBackgroundColor = isDarkMode ? const Color(0xFF303134) : Colors.grey[200]; // Dark grey for dark mode button bg (Gmail style)
    final actionButtonForegroundColor = isDarkMode ? const Color(0xFFE8EAED) : Colors.black87; // Light grey for dark mode button text/icon (Gmail style)

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
      // Format: '13:59, 2 tháng 6, 2025'
      formattedDate = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}, ${dt.day} tháng ${dt.month}, ${dt.year}";
      displayTime = formattedDate;
    } else {
      formattedDate = 'Unknown date';
    }

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor,
        elevation: isDarkMode ? 0.5 : 1.0,
        iconTheme: IconThemeData(color: appBarIconColor),
        actions: [
          IconButton(
            icon: Icon(
              _isStarredLocally ? Icons.star : Icons.star_border,
              color: _isStarredLocally ? starColor : unstarColor,
              size: 20, // nhỏ hơn
            ),
            onPressed: _toggleStarStatus,
            tooltip: _isStarredLocally ? 'Bỏ gắn dấu sao' : 'Gắn dấu sao',
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Lưu trữ',
            onPressed: _archiveEmail,
            color: appBarIconColor, // Explicitly set color
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Chuyển vào Thùng rác',
            onPressed: _deleteEmail,
            color: appBarIconColor, // Explicitly set color
          ),
          IconButton(
            icon: Icon(_isReadLocally ? Icons.mark_email_unread_outlined : Icons.drafts_outlined),
            tooltip: _isReadLocally ? 'Đánh dấu là chưa đọc' : 'Đánh dấu là đã đọc',
            onPressed: _toggleReadStatus,
            color: appBarIconColor, // Explicitly set color
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: popupMenuIconColor),
            color: popupMenuBackgroundColor,
            onSelected: (value) {
              if (value == 'assign_labels') _assignLabels();
              else if (value == 'move_to') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Di chuyển đến... (chưa triển khai)'),
                    backgroundColor: isDarkMode ? Colors.grey[700] : Colors.black87, // Themed SnackBar
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'move_to', child: Text('Di chuyển đến', style: TextStyle(color: popupMenuTextColor))),
              const PopupMenuDivider(),
              PopupMenuItem<String>( 
                onTap: _toggleStarStatus,
                child: Row(
                  children: [
                    Icon(_isStarredLocally ? Icons.star : Icons.star_border, color: _isStarredLocally ? starColor : unstarColor),
                    const SizedBox(width: 8),
                    Text(_isStarredLocally ? 'Bỏ gắn dấu sao' : 'Gắn dấu sao', style: TextStyle(color: popupMenuTextColor)),
                  ],
                ),
              ),
              PopupMenuItem<String>(value: 'assign_labels', child: Text('Thay đổi nhãn', style: TextStyle(color: popupMenuTextColor))),
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
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: subjectColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: avatarBackgroundColor,
                  backgroundImage: senderAvatarUrlToShow != null && senderAvatarUrlToShow.isNotEmpty
                      ? NetworkImage(senderAvatarUrlToShow)
                      : null,
                  child: (senderAvatarUrlToShow == null || senderAvatarUrlToShow.isEmpty)
                      ? Text(senderInitialToShow, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: avatarTextColor))
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: senderNameColor),
                      ),
                      GestureDetector( 
                        onTap: () {
                           if (mounted) setState(() => _showMetaDetails = !_showMetaDetails);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "tới tôi", 
                              style: TextStyle(fontSize: 13, color: recipientMetaColor),
                            ),
                             Icon(
                              _showMetaDetails ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                              color: recipientMetaColor, size: 20
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  // Hiển thị cả ngày và giờ gửi
                  formattedDate,
                  style: TextStyle(fontSize: 13, color: timeColor),
                ),
              ],
            ),
            // const SizedBox(height: 16), // Adjusted by meta details visibility
            if (_showMetaDetails)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Container( 
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: metaDetailBorderColor, width: 0.8),
                    color: isDarkMode ? Colors.grey[850] : Colors.white, // Background for meta details box
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetaDetailRow(context, "From", email['senderEmail'] ?? email['from'] ?? 'Không rõ'), // From: luôn là email
                      _buildMetaDetailRow(context, "To", toRecipients.join(', ')), // Pass context
                      if (ccRecipients.isNotEmpty) _buildMetaDetailRow(context, "Cc", ccRecipients.join(', ')), // Pass context
                      _buildMetaDetailRow(context, "Date", formattedDate), // Pass context
                    ],
                  ),
                ),
              ),
            Divider(height: 32, color: dividerColor),
            SelectableText( 
              email['body'] ?? email['bodyContent'] ?? '(Không có nội dung)',
              style: TextStyle(fontSize: 15, color: bodyTextColor, height: 1.5),
            ),
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tệp đính kèm (${attachments.length})", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: attachmentHeaderColor)),
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
                          elevation: isDarkMode ? 0.2 : 0.5,
                          color: attachmentCardBackgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: attachmentCardBorderColor)
                          ),
                          child: ListTile(
                            leading: Icon(Icons.insert_drive_file_outlined, color: attachmentIconColor),
                            title: Text(fileName, style: TextStyle(color: attachmentTextColor, fontSize: 14)),
                            trailing: IconButton(icon: Icon(Icons.download_outlined, color: attachmentActionIconColor), onPressed: (){
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(
                                   content: Text("Tải $fileName... (chưa triển khai)"),
                                   backgroundColor: isDarkMode ? Colors.grey[700] : Colors.black87, // Themed SnackBar
                                   behavior: SnackBarBehavior.floating,
                                  ),
                                );
                            }),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Mở $fileName... (chưa triển khai)"),
                                  backgroundColor: isDarkMode ? Colors.grey[700] : Colors.black87, // Themed SnackBar
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
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
            color: bottomNavBarBackgroundColor,
            border: Border(top: BorderSide(color: bottomNavBarBorderColor, width: 0.5))),
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
                        replyOrForwardEmail: widget.email, 
                        composeMode: 'reply',
                      ),
                    ),
                  );
                },
                buttonBackgroundColor: actionButtonBackgroundColor,
                buttonForegroundColor: actionButtonForegroundColor,
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
                buttonBackgroundColor: actionButtonBackgroundColor,
                buttonForegroundColor: actionButtonForegroundColor,
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
                buttonBackgroundColor: actionButtonBackgroundColor,
                buttonForegroundColor: actionButtonForegroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}