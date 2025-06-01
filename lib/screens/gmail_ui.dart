import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';
import 'search_overlay_screen.dart';
import '../widgets/custom_drawer.dart';
import 'email_detail_screen.dart';
import 'compose_email_screen.dart';
import '../widgets/email_list_item.dart';

class GmailUI extends StatefulWidget {
  final User? user; // THÊM TRƯỜNG USER

  GmailUI({super.key, this.user}); // CẬP NHẬT CONSTRUCTOR

  @override
  State<GmailUI> createState() => _GmailUIState();
}

class _GmailUIState extends State<GmailUI> {
  bool showDetail = false;
  String selectedLabel = "Inbox";
  bool isDetailedView = true;
  String? _userPhotoURL;
  String? _currentUserDisplayName; // ADDED: For default avatar
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Added

  List<Map<String, dynamic>> _emails = []; // To store fetched emails
  bool _isLoadingEmails = true; // To show a loading indicator

  final List<String> userLabels = ["Work", "Family"]; // This should probably be fetched or managed elsewhere

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAvatar();
    _fetchEmails(); // Fetch emails on init
  }

  Future<void> _fetchEmails() async {
    if (!mounted) return;
    setState(() {
      _isLoadingEmails = true;
    });

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      // Ensure mounted check here too for safety, though setState already checks.
      if (mounted) { 
        setState(() {
          _emails = [];
          _isLoadingEmails = false;
        });
      }
      return;
    }

    try {
      Query query = _firestore.collection('emails');

      // Filter by 'involvedUserIds' containing the current user's ID
      query = query.where('involvedUserIds', arrayContains: currentUser.uid);
      
      // REMOVE additional server-side filters for labels like 'selectedLabel', 'Sent', 'Starred'
      // These will be handled by client-side filtering after fetching all emails for the user.

      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();
      
      final allUserEmails = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Store document ID for later use (e.g., updates)
        
        // Determine if the email is unread for the current user
        final emailIsReadBy = data['emailIsReadBy'] as Map<String, dynamic>?;
        bool isUnread = true; // Default to unread
        if (emailIsReadBy != null && emailIsReadBy[currentUser.uid] == true) {
          isUnread = false;
        }
        data['isUnread'] = isUnread; // Add 'isUnread' to the email map

        // Determine if the email is starred by the current user
        final emailLabelsMap = data['emailLabels'] as Map<String, dynamic>?;
        bool isStarred = false;
        if (emailLabelsMap != null && 
            emailLabelsMap[currentUser.uid] is List &&
            (emailLabelsMap[currentUser.uid] as List).contains('Starred')) {
            isStarred = true;
        }
        data['starred'] = isStarred;


        return data;
      }).toList();

      List<Map<String, dynamic>> emailsToDisplay;

      if (selectedLabel == "All inboxes") {
        emailsToDisplay = allUserEmails;
      } else if (selectedLabel == "Starred") {
        // Filter for starred emails on the client side
        emailsToDisplay = allUserEmails.where((email) => email['starred'] == true).toList();
      } else {
        // Handles "Inbox", "Sent", "Drafts", "Trash", "Spam", and custom labels by client-side filtering
        emailsToDisplay = allUserEmails.where((email) {
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
          _emails = emailsToDisplay; // Use the client-side filtered list
          _isLoadingEmails = false;
        });
      }
    } catch (e) {
      print("Error fetching emails: $e");
      if (mounted) {
        setState(() {
          _isLoadingEmails = false;
          _emails = []; // Clear emails on error
        });
        // Wrap ScaffoldMessenger call
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) { // Check mounted again inside the callback
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error fetching emails: $e')),
            );
          }
        });
      }
    }
  }

  Future<void> _loadCurrentUserAvatar({bool forceRefresh = false}) async { // ADDED: forceRefresh parameter
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _userPhotoURL = null;
          _currentUserDisplayName = null; // ADDED
        });
      }
      return;
    }

    // If not forcing refresh, and avatar already loaded, do nothing.
    if (!forceRefresh && _userPhotoURL != null && _userPhotoURL!.isNotEmpty) {
        // return; 
    }

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (mounted && userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        final String? firestoreAvatarUrl = data['avatarUrl'];
        final String? displayName = data['displayName'] ?? data['name']; // ADDED: Get display name

        // Update display name
        if (forceRefresh || _currentUserDisplayName != displayName) {
          setState(() {
            _currentUserDisplayName = displayName;
          });
        }

        if (firestoreAvatarUrl != null && firestoreAvatarUrl.trim().isNotEmpty) {
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
         if (mounted) { // Simpler condition
          setState(() {
            _userPhotoURL = null;
            _currentUserDisplayName = null; // ADDED
          });
        }
      }
    } catch (e) {
      // print('Error loading user avatar from Firestore: $e');
      if (mounted) { // Simpler condition
        setState(() {
          _userPhotoURL = null;
          _currentUserDisplayName = null; // ADDED
        });
      }
    }
  }

  // Callback for updating labels from LabelManagementScreen
  void _updateUserLabels(List<String> updatedLabels) {
    setState(() {
      userLabels.clear();
      userLabels.addAll(updatedLabels);
      // userLabels.sort(); // Optional: sort labels
    });
  }

  // REMOVE STATIC emails list or comment it out, as we are fetching from Firestore
  // final List<Map<String, dynamic>> emails = [ ... ];

  @override
  Widget build(BuildContext context) {
    // Use _emails fetched from Firestore
    // final filteredEmails = selectedLabel == "All inboxes"
    //     ? _emails // Use fetched emails
    //     : _emails.where((e) {
    //         // This client-side filtering might be redundant if Firestore query is comprehensive
    //         // or can be adjusted based on what Firestore query handles
    //         final labelsForUser = e['emailLabels']?[_auth.currentUser?.uid] as List<dynamic>?;
    //         if (labelsForUser != null) {
    //           return labelsForUser.contains(selectedLabel);
    //         }
    //         return false;
    //       }).toList();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: 70,
        title: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8, left: 12, right: 12), // Thụt lề trái/phải
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black54),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
              Expanded(
                child: TextField(
                  readOnly: true,
                  cursorColor: Colors.black,
                  decoration: const InputDecoration(
                    hintText: "Search in mail",
                    hintStyle: TextStyle(color: Colors.black38),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: const TextStyle(color: Colors.black87),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SearchOverlayScreen()),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () async { // MODIFIED: Make onTap async
                    final bool? avatarChanged = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                    // If avatarChanged is true, reload the avatar
                    if (avatarChanged == true && mounted) {
                      _loadCurrentUserAvatar(forceRefresh: true); // CALL with forceRefresh
                    }
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: _userPhotoURL != null && _userPhotoURL!.isNotEmpty
                        ? NetworkImage(_userPhotoURL!)
                        : null, // Set to null if no photo URL
                    child: (_userPhotoURL == null || _userPhotoURL!.isEmpty) && 
                           (_currentUserDisplayName != null && _currentUserDisplayName!.isNotEmpty)
                        ? Text(
                            _currentUserDisplayName![0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          )
                        : null, // No text if photo URL exists or display name is null/empty
                    backgroundColor: (_userPhotoURL == null || _userPhotoURL!.isEmpty) 
                        ? Colors.blue[700] // Default blue background
                        : Colors.transparent, // Transparent if photo is shown
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
            _fetchEmails(); // Re-fetch emails when label changes
          });
          Navigator.pop(context);
        },
        userLabels: userLabels,
        emails: _emails, // Pass fetched emails
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
                  style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                ),
                IconButton(
                  icon: Icon(
                    isDetailedView ? Icons.view_list_outlined : Icons.view_comfortable_outlined,
                    color: Colors.black54,
                    size: 22, // Slightly increased size for better visibility
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
                        itemCount: _emails.length, // Use length of fetched emails
                        itemBuilder: (context, index) {
                          final email = _emails[index];
                          // bool isUnread = email["isUnread"] ?? true; // Already calculated in _fetchEmails
                          
                          return EmailListItem(
                            email: email,
                            isDetailedView: isDetailedView,
                            isUnread: email['isUnread'] ?? true, // Use pre-calculated value
                            isSentView: selectedLabel == "Sent", // ADDED THIS LINE
                            onTap: () async { // Make onTap async
                              final currentUser = _auth.currentUser;
                              if (currentUser != null && (email['isUnread'] ?? true)) {
                                try {
                                  await _firestore.collection('emails').doc(email['id']).update({
                                    'emailIsReadBy.${currentUser.uid}': true,
                                  });
                                  if (mounted) {
                                    setState(() {
                                      email['isUnread'] = false; // Update local state
                                      // Optionally, re-fetch or update the specific item in _emails list
                                      final emailIndex = _emails.indexWhere((e) => e['id'] == email['id']);
                                      if (emailIndex != -1) {
                                        _emails[emailIndex]['isUnread'] = false;
                                        // Also update the main map for consistency if needed elsewhere
                                        _emails[emailIndex]['emailIsReadBy'] = 
                                          Map<String, dynamic>.from(_emails[emailIndex]['emailIsReadBy'] ?? {})
                                          ..[currentUser.uid] = true;
                                      }
                                    });
                                  }
                                } catch (e) {
                                  print("Error marking email as read: $e");
                                  // Optionally show a snackbar
                                }
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EmailDetailScreen(email: email),
                                ),
                              );
                            },
                            onStarPressed: (bool newStarState) async { // Make onStarPressed async
                              final currentUser = _auth.currentUser;
                              if (currentUser == null) return;

                              final emailId = email['id'] as String?;
                              if (emailId == null) return;

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
                                });

                                if (mounted) {
                                  setState(() {
                                    email['starred'] = newStarState;
                                    // Update local _emails list for immediate UI feedback
                                     final emailIndex = _emails.indexWhere((e) => e['id'] == emailId);
                                      if (emailIndex != -1) {
                                        _emails[emailIndex]['starred'] = newStarState;
                                        _emails[emailIndex]['emailLabels'] = 
                                          Map<String, dynamic>.from(_emails[emailIndex]['emailLabels'] ?? {})
                                          ..[currentUser.uid] = currentLabels;
                                      }
                                    // If current view is "Starred", re-fetch to apply filter
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
        backgroundColor: Colors.white,
        elevation: 2.0,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeEmailScreen()),
          );
        },
        icon: const Icon(Icons.edit, color: Colors.redAccent),
        label: const Text("Compose", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
