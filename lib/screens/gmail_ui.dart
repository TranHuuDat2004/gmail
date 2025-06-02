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

  final List<String> userLabels = ["Work", "Family"];

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
          data['isUnread'] = true;
          data['starred'] = false;
          data['isDraft'] = true;
          data['subject'] = data['subject'] ?? 'No Subject';
          data['body'] = data['body'] ?? '';
          data['emailLabels'] = {currentUser.uid: ['Drafts']};
          data['emailIsReadBy'] = {currentUser.uid: false};
          data['from'] = currentUser.email;
          data['toRecipients'] = data['toRecipients'] ?? [];
          return data;
        }).toList();
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

        if (selectedLabel == "All inboxes") {
          emailsToDisplay = allUserEmails;
        } else if (selectedLabel == "Starred") {
          emailsToDisplay = allUserEmails.where((email) => email['starred'] == true).toList();
        } else {
          emailsToDisplay = allUserEmails.where((email) {
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
                    backgroundImage: _userPhotoURL != null && _userPhotoURL!.isNotEmpty
                        ? NetworkImage(_userPhotoURL!)
                        : null,
                    child: (_userPhotoURL == null || _userPhotoURL!.isEmpty) &&
                            (_currentUserDisplayName != null && _currentUserDisplayName!.isNotEmpty)
                        ? Text(
                            _currentUserDisplayName![0].toUpperCase(),
                            style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 18), // Use theme color
                          )
                        : null,
                    backgroundColor: (_userPhotoURL == null || _userPhotoURL!.isEmpty)
                        ? theme.colorScheme.primary // Use theme color
                        : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: CustomDrawer(
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
                            onTap: () async {
                              final currentUser = _auth.currentUser;
                              if (currentUser != null && (email['isUnread'] ?? true) && selectedLabel != "Drafts") {
                                try {
                                  await _firestore.collection('emails').doc(email['id']).update({
                                    'emailIsReadBy.${currentUser.uid}': true,
                                  });
                                  if (mounted) {
                                    setState(() {
                                      email['isUnread'] = false;
                                      final emailIndex = _emails.indexWhere((e) => e['id'] == email['id']);
                                      if (emailIndex != -1) {
                                        _emails[emailIndex]['isUnread'] = false;
                                        _emails[emailIndex]['emailIsReadBy'] =
                                            Map<String, dynamic>.from(_emails[emailIndex]['emailIsReadBy'] ?? {})
                                              ..[currentUser.uid] = true;
                                      }
                                    });
                                  }
                                } catch (e) {
                                  print("Error marking email as read: $e");
                                }
                              }
                              // Navigate to EmailDetailScreen and wait for result
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EmailDetailScreen(email: email),
                                ),
                              );
                              // If result indicates the draft was edited, refresh the drafts list
                              if (result == true && selectedLabel == "Drafts" && mounted) {
                                _fetchEmails();
                              }
                            },
                            onStarPressed: (bool newStarState) async {
                              final currentUser = _auth.currentUser;
                              if (currentUser == null) return;

                              final emailId = email['id'] as String?;
                              if (emailId == null) return;

                              if (selectedLabel == "Drafts") return;

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
                                    final emailIndex = _emails.indexWhere((e) => e['id'] == emailId);
                                    if (emailIndex != -1) {
                                      _emails[emailIndex]['starred'] = newStarState;
                                      _emails[emailIndex]['emailLabels'] =
                                          Map<String, dynamic>.from(_emails[emailIndex]['emailLabels'] ?? {})
                                            ..[currentUser.uid] = currentLabels;
                                    }
                                    if (selectedLabel == "Starred") {
                                      _fetchEmails();
                                    }
                                  });
                                }
                              } catch (e) {
                                print("Error updating star status: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error updating star status: $e')),
                                );
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: fabBackgroundColor, // Use conditional background color
        elevation: 2.0,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeEmailScreen()),
          );
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