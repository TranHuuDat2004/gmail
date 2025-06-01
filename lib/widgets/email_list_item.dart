import 'package:cloud_firestore/cloud_firestore.dart'; // Added for Firestore access
import 'package:flutter/material.dart';

class EmailListItem extends StatefulWidget {
  final Map<String, dynamic> email;
  final bool isDetailedView;
  final bool isUnread;
  final VoidCallback onTap;
  final Function(bool) onStarPressed;
  final bool isSentView; // ADDED: To indicate if the item is in "Sent" view

  const EmailListItem({
    super.key, // Ensure super.key is passed
    required this.email,
    required this.isDetailedView,
    required this.isUnread,
    required this.onTap,
    required this.onStarPressed,
    required this.isSentView,
  });

  @override
  _EmailListItemState createState() => _EmailListItemState();
}

class _EmailListItemState extends State<EmailListItem> {
  late bool _isStarred;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _fetchedDisplayUserDisplayName; // RENAMED: Generic for sender or recipient
  String? _fetchedDisplayUserAvatarUrl; // RENAMED
  String _displayUserInitialLetter = '?'; // RENAMED
  bool _isLoadingDisplayDetails = true; // RENAMED

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
    } else {
      if (widget.isSentView) {
        // For sent view, check if recipientIds changed (simple check)
        final List<dynamic>? currentRecipientIds = widget.email['recipientIds'] as List<dynamic>?;
        final List<dynamic>? oldRecipientIds = oldWidget.email['recipientIds'] as List<dynamic>?;
        if (currentRecipientIds?.toString() != oldRecipientIds?.toString()) {
          needsDetailsUpdate = true;
        }
      } else {
        // For non-sent view, check if senderId changed
        if (widget.email['senderId'] != oldWidget.email['senderId']) {
          needsDetailsUpdate = true;
        }
      }
    }

    if (needsDetailsUpdate) {
      _fetchDisplayDetails(); // CHANGED
    }
  }

  Future<void> _fetchDisplayDetails() async { // RENAMED & MODIFIED
    if (!mounted) return;
    setState(() {
      _isLoadingDisplayDetails = true;
    });

    if (widget.isSentView) {
      print("EmailListItem (Sent View): Processing email ID ${widget.email['id']}"); 
      final List<dynamic>? recipientIdsDynamic = widget.email['recipientIds'] as List<dynamic>?;
      print("EmailListItem (Sent View): Raw recipientIdsDynamic from email data: $recipientIdsDynamic"); 

      final List<String> recipientIds = recipientIdsDynamic?.map((e) => e.toString()).toList() ?? [];
      print("EmailListItem (Sent View): Parsed recipientIds: $recipientIds"); 

      String recipientToDisplayId = '';
      if (recipientIds.isNotEmpty) {
        recipientToDisplayId = recipientIds.first;
        print("EmailListItem (Sent View): Will attempt to fetch details for recipient ID: '$recipientToDisplayId'"); 
      } else {
        print("EmailListItem (Sent View): No recipient IDs found in email data (widget.email['recipientIds'])."); 
      }

      String? recipientEmailForLookup;
      String? recipientNameFromData; // For potential name directly in toRecipients

      final List<dynamic>? toRecipientsList = widget.email['toRecipients'] as List<dynamic>?;
      if (toRecipientsList != null && toRecipientsList.isNotEmpty) {
        dynamic firstRecipientData = toRecipientsList.first;
        if (firstRecipientData is String) {
          recipientEmailForLookup = firstRecipientData;
        } else if (firstRecipientData is Map) {
          recipientEmailForLookup = firstRecipientData['email'] as String?;
          recipientNameFromData = firstRecipientData['name'] as String?; // If name is also in the map
        }
        if (recipientEmailForLookup != null) {
            print("EmailListItem (Sent View): Found email in 'toRecipients': '$recipientEmailForLookup'");
            if (recipientNameFromData != null) {
                 print("EmailListItem (Sent View): Found name in 'toRecipients' data: '$recipientNameFromData'");
            }
        } else {
            print("EmailListItem (Sent View): 'toRecipients' field found, but could not extract email from its first element: $firstRecipientData");
        }
      } else {
        print("EmailListItem (Sent View): 'toRecipients' field is null or empty.");
        print("EmailListItem (Sent View): Available keys in widget.email: ${widget.email.keys.toList()}");
      }
      
      // Fallback display name for recipient
      final List<dynamic>? recipientDisplayNamesList = widget.email['recipientDisplayNames'] as List<dynamic>?;
      final String? firstRecipientDisplayNameFromEmailField = (recipientDisplayNamesList != null && recipientDisplayNamesList.isNotEmpty)
          ? recipientDisplayNamesList.first?.toString()
          : null;

      String fallbackRecipientName = recipientNameFromData ?? firstRecipientDisplayNameFromEmailField ?? recipientEmailForLookup ?? 'Unknown Recipient';
      print("EmailListItem (Sent View): Fallback recipient name: '$fallbackRecipientName'"); 
      String fallbackRecipientInitial = fallbackRecipientName.isNotEmpty && fallbackRecipientName != 'Unknown Recipient'
                                       ? fallbackRecipientName[0].toUpperCase()
                                       : '?';

      if (recipientToDisplayId.isNotEmpty) {
        try {
          print("EmailListItem (Sent View): Fetching user document from Firestore for ID: '$recipientToDisplayId'"); 
          DocumentSnapshot userDoc = await _firestore.collection('users').doc(recipientToDisplayId).get();
          if (mounted) { 
            if (userDoc.exists) {
              final data = userDoc.data() as Map<String, dynamic>;
              print("EmailListItem (Sent View): Recipient user document found for ID '$recipientToDisplayId'. Data: $data"); 
              final String actualRecipientName = data['displayName'] as String? ?? fallbackRecipientName;
              _fetchedDisplayUserDisplayName = "Đến: $actualRecipientName";
              _fetchedDisplayUserAvatarUrl = data['avatarUrl'] as String?;
              if (actualRecipientName.isNotEmpty && actualRecipientName != 'Unknown Recipient') {
                _displayUserInitialLetter = actualRecipientName[0].toUpperCase();
              } else {
                _displayUserInitialLetter = fallbackRecipientInitial;
              }
              print("EmailListItem (Sent View): Fetched display name: '$_fetchedDisplayUserDisplayName', Avatar URL: '${_fetchedDisplayUserAvatarUrl ?? 'None'}'"); 
            } else {
              print("EmailListItem (Sent View): Recipient user document NOT found in Firestore for ID '$recipientToDisplayId'. Using fallback name: '$fallbackRecipientName'"); 
              _fetchedDisplayUserDisplayName = "Đến: $fallbackRecipientName";
              _fetchedDisplayUserAvatarUrl = null;
              _displayUserInitialLetter = fallbackRecipientInitial;
            }
          }
        } catch (e) {
          print("EmailListItem (Sent View): ERROR fetching recipient details for ID '$recipientToDisplayId'. Email ID ${widget.email['id']}: $e"); 
          if (mounted) {
            _fetchedDisplayUserDisplayName = "Đến: $fallbackRecipientName";
            _fetchedDisplayUserAvatarUrl = null;
            _displayUserInitialLetter = fallbackRecipientInitial;
          }
        }
      } else if (recipientEmailForLookup != null && recipientEmailForLookup.isNotEmpty) {
        print("EmailListItem (Sent View): No recipient ID. Attempting to fetch by email: '$recipientEmailForLookup'");
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
              print("EmailListItem (Sent View): Recipient user document found by email '$recipientEmailForLookup'. Data: $data");
              // MODIFIED LINE: Prioritize displayName, then name, then fallback
              final String actualRecipientName = data['displayName'] as String? ?? data['name'] as String? ?? fallbackRecipientName;
              _fetchedDisplayUserDisplayName = "Đến: $actualRecipientName";
              _fetchedDisplayUserAvatarUrl = data['avatarUrl'] as String?;
              if (actualRecipientName.isNotEmpty && actualRecipientName != 'Unknown Recipient') {
                _displayUserInitialLetter = actualRecipientName[0].toUpperCase();
              } else {
                _displayUserInitialLetter = fallbackRecipientInitial;
              }
              print("EmailListItem (Sent View): Fetched (by email) display name: '$_fetchedDisplayUserDisplayName', Avatar URL: '${_fetchedDisplayUserAvatarUrl ?? 'None'}'");
            } else {
              print("EmailListItem (Sent View): Recipient user document NOT found by email '$recipientEmailForLookup'. Using fallback name: '$fallbackRecipientName'");
              _fetchedDisplayUserDisplayName = "Đến: $fallbackRecipientName";
              _fetchedDisplayUserAvatarUrl = null;
              _displayUserInitialLetter = fallbackRecipientInitial;
            }
          }
        } catch (e) {
          print("EmailListItem (Sent View): ERROR fetching recipient details by email '$recipientEmailForLookup'. Email ID ${widget.email['id']}: $e");
          if (mounted) {
            _fetchedDisplayUserDisplayName = "Đến: $fallbackRecipientName";
            _fetchedDisplayUserAvatarUrl = null;
            _displayUserInitialLetter = fallbackRecipientInitial;
          }
        }
      } else {
        print("EmailListItem (Sent View): No valid recipientToDisplayId OR email to fetch from Firestore. Using fallback name: '$fallbackRecipientName'"); 
        if (mounted) {
          _fetchedDisplayUserDisplayName = "Đến: $fallbackRecipientName";
          _fetchedDisplayUserAvatarUrl = null;
          _displayUserInitialLetter = fallbackRecipientInitial;
        }
      }
    } else {
      // Original logic for fetching sender (Inbox, etc.)
      String? senderId = widget.email['senderId'] as String?;
      String fallbackDisplayName = widget.email['senderDisplayName'] as String? ??
                                   widget.email['senderEmail'] as String? ??
                                   widget.email['sender'] as String? ??
                                   'Unknown Sender';
      String fallbackInitial = fallbackDisplayName.isNotEmpty && fallbackDisplayName != 'Unknown Sender'
                               ? fallbackDisplayName[0].toUpperCase()
                               : '?';

      if (senderId != null && senderId.isNotEmpty) {
        try {
          DocumentSnapshot senderDoc = await _firestore.collection('users').doc(senderId).get();
          if (mounted && senderDoc.exists) {
            final data = senderDoc.data() as Map<String, dynamic>;
            _fetchedDisplayUserDisplayName = data['displayName'] as String? ??
                                        data['name'] as String? ??
                                        fallbackDisplayName;
            _fetchedDisplayUserAvatarUrl = data['avatarUrl'] as String?;
            if (_fetchedDisplayUserDisplayName != null && _fetchedDisplayUserDisplayName!.isNotEmpty && _fetchedDisplayUserDisplayName != 'Unknown Sender') {
              _displayUserInitialLetter = _fetchedDisplayUserDisplayName![0].toUpperCase();
            } else {
               _displayUserInitialLetter = fallbackInitial;
            }
          } else {
            _fetchedDisplayUserDisplayName = fallbackDisplayName;
            _fetchedDisplayUserAvatarUrl = widget.email['senderAvatarUrl'] as String?;
            _displayUserInitialLetter = fallbackInitial;
          }
        } catch (e) {
          print('Error fetching sender details for email ID ${widget.email['id']}: $e');
          _fetchedDisplayUserDisplayName = fallbackDisplayName;
          _fetchedDisplayUserAvatarUrl = widget.email['senderAvatarUrl'] as String?;
          _displayUserInitialLetter = fallbackInitial;
        }
      } else {
        _fetchedDisplayUserDisplayName = fallbackDisplayName;
        _fetchedDisplayUserAvatarUrl = widget.email['senderAvatarUrl'] as String?;
        _displayUserInitialLetter = fallbackInitial;
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingDisplayDetails = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;

    String preliminaryDisplayName;
    if (widget.isSentView) {
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
    }

    final String displayName = _isLoadingDisplayDetails
        ? preliminaryDisplayName
        : (_fetchedDisplayUserDisplayName ?? (widget.isSentView ? 'Đến: Unknown Recipient' : 'Unknown Sender'));
    
    final String? avatarUrl = _isLoadingDisplayDetails ? null : _fetchedDisplayUserAvatarUrl;
    final String initialForAvatar = _isLoadingDisplayDetails ? '?' : _displayUserInitialLetter;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: widget.isUnread ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[200],
        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty 
            ? NetworkImage(avatarUrl)
            : null,
        child: (avatarUrl == null || avatarUrl.isEmpty)
            ? Text(
                initialForAvatar,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.isUnread ? Theme.of(context).primaryColorDark : Colors.grey[700],
                ),
              )
            : null,
      ),
      title: Text(
        displayName, // Use the fetched or fallback display name
        style: TextStyle(
          fontWeight: widget.isUnread ? FontWeight.bold : FontWeight.normal,
          color: Colors.black87,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            email["subject"] ?? '(No Subject)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: widget.isUnread ? FontWeight.w500 : FontWeight.normal,
              color: widget.isUnread ? Colors.black.withOpacity(0.85) : Colors.black54,
            ),
          ),
          if (widget.isDetailedView && email["preview"] != null && (email["preview"] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                email["preview"],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min, 
        children: [
          Text(
            email["time"] ?? "",
            style: TextStyle(
              fontSize: 12,
              color: widget.isUnread ? Theme.of(context).primaryColor : Colors.grey[600],
              fontWeight: widget.isUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4), 
          SizedBox( 
            width: 24,
            height: 24,
            child: IconButton(
              icon: Icon(
                _isStarred ? Icons.star : Icons.star_border,
                color: _isStarred ? Colors.amber[600] : Colors.grey,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 18, 
              tooltip: _isStarred ? 'Unstar' : 'Star',
              onPressed: () {
                widget.onStarPressed(!_isStarred); 
              },
            ),
          ),
        ],
      ),
      onTap: widget.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
      tileColor: widget.isUnread ? Theme.of(context).primaryColor.withOpacity(0.03) : null, 
    );
  }
}
