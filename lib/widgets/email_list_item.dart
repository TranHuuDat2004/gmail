import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

class EmailListItem extends StatefulWidget {
  final Map<String, dynamic> email;
  final bool isDetailedView;
  final bool isUnread;
  final VoidCallback onTap;
  final Function(bool) onStarPressed;
  final bool isSentView;
  final bool isDraft; 
  final String? currentUserDisplayName; 
  final String? currentUserAvatarUrl; 

  const EmailListItem({
    super.key,
    required this.email,
    required this.isDetailedView,
    required this.isUnread,
    required this.onTap,
    required this.onStarPressed,
    required this.isSentView,
    this.isDraft = false, 
    this.currentUserDisplayName, 
    this.currentUserAvatarUrl, 
  });

  @override
  _EmailListItemState createState() => _EmailListItemState();
}

class _EmailListItemState extends State<EmailListItem> {
  late bool _isStarred;  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; 
  String? _fetchedDisplayUserDisplayName;
  String? _fetchedDisplayUserAvatarUrl;
  bool _isLoadingDisplayDetails = true;

  @override
  void initState() {
    super.initState();
    _isStarred = widget.email['starred'] ?? false;
    _fetchDisplayDetails();
  }
  @override
  void didUpdateWidget(EmailListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.email['starred'] != oldWidget.email['starred']) {
      _isStarred = widget.email['starred'] ?? false;
    }

    bool needsDetailsUpdate = false;
    if (widget.email['id'] != oldWidget.email['id']) {
      needsDetailsUpdate = true;
    } else if (widget.isSentView != oldWidget.isSentView) {
      needsDetailsUpdate = true;
    } else if (widget.isDraft != oldWidget.isDraft) { 
      needsDetailsUpdate = true;
    } else {
      if (widget.isSentView) {
        final List<dynamic>? currentRecipientIds = widget.email['recipientIds'] as List<dynamic>?;
        final List<dynamic>? oldRecipientIds = oldWidget.email['recipientIds'] as List<dynamic>?;
        if (currentRecipientIds?.toString() != oldRecipientIds?.toString()) {
          needsDetailsUpdate = true;
        }
      } else {
        if (widget.email['senderId'] != oldWidget.email['senderId']) {
          needsDetailsUpdate = true;
        }
      }
    }

