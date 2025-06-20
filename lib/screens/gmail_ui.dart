import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import '../widgets/custom_drawer.dart';
import 'email_detail_screen.dart';
import 'compose_email_screen.dart';
import '../widgets/email_list_item.dart';
import '../utils/spam_classifier.dart';
import 'dart:async';

class GmailUI extends StatefulWidget {
  final User? user;

  GmailUI({super.key, this.user});

  @override
  State<GmailUI> createState() => _GmailUIState();
}

class _GmailUIState extends State<GmailUI> {
  bool showDetail = false;
  String selectedLabel = "Inbox";
  bool isDetailedView = true;
  String? _userPhotoURL;
  String? _currentUserDisplayName;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _emails = [];
  bool _isLoadingEmails = true;
  StreamSubscription? _emailStreamSubscription; 

  final List<String> userLabels = [];

  final TextEditingController _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _loadCurrentUserAvatar();
    _fetchEmails(); 
    _searchController.addListener(() {
      if (_searchController.text.trim().isEmpty) {
        _fetchEmails(); 
      }
    });
  }  /// Automatically classify emails for spam using AI(gemini api flash 1.5)
  Future<void> _classifyEmailForSpam(String emailId, String userId) async {
    try {
      final emailDoc = await _firestore.collection('emails').doc(emailId).get();
      if (!emailDoc.exists) {
        return;
      }

      final emailData = emailDoc.data() as Map<String, dynamic>;
      final emailLabelsMap = emailData['emailLabels'] as Map<String, dynamic>?;
      final userLabels = emailLabelsMap?[userId] as List<dynamic>?;
      final senderId = emailData['senderId'] as String?;
      final spamClassified = emailData['spamClassified'] as bool? ?? false;
      final timestamp = emailData['timestamp'] as Timestamp?;
      final emailTime = timestamp?.toDate();
      
      // Check if email is recent (within last 5 minutes)
      final isRecentEmail = emailTime != null && 
          emailTime.isAfter(DateTime.now().subtract(const Duration(minutes: 5)));
      
      if (senderId == userId) {
        return;
      }
      if (userLabels?.contains('Spam') == true) {
        return;
      }
      
      // For debugging: Allow re-classification of recent emails even if spamClassified=true
      if (spamClassified && !isRecentEmail) {
        return;
      } else if (spamClassified && isRecentEmail) {
        print('🔄 [SPAM_CLASSIFIER] Re-classifying recent email despite spamClassified=true');
      }final subject = emailData['subject'] as String? ?? '';
      final body = emailData['bodyPlainText'] as String? ?? emailData['body'] as String? ?? '';
      final from = emailData['from'] as String? ?? '';

      print('📝 [SPAM_CLASSIFIER] Email content:');
      print('   - Subject: ${subject.length > 50 ? subject.substring(0, 50) + "..." : subject}');
      print('   - Body length: ${body.length}');
      print('   - From: $from');

      if (subject.trim().isEmpty && body.trim().isEmpty) {
        print('⚠️ [SPAM_CLASSIFIER] Empty email content, marking as classified without API call');
        await _firestore.collection('emails').doc(emailId).update({'spamClassified': true});
        return;
      }

      print('🚀 [SPAM_CLASSIFIER] Starting API call to Gemini...');
      bool isSpam = false;
      bool classificationSuccessful = false;
      
      try {
        print('🔄 [SPAM_CLASSIFIER] Calling SpamClassifier.classifyEmail...');
        isSpam = await SpamClassifier.classifyEmail(
          subject: subject,
          body: body,
          from: from,
        ).timeout(const Duration(seconds: 10), onTimeout: () {
          print('⏰ [SPAM_CLASSIFIER] API call timed out after 10 seconds');
          return false;
        });
        classificationSuccessful = true;
        print('✅ [SPAM_CLASSIFIER] API call successful. Result: ${isSpam ? "SPAM" : "HAM"}');
      } catch (e) {
        print('❌ [SPAM_CLASSIFIER] API call failed: $e');
        isSpam = false;
        classificationSuccessful = false;
      }      
      Map<String, dynamic> currentEmailLabels = Map<String, dynamic>.from(emailLabelsMap ?? {});
      List<String> currentUserLabels = List<String>.from(currentEmailLabels[userId] ?? []);
      
      print('🏷️ [SPAM_CLASSIFIER] Processing labels...');
      print('   - Current labels before: $currentUserLabels');
      print('   - Classification successful: $classificationSuccessful');
      print('   - Is spam: $isSpam');
      
      if (isSpam && classificationSuccessful) {
        if (!currentUserLabels.contains('Spam')) {
          currentUserLabels.add('Spam');
          print('   - Added Spam label');
        }
        currentUserLabels.remove('Inbox');
        print('   - Removed Inbox label');
      } else {
        if (!currentUserLabels.contains('Inbox')) {
          currentUserLabels.add('Inbox');
          print('   - Added Inbox label');
        }
      }
      
      currentEmailLabels[userId] = currentUserLabels;
      print('   - Final labels: $currentUserLabels');        print('💾 [SPAM_CLASSIFIER] Updating database...');
      await _firestore.collection('emails').doc(emailId).update({
        'emailLabels': currentEmailLabels,
        'spamClassified': true,
      });
      print('✅ [SPAM_CLASSIFIER] Database updated successfully');} catch (e) {
      print('❌ [SPAM_CLASSIFIER] Error in classification process: $e');
      // Don't mark as classified if there was an error
      print('❌ [SPAM_CLASSIFIER] Error occurred, not marking as classified to allow retry');
    }
  }

  /// Toggle spam status for an email
  Future<void> _toggleSpamStatus(String emailId, String userId, bool isSpam) async {
    try {
      final emailDoc = await _firestore.collection('emails').doc(emailId).get();
      if (!emailDoc.exists) return;

      final emailData = emailDoc.data() as Map<String, dynamic>;
      final emailLabelsMap = emailData['emailLabels'] as Map<String, dynamic>?;
      
      Map<String, dynamic> currentEmailLabels = Map<String, dynamic>.from(emailLabelsMap ?? {});
      List<String> currentUserLabels = List<String>.from(currentEmailLabels[userId] ?? []);
      
      if (isSpam) {
        if (!currentUserLabels.contains('Spam')) {
          currentUserLabels.add('Spam');
        }
        currentUserLabels.remove('Inbox');
      } else {
        currentUserLabels.remove('Spam');
        if (!currentUserLabels.contains('Inbox')) {
          currentUserLabels.add('Inbox');
        }
      }
      
      currentEmailLabels[userId] = currentUserLabels;
      
      await _firestore.collection('emails').doc(emailId).update({
        'emailLabels': currentEmailLabels,
        'spamClassified': true,
      });
      
      _fetchEmails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating spam status: $e')),
        );
      }
    }
  }

  Future<void> _fetchEmails() async {
  if (!mounted) return;

  await _emailStreamSubscription?.cancel();
  _emailStreamSubscription = null;

  setState(() {
    _isLoadingEmails = true;
  });

  final currentUser = _auth.currentUser;
  if (currentUser == null) {
    if (mounted) {
      setState(() {
        _emails = [];
        _isLoadingEmails = false;
      });
    }
    return;
  }

  try {    if (selectedLabel == "Drafts") {
      // Use real-time updates for drafts
      _emailStreamSubscription = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('drafts')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
        final emailsToDisplay = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          data['isUnread'] = false; 
          data['starred'] = data['starred'] ?? false;
          data['isDraft'] = true;
          data['subject'] = data['subject'];
          data['body'] = data['body'] ?? '';
          data['bodyPlainText'] = data['bodyPlainText'] ?? data['body'] ?? '';
          data['emailLabels'] = {currentUser.uid: ['Drafts']};
          data['emailIsReadBy'] = {currentUser.uid: true};
          data['from'] = currentUser.email;
          data['toRecipients'] = data['toRecipients'] ?? [];
          return data;
        }).toList();
        
        if (mounted) {
          setState(() {
            _emails = emailsToDisplay;
            _isLoadingEmails = false;
          });
        }
      }, onError: (error) {        if (mounted) {
          setState(() {
            _isLoadingEmails = false;
            _emails = [];
          });
        }
      });
    }else if (selectedLabel == "Starred") {
      Query emailQuery = _firestore.collection('emails');
      emailQuery = emailQuery.where('involvedUserIds', arrayContains: currentUser.uid);
      emailQuery = emailQuery.orderBy('timestamp', descending: true);
      final emailSnapshot = await emailQuery.get();
      final allUserEmails = emailSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final emailIsReadBy = data['emailIsReadBy'] as Map<String, dynamic>?;
        bool isUnread = true;
        if (emailIsReadBy != null && emailIsReadBy[currentUser.uid] == true) {
          isUnread = false;
        }
        data['isUnread'] = isUnread;
        final emailLabelsMap = data['emailLabels'] as Map<String, dynamic>?;
        bool isStarred = false;
        if (emailLabelsMap != null &&
            emailLabelsMap[currentUser.uid] is List &&
            (emailLabelsMap[currentUser.uid] as List).contains('Starred')) {
          isStarred = true;
        }
        data['starred'] = isStarred;
        data['isDraft'] = false;
        return data;
      }).toList();
      final starredEmails = allUserEmails.where((data) {
        final isTrashedBy = List<String>.from(data['isTrashedBy'] ?? []);
        final permanentlyDeletedBy = List<String>.from(data['permanentlyDeletedBy'] ?? []);
        return data['starred'] == true && !isTrashedBy.contains(currentUser.uid) && !permanentlyDeletedBy.contains(currentUser.uid);
      }).toList();
      
      final starredDraftsSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('drafts')
          .where('starred', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .get();
      final starredDrafts = starredDraftsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['isUnread'] = false;
        data['starred'] = true;
        data['isDraft'] = true;
        data['subject'] = data['subject'];
        data['body'] = data['body'] ?? '';
        data['bodyPlainText'] = data['bodyPlainText'] ?? data['body'] ?? '';
        data['emailLabels'] = {currentUser.uid: ['Drafts']};
        data['emailIsReadBy'] = {currentUser.uid: true};
        data['from'] = currentUser.email;
        data['toRecipients'] = data['toRecipients'] ?? [];
        return data;
      }).toList();
      
      var emailsToDisplay = [...starredEmails, ...starredDrafts];
      emailsToDisplay.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      if (mounted) {
        setState(() {
          _emails = emailsToDisplay;
          _isLoadingEmails = false;
        });
      }
    } else if (selectedLabel == "Trash") {
      Query query = _firestore.collection('emails');
      query = query.where('involvedUserIds', arrayContains: currentUser.uid);
      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();

      final emailsToDisplay = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          })
          .where((data) {
            final isTrashedBy = List<String>.from(data['isTrashedBy'] ?? []);
            return isTrashedBy.contains(currentUser.uid);
          })
          .map((data) {
            final emailIsReadBy = data['emailIsReadBy'] as Map<String, dynamic>?;
            bool isUnread = true;
            if (emailIsReadBy != null && emailIsReadBy[currentUser.uid] == true) {
              isUnread = false;
            }
            data['isUnread'] = isUnread;

            final emailLabelsMap = data['emailLabels'] as Map<String, dynamic>?;
            bool isStarred = false;
            if (emailLabelsMap != null &&
                emailLabelsMap[currentUser.uid] is List &&
                (emailLabelsMap[currentUser.uid] as List).contains('Starred')) {
              isStarred = true;
            }
            data['starred'] = isStarred;

            bool isDraft = false; // Drafts are not typically in the main trash query
            data['isDraft'] = isDraft;

            return data;
          })
          .toList();
      if (mounted) {
        setState(() {
          _emails = emailsToDisplay;
          _isLoadingEmails = false;
        });
      }
    } else { 
      Query query = _firestore.collection('emails');
      query = query.where('involvedUserIds', arrayContains: currentUser.uid);
      query = query.orderBy('timestamp', descending: true);        _emailStreamSubscription = query.snapshots().listen((snapshot) {
          final allUserEmails = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;

            final emailIsReadBy = data['emailIsReadBy'] as Map<String, dynamic>?;
            bool isUnread = true;
            if (emailIsReadBy != null && emailIsReadBy[currentUser.uid] == true) {
              isUnread = false;
            }
            data['isUnread'] = isUnread;

            final emailLabelsMap = data['emailLabels'] as Map<String, dynamic>?;
            bool isStarred = false;
            if (emailLabelsMap != null &&
                emailLabelsMap[currentUser.uid] is List &&
                (emailLabelsMap[currentUser.uid] as List).contains('Starred')) {
              isStarred = true;
            }
            data['starred'] = isStarred;
            data['isDraft'] = false;
            return data;
          }).toList();          // Classify new emails for spam
          for (var email in allUserEmails) {
            final emailId = email['id'] as String;
            final spamClassified = email['spamClassified'] as bool? ?? false;
            
            if (!spamClassified) {
              _classifyEmailForSpam(emailId, currentUser.uid);
            }
          }

          final filteredEmails = allUserEmails.where((data) {
            final isTrashedBy = List<String>.from(data['isTrashedBy'] ?? []);
            final permanentlyDeletedBy = List<String>.from(data['permanentlyDeletedBy'] ?? []);
            return !isTrashedBy.contains(currentUser.uid) && !permanentlyDeletedBy.contains(currentUser.uid);
          }).toList();

        List<Map<String, dynamic>> emailsToDisplay;
        if (selectedLabel == "All inboxes" || selectedLabel == "Inbox") { 
          emailsToDisplay = filteredEmails.where((email) {
            final emailLabelsMap = email['emailLabels'] as Map<String, dynamic>?;
            if (emailLabelsMap != null && emailLabelsMap[currentUser.uid] is List) {
              final userSpecificLabels = List<String>.from(emailLabelsMap[currentUser.uid] as List);
              if (userSpecificLabels.contains("Inbox")) return true;
              if (selectedLabel == "All inboxes" && 
                  !userSpecificLabels.contains("Sent") && 
                  !userSpecificLabels.contains("Drafts") &&
                  !userSpecificLabels.contains("Trash") 
                 ) {
                if (userSpecificLabels.isEmpty) return true; 
                bool isInSpecialFolder = userSpecificLabels.any((l) => ["Sent", "Drafts"].contains(l));
                if (!isInSpecialFolder) return true;
              }
            } else if (selectedLabel == "All inboxes") { 
              return true;
            }
            if (selectedLabel == "Inbox" && emailLabelsMap != null && emailLabelsMap[currentUser.uid] is List) {
                 final userSpecificLabels = List<String>.from(emailLabelsMap[currentUser.uid] as List);
                 return userSpecificLabels.contains("Inbox");
            }
            return selectedLabel == "All inboxes"; 
          }).toList();
        } else if (selectedLabel == "Sent") {
            emailsToDisplay = filteredEmails.where((email) {
            final fromMatches = (email['from'] as String?)?.toLowerCase() == currentUser.email?.toLowerCase();
            final senderIdMatches = email['senderId'] == currentUser.uid;
            final emailLabelsMap = email['emailLabels'] as Map<String, dynamic>?;
            bool hasSentLabel = false;
            if (emailLabelsMap != null && emailLabelsMap[currentUser.uid] is List) {
              final userSpecificLabels = List<String>.from(emailLabelsMap[currentUser.uid] as List);
              hasSentLabel = userSpecificLabels.contains("Sent");
            }
            return (fromMatches || senderIdMatches) || hasSentLabel;
          }).toList();
        } else if (selectedLabel == "Spam") {
          emailsToDisplay = filteredEmails.where((email) {
            final emailLabelsMap = email['emailLabels'] as Map<String, dynamic>?;
            if (emailLabelsMap != null && emailLabelsMap[currentUser.uid] is List) {
              final userSpecificLabels = List<String>.from(emailLabelsMap[currentUser.uid] as List);
              return userSpecificLabels.contains("Spam");
            }
            return false;
          }).toList();
        } else { // Custom labels
          emailsToDisplay = filteredEmails.where((email) {
            final emailLabelsMap = email['emailLabels'] as Map<String, dynamic>?;
            if (emailLabelsMap != null && emailLabelsMap[currentUser.uid] is List) {
              final userSpecificLabels = List<String>.from(emailLabelsMap[currentUser.uid] as List);
              return userSpecificLabels.contains(selectedLabel);
            }
            return false;
          }).toList();
        }

        if (mounted) {
          setState(() {
            _emails = emailsToDisplay;
            _isLoadingEmails = false;
          });
        }
      }, onError: (error) {        if (mounted) {
          setState(() {
            _isLoadingEmails = false;
            _emails = []; // Clear emails on error
          });
        }
      });
    }
  } catch (e) {    print("Error in _fetchEmails outer try-catch: $e");
    if (mounted) {
      setState(() {
        _isLoadingEmails = false;
        _emails = [];
      });
    }
  }
}

  Future<void> _loadCurrentUserAvatar({bool forceRefresh = false}) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _userPhotoURL = null;
          _currentUserDisplayName = null;
        });
      }
      return;
    }

    if (!forceRefresh && _userPhotoURL != null && _userPhotoURL!.isNotEmpty) {
      return;
    }

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (mounted && userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        final String? firestoreAvatarUrl = data['avatarUrl'];
        final String? displayName = data['displayName'] ?? data['name'];

        if (forceRefresh || _currentUserDisplayName != displayName) {
          setState(() {
            _currentUserDisplayName = displayName;
          });
        }

        if (firestoreAvatarUrl != null && firestoreAvatarUrl.trim().isNotEmpty) {
          // ignore: unrelated_type_equality_checks
          if (forceRefresh || _userPhotoURL != firestoreAvatarUrl) {
            setState(() {
              _userPhotoURL = firestoreAvatarUrl;
            });
          }
        } else {
          if (forceRefresh || _userPhotoURL != null) {
            setState(() {
              _userPhotoURL = null;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _userPhotoURL = null;
            _currentUserDisplayName = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userPhotoURL = null;
          _currentUserDisplayName = null;
        });
      }
    }
  }

  void _updateUserLabels(List<String> updatedLabels) {
    setState(() {
      userLabels.clear();
      userLabels.addAll(updatedLabels);
    });
  }

  Future<void> _searchEmails(String keyword) async {
    if (!mounted) return;
    setState(() {
      _isLoadingEmails = true;
    });

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _emails = [];
        _isLoadingEmails = false;
      });
      return;
    }

    try {
      Query query = _firestore.collection('emails')
        .where('involvedUserIds', arrayContains: currentUser.uid)
        .orderBy('timestamp', descending: true);

      final snapshot = await query.get();

      final allUserEmails = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      final lowerKeyword = keyword.toLowerCase();
      final filteredEmails = allUserEmails.where((email) {
        final subject = (email['subject'] ?? '').toString().toLowerCase();
        final body = (email['body'] ?? '').toString().toLowerCase();
        final senderDisplayName = (email['senderDisplayName'] ?? '').toString().toLowerCase();
        final senderEmail = (email['senderEmail'] ?? '').toString().toLowerCase();
        final from = (email['from'] ?? '').toString().toLowerCase();
        return subject.contains(lowerKeyword) ||
               body.contains(lowerKeyword) ||
               senderDisplayName.contains(lowerKeyword) ||
               senderEmail.contains(lowerKeyword) ||
               from.contains(lowerKeyword);
      }).toList();

      setState(() {
        _emails = filteredEmails;
        _isLoadingEmails = false;
      });    } catch (e) {
      setState(() {
        _isLoadingEmails = false;
        _emails = [];
      });
    }
  }
  /// Temporarily reset spam classification for testing
  Future<void> _resetSpamClassification() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      final snapshot = await _firestore.collection('emails')
          .where('involvedUserIds', arrayContains: currentUser.uid)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'spamClassified': false});
      }
      
      await batch.commit();
      
      // Refresh emails
      _fetchEmails();
    } catch (e) {
      // Silent error handling
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); 
    final bool isDarkMode = theme.brightness == Brightness.dark; 

    final Color fabBackgroundColor = isDarkMode 
        ? const Color(0xFFC62828) // Dark red for dark mode
        : Colors.blue; // Blue for light mode
    final Color fabForegroundColor = isDarkMode 
        ? Colors.white.withOpacity(0.95) // Light white for dark mode
        : Colors.white; // White for light mode text/icon

    return Scaffold(
      backgroundColor: theme.colorScheme.background, 
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface, // Use theme color
        elevation: 0.0, 
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: 70,
        title: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8, left: 12, right: 12),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark ? theme.colorScheme.surface : Colors.grey[200], // Updated dark mode color
            borderRadius: BorderRadius.circular(30.0), // Increased border radius
            boxShadow: const [], // Keep shadow explicitly empty
          ),
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu, color: theme.iconTheme.color), // Use theme icon color
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SearchScreen()),
                    );
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: _searchController,
                      cursorColor: theme.colorScheme.onSurfaceVariant, // Use theme color
                      decoration: InputDecoration(
                        hintText: "Search in mail",
                        hintStyle: TextStyle(color: theme.hintColor), // Use theme hint color
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none, // Explicitly remove enabled border
                        focusedBorder: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant), // Use theme text color
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _searchEmails(value.trim());
                        } else {
                          _fetchEmails();
                        }
                      },
                    ),
                  ),
                ),
              ),              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () async {
                    final bool? avatarChanged = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                    if (avatarChanged == true && mounted) {
                      _loadCurrentUserAvatar(forceRefresh: true);
                    }
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: (_userPhotoURL != null && _userPhotoURL!.isNotEmpty)
                        ? NetworkImage(_userPhotoURL!)
                        : const AssetImage('assets/images/default_avatar.png'),
                    child: null, 
                    backgroundColor: (_userPhotoURL == null || _userPhotoURL!.isEmpty)
                        ? theme.colorScheme.primary 
                        : Colors.transparent,
                  ),
                ),
              ),
              // Debug button to reset spam classification
              if (selectedLabel == "Spam")
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Icon(Icons.refresh, color: theme.iconTheme.color),
                    tooltip: 'Reset spam classification',
                    onPressed: _resetSpamClassification,
                  ),
                ),
            ],
          ),
        ),
      ),        drawer: CustomDrawer(
        selectedLabel: selectedLabel,
        onLabelSelected: (label) {
          setState(() {
            selectedLabel = label;
            _fetchEmails();
          });
        },
        userLabels: userLabels,
        onUserLabelsUpdated: _updateUserLabels,
        currentUserDisplayName: _currentUserDisplayName,
        currentUserEmail: _auth.currentUser?.email,
        currentUserAvatarUrl: _userPhotoURL,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 18.0, right: 15.0, top: 8.0, bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12, 
                    color: theme.brightness == Brightness.dark ? Colors.grey[400] : theme.colorScheme.onSurface.withOpacity(0.7), // Adjusted for dark mode
                    fontWeight: FontWeight.w500
                  ), 
                ),
                IconButton(
                  icon: Icon(
                    isDetailedView ? Icons.view_list_outlined : Icons.view_comfortable_outlined,
                    color: theme.iconTheme.color, // Use theme icon color
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: isDetailedView ? 'Switch to compact view' : 'Switch to comfortable view',
                  onPressed: () {
                    setState(() {
                      isDetailedView = !isDetailedView;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingEmails
                ? const Center(child: CircularProgressIndicator())
                : _emails.isEmpty
                    ? Center(child: Text('No emails in $selectedLabel.'))
                    : ListView.builder(
                        itemCount: _emails.length,
                        itemBuilder: (context, index) {
                          final email = _emails[index];
                          return EmailListItem(
                            email: email,
                            isDetailedView: isDetailedView,
                            isUnread: email['isUnread'] ?? true,
                            isSentView: selectedLabel == "Sent",
                            isDraft: email['isDraft'] ?? false,
                            currentUserDisplayName: _currentUserDisplayName,
                            currentUserAvatarUrl: _userPhotoURL,                              onTap: () async {
                              if (email['isDraft'] == true) {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ComposeEmailScreen(draftToLoad: email),
                                  ),
                                );
                                if (result is Map && mounted && (selectedLabel == "Drafts" || selectedLabel == "Starred")) {
                                  if (result['draftUpdated'] == true || result['draftDeleted'] == true || result['emailSent'] == true) {
                                    _fetchEmails();
                                  }
                                }
                                return;
                              }

                              final currentUser = _auth.currentUser;
                              if (currentUser != null && (email['isUnread'] ?? true) && selectedLabel != "Drafts") {
                                try {
                                  await _firestore.collection('emails').doc(email['id']).update({
                                    'emailIsReadBy.${currentUser.uid}': true,
                                  });
                                  if (mounted) {
                                    setState(() {
                                      email['isUnread'] = false; 
                                      Map<String, dynamic> currentEmailIsReadBy = {};
                                      if (email['emailIsReadBy'] != null) {
                                        try {
                                          currentEmailIsReadBy = Map<String, dynamic>.from(email['emailIsReadBy']);
                                        } catch (e) {
                                          print("Warning: Could not cast email['emailIsReadBy'] to Map<String, dynamic> during initial read marking.");
                                        }
                                      }
                                      email['emailIsReadBy'] = {
                                        ...currentEmailIsReadBy,
                                        currentUser.uid: true,
                                      };
                                    });
                                  }
                                } catch (e) {
                                  print("Error marking email as read on tap: $e");
                                }
                              }                                final result = await Navigator.push(
                                context,
                                MaterialPageRoute(                                  builder: (context) => EmailDetailScreen(
                                    email: Map<String, dynamic>.from(email), 
                                    isSentView: selectedLabel == "Sent",
                                    toggleSpamStatus: _toggleSpamStatus,
                                  ),
                                ),
                              );
                              if (result is Map<String, dynamic> && mounted) {
                                final currentUser = _auth.currentUser;                                
                                setState(() {
                                  final emailIndex = _emails.indexWhere((e) => e['id'] == result['id']);
                                  if (emailIndex != -1) {
                                    _emails[emailIndex] = result;
                                    final emailIsReadBy = result['emailIsReadBy'] as Map<String, dynamic>?;
                                    if (currentUser != null) {
                                      _emails[emailIndex]['isUnread'] = !(emailIsReadBy?[currentUser.uid] ?? false);
                                    }
                                  }
                                  final isTrashedBy = List<String>.from(result['isTrashedBy'] ?? []);
                                  if (currentUser?.uid != null && isTrashedBy.contains(currentUser!.uid) && selectedLabel != "Trash") {
                                    _emails.removeWhere((e) => e['id'] == result['id']);
                                  }
                                  if (selectedLabel == "Trash" && currentUser?.uid != null && 
                                      !isTrashedBy.contains(currentUser!.uid)) {
                                    _emails.removeWhere((e) => e['id'] == result['id']);
                                  }
                                });
                              } else if (result == 'permanently_deleted' && mounted) {
                                setState(() {
                                  _emails.removeWhere((e) => e['id'] == email['id']);
                                });
                              }
                            },
                            onStarPressed: (bool newStarState) async { // Marked async
                              final currentUser = _auth.currentUser;
                              if (currentUser == null) return;

                              final emailId = email['id'] as String?;
                              if (emailId == null) return; // Corrected if condition

                              final bool isDraftEmail = email['isDraft'] == true || selectedLabel == "Drafts";                              
                              if (isDraftEmail) {
                                try {
                                  await _firestore // await is valid here
                                      .collection('users')
                                      .doc(currentUser.uid)
                                      .collection('drafts')
                                      .doc(emailId)
                                      .update({'starred': newStarState});
                                  
                                  if (mounted) {
                                    setState(() {
                                      email['starred'] = newStarState;
                                      if (selectedLabel == "Starred" && !newStarState) {
                                        _fetchEmails();
                                      }
                                    });
                                  }
                                } catch (e) {
                                  print("Error updating draft star status: $e");
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error updating draft star status: $e')),
                                    );
                                  }
                                }
                                return;
                              }

                              try {
                                List<String> currentLabels = List<String>.from(email['emailLabels']?[currentUser.uid] ?? []);
                                if (newStarState) {
                                  if (!currentLabels.contains('Starred')) {
                                    currentLabels.add('Starred');
                                  }
                                } else {
                                  currentLabels.remove('Starred');
                                }
                                await _firestore.collection('emails').doc(emailId).update({ // await is valid here
                                  'emailLabels.${currentUser.uid}': currentLabels,
                                  'starred': newStarState,
                                });

                                if (mounted) {
                                  setState(() {
                                    email['starred'] = newStarState;
                                    if (selectedLabel == "Starred" && !newStarState) {
                                      _fetchEmails();
                                    }
                                  });
                                }
                              } catch (e) {
                                print("Error updating star status: $e");
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error updating star status: $e')),
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),        floatingActionButton: FloatingActionButton.extended(
        backgroundColor: fabBackgroundColor,
        elevation: 2.0,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeEmailScreen()),
          );
          if (result is Map && mounted && (selectedLabel == "Drafts" || selectedLabel == "Starred")) {
            if (result['draftUpdated'] == true || result['draftDeleted'] == true || result['emailSent'] == true) {
              _fetchEmails();
            }
          }
        },
        icon: Icon(Icons.edit, color: fabForegroundColor),
        label: Text("Compose", style: TextStyle(color: fabForegroundColor, fontWeight: FontWeight.w500)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _emailStreamSubscription?.cancel(); // Cancel stream subscription
    super.dispose();
  }
}