import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';
import 'search_overlay_screen.dart';
import 'search_screen.dart';
import '../widgets/custom_drawer.dart';
import 'email_detail_screen.dart';
import 'compose_email_screen.dart';
import '../widgets/email_list_item.dart';

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
  }

  Future<void> _fetchEmails() async {
  if (!mounted) return;
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

  try {
    List<Map<String, dynamic>> emailsToDisplay = [];

    if (selectedLabel == "Drafts") {
      final draftsSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('drafts')
          .orderBy('timestamp', descending: true)
          .get();
      emailsToDisplay = draftsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['isUnread'] = false; // Drafts should not be bold
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
    } else if (selectedLabel == "Starred") {
      // Query both emails and drafts for starred items
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
        return data['starred'] == true && !isTrashedBy.contains(currentUser.uid);
      }).toList();
      // Query starred drafts
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
      // Combine and sort by timestamp
      emailsToDisplay = [...starredEmails, ...starredDrafts];
      emailsToDisplay.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
    } else if (selectedLabel == "Trash") {
      Query query = _firestore.collection('emails');
      query = query.where('involvedUserIds', arrayContains: currentUser.uid);
      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();

      emailsToDisplay = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          })
          .where((data) {
            // Lọc phía client: chỉ giữ email có isTrashedBy chứa currentUser.uid
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

            bool isDraft = false;
            if (emailLabelsMap != null &&
                emailLabelsMap[currentUser.uid] is List &&
                (emailLabelsMap[currentUser.uid] as List).contains('Drafts')) {
              isDraft = true;
            }
            data['isDraft'] = isDraft;

            return data;
          })
          .toList();
    } else {
      Query query = _firestore.collection('emails');
      query = query.where('involvedUserIds', arrayContains: currentUser.uid);
      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();

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

        bool isDraft = false;
        if (emailLabelsMap != null &&
            emailLabelsMap[currentUser.uid] is List &&
            (emailLabelsMap[currentUser.uid] as List).contains('Drafts')) {
          isDraft = true;
        }
        data['isDraft'] = isDraft;

        return data;
      }).toList();

      // Lọc bỏ các email có isTrashedBy chứa currentUser.uid
      final filteredEmails = allUserEmails.where((data) {
        final isTrashedBy = List<String>.from(data['isTrashedBy'] ?? []);
        return !isTrashedBy.contains(currentUser.uid);
      }).toList();      if (selectedLabel == "All inboxes") {
        emailsToDisplay = filteredEmails;      } else {
        emailsToDisplay = filteredEmails.where((email) {
          final emailLabelsMap = email['emailLabels'] as Map<String, dynamic>?;
          if (emailLabelsMap != null && emailLabelsMap[currentUser.uid] is List) {
            final userSpecificLabels = List<String>.from(emailLabelsMap[currentUser.uid] as List);
            return userSpecificLabels.contains(selectedLabel);
          }
          return false;
        }).toList();
      }
    }

    if (mounted) {
      setState(() {
        _emails = emailsToDisplay;
        _isLoadingEmails = false;
      });
    }
  } catch (e) {
    print("Error fetching emails: $e");
    if (mounted) {
      setState(() {
        _isLoadingEmails = false;
        _emails = [];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching emails: $e')),
          );
        }
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

      // Lọc theo từ khóa (subject, body, sender, ...), không phân biệt hoa thường
      final lowerKeyword = keyword.toLowerCase();
      final filteredEmails = allUserEmails.where((email) {
        final subject = (email['subject'] ?? '').toString().toLowerCase();
        final body = (email['body'] ?? '').toString().toLowerCase();
        // Thêm kiểm tra các trường có thể chứa tên/email người gửi
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
      });
    } catch (e) {
      setState(() {
        _isLoadingEmails = false;
        _emails = [];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi tìm kiếm: $e')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get the current theme
    final bool isDarkMode = theme.brightness == Brightness.dark; // Check for dark mode

    // Define FAB colors based on theme
    final Color fabBackgroundColor = isDarkMode 
        ? const Color(0xFFC62828) // Dark red for dark mode
        : Colors.blue; // Blue for light mode
    final Color fabForegroundColor = isDarkMode 
        ? Colors.white.withOpacity(0.95) // Light white for dark mode
        : Colors.white; // White for light mode text/icon

    return Scaffold(
      backgroundColor: theme.colorScheme.background, // Use theme color
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface, // Use theme color
        elevation: 0.0, // Keep elevation 0 as per previous settings
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: 70,
        title: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8, left: 12, right: 12),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark ? theme.colorScheme.surface : Colors.grey[200], // Updated dark mode color
            borderRadius: BorderRadius.circular(30.0), // Increased border radius
            // border: Border.all( // Border remains removed as per previous request
            //   color: theme.brightness == Brightness.light ? Colors.grey.shade400 : Colors.grey.shade700,
            //   width: 1.0,
            // ),
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
              ),
              Padding(
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
                    child: null, // Ensures no icon or text is overlaid on the backgroundImage
                    backgroundColor: (_userPhotoURL == null || _userPhotoURL!.isEmpty)
                        ? theme.colorScheme.primary // Fallback color if asset image is transparent or fails
                        : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),      drawer: CustomDrawer(
        selectedLabel: selectedLabel,
        onLabelSelected: (label) {
          setState(() {
            selectedLabel = label;
            _fetchEmails();
          });
          Navigator.pop(context);
        },
        userLabels: userLabels,
        emails: _emails,
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
                            currentUserAvatarUrl: _userPhotoURL,                            onTap: () async {
                              if (email['isDraft'] == true) {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ComposeEmailScreen(draftToLoad: email),
                                  ),
                                );
                                if (result is Map && mounted && (selectedLabel == "Drafts" || selectedLabel == "Starred")) {
                                  if (result['draftUpdated'] == true || result['draftDeleted'] == true) {
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
          email['isUnread'] = false; // Cập nhật trực tiếp email này
          // Cập nhật cả map emailIsReadBy trong email này để đồng bộ
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
                              }                              // Navigate to EmailDetailScreen and wait for result
                              final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EmailDetailScreen(
                                      // Truyền một BẢN SAO của email để EmailDetailScreen có thể sửa đổi
                                      // mà không ảnh hưởng trực tiếp đến đối tượng trong _emails cho đến khi pop
                                      email: Map<String, dynamic>.from(email), // <<<< QUAN TRỌNG: TRUYỀN BẢN SAO
                                      isSentView: selectedLabel == "Sent",
                                    ),
                                  ),
                                );                              // If result is a Map (email was updated in detail screen), refresh the list
                              if (result is Map<String, dynamic> && mounted) {
                                // Update email in list and refresh current view if needed
                                final currentUser = _auth.currentUser;                                setState(() {
                                  final emailIndex = _emails.indexWhere((e) => e['id'] == result['id']);
                                  if (emailIndex != -1) {
                                    _emails[emailIndex] = result;
                                    
                                    // Cập nhật trạng thái isUnread dựa trên emailIsReadBy
                                    final emailIsReadBy = result['emailIsReadBy'] as Map<String, dynamic>?;
                                    if (currentUser != null) {
                                      _emails[emailIndex]['isUnread'] = !(emailIsReadBy?[currentUser.uid] ?? false);
                                    }
                                  }
                                  // If email was moved to trash, remove it from current view (except Trash view)
                                  final isTrashedBy = List<String>.from(result['isTrashedBy'] ?? []);
                                  if (currentUser?.uid != null && isTrashedBy.contains(currentUser!.uid) && selectedLabel != "Trash") {
                                    _emails.removeWhere((e) => e['id'] == result['id']);
                                  }
                                  // If email was restored from trash, remove it from Trash view
                                  if (selectedLabel == "Trash" && currentUser?.uid != null && 
                                      !isTrashedBy.contains(currentUser!.uid)) {
                                    _emails.removeWhere((e) => e['id'] == result['id']);
                                  }
                                });
                              } else if (result == 'permanently_deleted' && mounted) {
                                // Handle permanent deletion - remove from list immediately
                                setState(() {
                                  _emails.removeWhere((e) => e['id'] == email['id']);
                                });
                              }
},

                            onStarPressed: (bool newStarState) async {
                              final currentUser = _auth.currentUser;
                              if (currentUser == null) return;

                              final emailId = email['id'] as String?;
                              if (emailId == null) return;                              // Check if this is a draft by looking at the isDraft field or if we're in Drafts view
                              final bool isDraftEmail = email['isDraft'] == true || selectedLabel == "Drafts";                              if (isDraftEmail) {
                                // For drafts, update in the users/{uid}/drafts subcollection
                                try {
                                  await _firestore
                                      .collection('users')
                                      .doc(currentUser.uid)
                                      .collection('drafts')
                                      .doc(emailId)
                                      .update({'starred': newStarState});
                                  
                                  if (mounted) {
                                    setState(() {
                                      email['starred'] = newStarState;
                                      // Nếu đang ở view "Starred" và unstar draft, cần refresh để loại bỏ item
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

                              // For regular emails, update in the emails collection
                              try {
                                List<String> currentLabels = List<String>.from(email['emailLabels']?[currentUser.uid] ?? []);
                                if (newStarState) {
                                  if (!currentLabels.contains('Starred')) {
                                    currentLabels.add('Starred');
                                  }
                                } else {
                                  currentLabels.remove('Starred');
                                }
                                await _firestore.collection('emails').doc(emailId).update({
                                  'emailLabels.${currentUser.uid}': currentLabels,
                                  'starred': newStarState, // Đảm bảo cập nhật trường starred
                                });

                                if (mounted) {
                                  setState(() {
                                    email['starred'] = newStarState;
                                    // Nếu đang ở view "Starred" và unstar, cần refresh để loại bỏ item
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
      ),      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: fabBackgroundColor, // Use conditional background color
        elevation: 2.0,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeEmailScreen()),
          );
          if (result is Map && mounted && (selectedLabel == "Drafts" || selectedLabel == "Starred")) {
            if (result['draftUpdated'] == true || result['draftDeleted'] == true) {
              _fetchEmails();
            }
          }
        },
        icon: Icon(Icons.edit, color: fabForegroundColor), // Use conditional foreground color
        label: Text("Compose", style: TextStyle(color: fabForegroundColor, fontWeight: FontWeight.w500)), // Use conditional foreground color
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}