    if (needsDetailsUpdate) {
      _fetchDisplayDetails(); 
    }
  }
  Future<void> _fetchDisplayDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDisplayDetails = true;
    });

    if (widget.isDraft) {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        _fetchedDisplayUserDisplayName = "Nháp"; 
        _fetchedDisplayUserAvatarUrl = widget.currentUserAvatarUrl ?? currentUser.photoURL;
        
        if (widget.currentUserDisplayName == null || widget.currentUserAvatarUrl == null) {
          try {
            DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
            if (mounted && userDoc.exists) {
              final data = userDoc.data() as Map<String, dynamic>;
              _fetchedDisplayUserAvatarUrl = data['avatarUrl'] as String? ?? _fetchedDisplayUserAvatarUrl;
            }
          } catch (e) {
            print("Error fetching current user details for draft: $e");
          }
        }
      } else {
        _fetchedDisplayUserDisplayName = "Nháp";
        _fetchedDisplayUserAvatarUrl = null;
      }
    } else if (widget.isSentView) {
      final List<dynamic>? recipientIdsDynamic = widget.email['recipientIds'] as List<dynamic>?; 

      final List<String> recipientIds = recipientIdsDynamic?.map((e) => e.toString()).toList() ?? [];

      String recipientToDisplayId = '';
      if (recipientIds.isNotEmpty) {
        recipientToDisplayId = recipientIds.first;
      }

      String? recipientEmailForLookup;
      String? recipientNameFromData; 

      final List<dynamic>? toRecipientsList = widget.email['toRecipients'] as List<dynamic>?;
      if (toRecipientsList != null && toRecipientsList.isNotEmpty) {
        dynamic firstRecipientData = toRecipientsList.first;
        if (firstRecipientData is String) {
          recipientEmailForLookup = firstRecipientData;
        } else if (firstRecipientData is Map) {
          recipientEmailForLookup = firstRecipientData['email'] as String?;
          recipientNameFromData = firstRecipientData['name'] as String?; 
        }
      }
      
      // Fallback display name for recipient
      final List<dynamic>? recipientDisplayNamesList = widget.email['recipientDisplayNames'] as List<dynamic>?;
      final String? firstRecipientDisplayNameFromEmailField = (recipientDisplayNamesList != null && recipientDisplayNamesList.isNotEmpty)
          ? recipientDisplayNamesList.first?.toString()
          : null;

      String fallbackRecipientName = recipientNameFromData ?? firstRecipientDisplayNameFromEmailField ?? recipientEmailForLookup ?? 'Unknown Recipient';

      if (recipientToDisplayId.isNotEmpty) {
        try {
          DocumentSnapshot userDoc = await _firestore.collection('users').doc(recipientToDisplayId).get();
          if (mounted) { 
            if (userDoc.exists) {
              final data = userDoc.data() as Map<String, dynamic>;
              final String actualRecipientName = data['displayName'] as String? ?? fallbackRecipientName;
              _fetchedDisplayUserDisplayName = "Đến: $actualRecipientName";
              _fetchedDisplayUserAvatarUrl = data['avatarUrl'] as String?;
            } else {
              _fetchedDisplayUserDisplayName = "Đến: $fallbackRecipientName";
              _fetchedDisplayUserAvatarUrl = null;
            }
          }
        } catch (e) {
          print("EmailListItem (Sent View): ERROR fetching recipient details for ID '$recipientToDisplayId'. Email ID ${widget.email['id']}: $e"); 
          if (mounted) {
            _fetchedDisplayUserDisplayName = "Đến: $fallbackRecipientName";
            _fetchedDisplayUserAvatarUrl = null;
          }
        }
      } else if (recipientEmailForLookup != null && recipientEmailForLookup.isNotEmpty) {
        try {
          QuerySnapshot userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: recipientEmailForLookup)
              .limit(1)
              .get();

          if (mounted) {
            if (userQuery.docs.isNotEmpty) {
              DocumentSnapshot userDoc = userQuery.docs.first;
              final data = userDoc.data() as Map<String, dynamic>;
              final String actualRecipientName = data['displayName'] as String? ?? data['name'] as String? ?? fallbackRecipientName;
              _fetchedDisplayUserDisplayName = "Đến: $actualRecipientName";
              _fetchedDisplayUserAvatarUrl = data['avatarUrl'] as String?;
            } else {
              print("EmailListItem (Sent View): Recipient user document NOT found by email '$recipientEmailForLookup'. Using fallback name: '$fallbackRecipientName'");
              _fetchedDisplayUserDisplayName = "Đến: $fallbackRecipientName";
              _fetchedDisplayUserAvatarUrl = null;
            }
          }
        } catch (e) {
          print("EmailListItem (Sent View): ERROR fetching recipient details by email '$recipientEmailForLookup'. Email ID ${widget.email['id']}: $e");
          if (mounted) {
            _fetchedDisplayUserDisplayName = "Đến: $fallbackRecipientName";
            _fetchedDisplayUserAvatarUrl = null;
          }
        }
      } else {
        print("EmailListItem (Sent View): No valid recipientToDisplayId OR email to fetch from Firestore. Using fallback name: '$fallbackRecipientName'"); 
        if (mounted) {
          _fetchedDisplayUserDisplayName = "Đến: $fallbackRecipientName";
          _fetchedDisplayUserAvatarUrl = null;
        }
      }
    } else {
      String? senderId = widget.email['senderId'] as String?;
      String fallbackDisplayName = widget.email['senderDisplayName'] as String? ??
                                   widget.email['senderEmail'] as String? ??
                                   widget.email['sender'] as String? ??
                                   'Unknown Sender';

      if (senderId != null && senderId.isNotEmpty) {
        try {
          DocumentSnapshot senderDoc = await _firestore.collection('users').doc(senderId).get();
          if (mounted && senderDoc.exists) {
            final data = senderDoc.data() as Map<String, dynamic>;
            _fetchedDisplayUserDisplayName = data['displayName'] as String? ??
                                        data['name'] as String? ??
                                        fallbackDisplayName;
            _fetchedDisplayUserAvatarUrl = data['avatarUrl'] as String?;
          } else {
            _fetchedDisplayUserDisplayName = fallbackDisplayName;
            _fetchedDisplayUserAvatarUrl = widget.email['senderAvatarUrl'] as String?;
          }
        } catch (e) {
          print('Error fetching sender details for email ID ${widget.email['id']}: $e');
          _fetchedDisplayUserDisplayName = fallbackDisplayName;
          _fetchedDisplayUserAvatarUrl = widget.email['senderAvatarUrl'] as String?;
        }
      } else {
        _fetchedDisplayUserDisplayName = fallbackDisplayName;
        _fetchedDisplayUserAvatarUrl = widget.email['senderAvatarUrl'] as String?;
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingDisplayDetails = false;
      });
    }
  }  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    final theme = Theme.of(context); // Get the current theme
    final isDarkMode = theme.brightness == Brightness.dark;

    String preliminaryDisplayName;
    if (widget.isDraft) {
      preliminaryDisplayName = "Nháp";
    } else if (widget.isSentView) {
        final List<dynamic>? recipientDisplayNames = widget.email['recipientDisplayNames'] as List<dynamic>?;
        final String? firstRecipientName = (recipientDisplayNames != null && recipientDisplayNames.isNotEmpty) ? recipientDisplayNames.first.toString() : null;
        final List<dynamic>? recipientEmails = widget.email['recipientEmails'] as List<dynamic>?;
        final String? firstRecipientEmail = (recipientEmails != null && recipientEmails.isNotEmpty) ? recipientEmails.first.toString() : null;
        preliminaryDisplayName = "Đến: ${firstRecipientName ?? firstRecipientEmail ?? 'Loading...'}";
    } else {
        preliminaryDisplayName = widget.email['senderDisplayName'] as String? ??
                                 widget.email['senderEmail'] as String? ??
                                 widget.email['sender'] as String? ??
                                 'Loading...';
    }final String displayName = widget.isDraft
        ? "Nháp"
        : (_isLoadingDisplayDetails
            ? preliminaryDisplayName
            : (_fetchedDisplayUserDisplayName ?? (widget.isSentView ? 'Đến: Unknown Recipient' : 'Unknown Sender')));
    
    final String? avatarUrl = widget.isDraft
        ? _fetchedDisplayUserAvatarUrl 
        : (_isLoadingDisplayDetails ? null : _fetchedDisplayUserAvatarUrl);
    
    final String rawSubject = widget.email["subject"] as String? ?? '';
    final bool isSubjectEmpty = rawSubject.trim().isEmpty;
    final String displaySubject = isSubjectEmpty
        ? (widget.isDraft ? "(Không có tiêu đề)" : (widget.isSentView ? "(Không có tiêu đề)" : "(No Subject)"))
        : rawSubject;    
    final String rawBody = widget.email["bodyPlainText"] as String? ?? widget.email["body"] as String? ?? '';
    final bool isBodyReallyEmpty = rawBody.trim().isEmpty;
    String displayBodyPreview = rawBody.trim(); 
    bool isBodyPlaceholder = false;

    if (widget.isDetailedView) {
      if (isBodyReallyEmpty) {
        displayBodyPreview = "(Không có nội dung)";
        isBodyPlaceholder = true;
      }
    } else {
      if (isBodyReallyEmpty) {
        displayBodyPreview = ''; 
      }
    }
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? NetworkImage(avatarUrl)
            : const AssetImage('assets/images/default_avatar.png'),
        child: null,
      ),      title: Text(
        displayName,
        style: TextStyle(
          fontWeight: (widget.isUnread && !widget.isDraft) ? FontWeight.bold : FontWeight.normal, // Normal for drafts
          color: isDarkMode
              ? Colors.grey[300] 
              : (widget.isDraft
                  ? Colors.black54 
                  : (widget.isUnread 
                      ? theme.colorScheme.primary 
                      : Colors.black54)),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: widget.isDetailedView
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displaySubject, 
                  style: TextStyle(
                    fontWeight: (widget.isUnread && !widget.isDraft) ? FontWeight.bold : FontWeight.normal,
                    color: isDarkMode
                        ? Colors.grey[400] 
                        : (widget.isUnread && !widget.isDraft ? const Color.fromARGB(221, 0, 0, 0) : Colors.grey[700]),
                    fontStyle: isSubjectEmpty ? FontStyle.italic : FontStyle.normal, 
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (displayBodyPreview.isNotEmpty || isBodyPlaceholder) 
                  Text(
                    displayBodyPreview,
                    style: TextStyle(
                      color: isBodyPlaceholder 
                          ? (isDarkMode ? Colors.grey[600] : Colors.grey[500]) 
                          : (isDarkMode ? Colors.grey[500] : Colors.grey[700]),
                      fontStyle: isBodyPlaceholder ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            )
          : Text( // For non-detailed view, only show subject
              displaySubject,
              style: TextStyle(
                fontWeight: (widget.isUnread && !widget.isDraft) ? FontWeight.bold : FontWeight.normal, // Normal for drafts
                color: isDarkMode
                    ? Colors.grey[400] // Đã đọc và chưa đọc đều là xám sáng ở dark mode
                    : (widget.isUnread && !widget.isDraft ? Colors.black87 : Colors.grey[700]),
                fontStyle: isSubjectEmpty ? FontStyle.italic : FontStyle.normal, // Italic for placeholder
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min, 
        children: [
          Builder(
            builder: (context) {
              final ts = email['timestamp'];
              DateTime? dt;
              if (ts is Timestamp) {
                dt = ts.toDate();
              } else if (ts is DateTime) {
                dt = ts;
              }
              String formatted = '';
              if (dt != null) {
                formatted = '${dt.day} thg ${dt.month}';
              }
              return Text(
                formatted,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.brightness == Brightness.dark
                      ? ((widget.isUnread && !widget.isDraft) ? Colors.grey[300] : Colors.grey[500])
                      : ((widget.isUnread && !widget.isDraft) ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                  fontWeight: (widget.isUnread && !widget.isDraft) ? FontWeight.bold : FontWeight.normal, 
                ),
              );
            },
          ),          const SizedBox(height: 4),
          SizedBox( 
            width: 24,
            height: 24,
            child: IconButton(
              icon: Icon(
                _isStarred ? Icons.star : Icons.star_border,
                color: _isStarred 
                    ? Colors.amber[600] 
                    : (theme.brightness == Brightness.dark ? Colors.grey[600] : theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 18, 
              tooltip: _isStarred ? 'Unstar' : 'Star',              onPressed: () async {
                setState(() {
                  _isStarred = !_isStarred;
                });
                
                widget.email['starred'] = _isStarred;
                
                final currentUser = _auth.currentUser;
                if (currentUser != null) {
                  Map<String, dynamic> emailLabelsMap = Map<String, dynamic>.from(widget.email['emailLabels'] ?? {});
                  List<dynamic> currentUserLabels = List<dynamic>.from(emailLabelsMap[currentUser.uid] ?? []);
                  
                  if (_isStarred) {
                    if (!currentUserLabels.contains('Starred')) {
                      currentUserLabels.add('Starred');
                    }
                  } else {
                    currentUserLabels.remove('Starred');
                  }
                  
                  emailLabelsMap[currentUser.uid] = currentUserLabels;
                  widget.email['emailLabels'] = emailLabelsMap;
                }
                
                await widget.onStarPressed(_isStarred);
              },
            ),
          ),
        ],
      ),
      onTap: widget.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      tileColor: (widget.isUnread && !widget.isDraft) && theme.brightness == Brightness.light 
          ? theme.colorScheme.primaryContainer.withOpacity(0.1) 
          : null,
    );
  }
}