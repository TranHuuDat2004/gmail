import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/email_list_item.dart';
import 'email_detail_screen.dart';
import 'compose_email_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const SearchScreen({super.key, this.initialSearchQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  bool _hasAttachment = false;
  String? _selectedLabelFilter;

  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _recentSearches = [];
  List<String> _userLabels = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchController.text = widget.initialSearchQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch();
      });
    }
    _loadRecentSearches();
    _loadUserLabels();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty && mounted) {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        _recentSearches = prefs.getStringList('recentSearches_${currentUser.uid}') ?? [];
      });
    }
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await prefs.setStringList('recentSearches_${currentUser.uid}', _recentSearches);
    }
  }

  Future<void> _addRecentSearch(String term) async {
    if (term.isEmpty) return;
    setState(() {
      _recentSearches.remove(term);
      _recentSearches.insert(0, term);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
    });
    await _saveRecentSearches();
  }

  Future<void> _deleteRecentSearch(String term) async {
    setState(() {
      _recentSearches.remove(term);
    });
    await _saveRecentSearches();
  }

  Future<void> _loadUserLabels() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final labelsSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('labels')
          .orderBy('name', descending: false)
          .get();

      if (mounted) {
        final systemLabels = ['Inbox', 'Sent', 'Starred', 'Drafts'];
        final userCreatedLabels = labelsSnapshot.docs
            .map((doc) => doc['name'] as String)
            .toList();
        
        setState(() {
          _userLabels = [...systemLabels, ...userCreatedLabels];
        });
      }
    } catch (e) {
      print("Error loading user labels: $e");
    }
  }

  Future<void> _performSearch() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isNotEmpty) {
      _addRecentSearch(searchTerm);
    }

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isSearching = false;
      });
      return;
    }

    try {
      List<Map<String, dynamic>> results = [];

      final emailsQuery = await _firestore
          .collection('emails')
          .where('involvedUserIds', arrayContains: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .get();

      for (var doc in emailsQuery.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        final isTrashedBy = List<String>.from(data['isTrashedBy'] ?? []);
        final permanentlyDeletedBy = List<String>.from(data['permanentlyDeletedBy'] ?? []);
        if (isTrashedBy.contains(currentUser.uid) || permanentlyDeletedBy.contains(currentUser.uid)) {
          continue;
        }

        bool passesFilters = true;

        if (_selectedDateRange != null && data['timestamp'] is Timestamp) {
          final emailTime = (data['timestamp'] as Timestamp).toDate();
          if (emailTime.isBefore(_selectedDateRange!.start) || 
              emailTime.isAfter(DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59))) {
            passesFilters = false;
          }
        }

        if (_hasAttachment && !(data['hasAttachment'] ?? false)) {
          passesFilters = false;
        }

        if (_selectedLabelFilter != null && _selectedLabelFilter!.isNotEmpty) {
          final labelsMap = data['emailLabels'] as Map<String, dynamic>?;
          final userLabels = labelsMap?[currentUser.uid] as List<dynamic>? ?? [];
          
          if (_selectedLabelFilter == "Drafts") {
            passesFilters = false;
          } else if (_selectedLabelFilter == "Sent") {
            if (!userLabels.contains('Sent') && data['senderId'] != currentUser.uid) {
              passesFilters = false;
            }
          } else if (!userLabels.contains(_selectedLabelFilter)) {
            passesFilters = false;
          }
        }

        if (searchTerm.isNotEmpty) {
          final keyword = searchTerm.toLowerCase();
          final subject = (data['subject'] as String? ?? '').toLowerCase();
          final body = (data['body'] as String? ?? '').toLowerCase();
          final sender = (data['senderDisplayName'] as String? ?? data['senderEmail'] as String? ?? '').toLowerCase();
          
          if (!subject.contains(keyword) && !body.contains(keyword) && !sender.contains(keyword)) {
            passesFilters = false;
          }
        }

        if (passesFilters) {
          data['isUnread'] = !(data['emailIsReadBy']?[currentUser.uid] ?? false);
          data['starred'] = (data['emailLabels']?[currentUser.uid] as List?)?.contains('Starred') ?? false;
          
          String emailLocation = "";
          final labelsMap = data['emailLabels'] as Map<String, dynamic>?;
          if (labelsMap?[currentUser.uid] != null) {
            final userLabels = List<String>.from(labelsMap![currentUser.uid]);
            if (userLabels.contains('Sent')) {
              emailLocation = "Sent";
            } else if (userLabels.contains('Starred')) {
              emailLocation = "Starred";  
            } else if (userLabels.contains('Inbox')) {
              emailLocation = "Inbox";
            } else if (userLabels.isNotEmpty) {
              emailLocation = userLabels.first;
            }
          }
          data['emailLocation'] = emailLocation;
          
          if (data['timestamp'] is Timestamp) {
            final timestamp = data['timestamp'] as Timestamp;
            final dateTime = timestamp.toDate();
            final now = DateTime.now();
            if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
              data['time'] = DateFormat('HH:mm', 'vi_VN').format(dateTime);
            } else {
              data['time'] = DateFormat('d MMM', 'vi_VN').format(dateTime);
            }
          } else {
            data['time'] = '';
          }

          String body = data['body'] as String? ?? '';
          if (body.isNotEmpty) {
            data['preview'] = body.split('\\n').first.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ').trim();
            if (data['preview'].length > 100) {
              data['preview'] = data['preview'].substring(0, 100) + '...';
            }
          } else {
            data['preview'] = '';
          }
          
          results.add(data);
        }
      }

      if (searchTerm.isNotEmpty || _selectedDateRange != null || _hasAttachment || _selectedLabelFilter == "Drafts") {
        try {
          final draftsSnapshot = await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('drafts')
              .get();

          for (var doc in draftsSnapshot.docs) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            data['isDraft'] = true;
            
            bool passesFilters = true;

            if (_selectedDateRange != null && data['timestamp'] is Timestamp) {
              final draftTime = (data['timestamp'] as Timestamp).toDate();
              if (draftTime.isBefore(_selectedDateRange!.start) || 
                  draftTime.isAfter(DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59))) {
                passesFilters = false;
              }
            }

            if (_hasAttachment && !((data['attachmentLocalPaths'] as List?)?.isNotEmpty ?? false)) {
              passesFilters = false;
            }

            if (_selectedLabelFilter != null && _selectedLabelFilter != "Drafts") {
              passesFilters = false;
            }

            if (searchTerm.isNotEmpty) {
              final keyword = searchTerm.toLowerCase();
              final subject = (data['subject'] as String? ?? '').toLowerCase();
              final body = (data['bodyPlainText'] as String? ?? data['body'] as String? ?? '').toLowerCase();
              
              if (!subject.contains(keyword) && !body.contains(keyword)) {
                passesFilters = false;
              }
            }

            if (passesFilters) {
              data['isUnread'] = false;
              data['starred'] = data['starred'] ?? false;
              data['emailLocation'] = "Drafts";
              data['hasAttachment'] = (data['attachmentLocalPaths'] as List?)?.isNotEmpty ?? false;
              
              if (data['timestamp'] is Timestamp) {
                final timestamp = data['timestamp'] as Timestamp;
                final dateTime = timestamp.toDate();
                final now = DateTime.now();
                if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
                  data['time'] = DateFormat('HH:mm', 'vi_VN').format(dateTime);
                } else {
                  data['time'] = DateFormat('d MMM', 'vi_VN').format(dateTime);
                }
              } else {
                data['time'] = '';
              }

              String body = data['bodyPlainText'] as String? ?? data['body'] as String? ?? '';
              if (body.isNotEmpty) {
                data['preview'] = body.split('\\n').first.trim();
                if (data['preview'].length > 100) {
                  data['preview'] = data['preview'].substring(0, 100) + '...';
                }
              } else {
                data['preview'] = '';
              }
              
              results.add(data);
            }
          }
        } catch (e) {
          print("Error searching drafts: $e");
        }
      }

      results.sort((a, b) {
        final aTime = a['timestamp'] is Timestamp ? (a['timestamp'] as Timestamp).toDate() : DateTime(1970);
        final bTime = b['timestamp'] is Timestamp ? (b['timestamp'] as Timestamp).toDate() : DateTime(1970);
        return bTime.compareTo(aTime);
      });

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print("Error performing search: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error performing search: $e')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _showDateFilterDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day);

    Map<String, DateTimeRange?> dateOptions = {
      "Any time": null,
      "Today": DateTimeRange(start: todayStart, end: now),
      "Last 7 days": DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      "Last 30 days": DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now),
    };

    String? selectedOptionKey = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(
            'Select Date Range',
            style: TextStyle(
              color: isDark ? Colors.grey[200] : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          children: dateOptions.keys.map((String key) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, key);
              },
              child: Text(
                key,
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.black87,
                  fontSize: 16,
                ),
              ),
            );
          }).toList(),
        );
      },
    );

    if (selectedOptionKey != null) {
      setState(() {
        _selectedDateRange = dateOptions[selectedOptionKey];
      });
      _performSearch();
    }
  }

  Future<void> _showLabelFilterDialog() async {
    if (_userLabels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có nhãn nào')),
      );
      return;
    }

    final String? selectedLabel = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final bool isDark = theme.brightness == Brightness.dark;
        return SimpleDialog(
          title: Text(
            'Chọn nhãn', 
            style: TextStyle(
              color: isDark ? Colors.grey[200] : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          children: _userLabels.map((label) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, label),
              child: Text(
                label, 
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.black87,
                  fontSize: 16,
                ),
              ),
            );
          }).toList(),
        );
      },
    );

    if (selectedLabel != null) {
      setState(() {
        _selectedLabelFilter = selectedLabel;
      });
      _performSearch();
    }
  }

  Widget _buildFilterChip(String label, {bool selected = false, required String filterKey}) {
    final theme = Theme.of(context);
    VoidCallback? onPressed;
    final bool isDark = theme.brightness == Brightness.dark;

    final Color chipBg = isDark ? const Color(0xFF292929) : Colors.transparent;
    final Color chipSelectedBg = isDark ? const Color(0xFF3c4043) : theme.primaryColor.withOpacity(0.15);
    final Color chipText = isDark ? const Color(0xFFE8EAED) : Colors.black87;
    final Color chipSelectedText = isDark ? Colors.white : theme.primaryColor;
    final BorderSide chipBorder = BorderSide(color: isDark ? const Color(0xFF444746) : Colors.grey[400]!);

    String displayLabel = label;
    switch (filterKey) {
      case "label":
        onPressed = () => _showLabelFilterDialog();
        selected = _selectedLabelFilter != null && _selectedLabelFilter!.isNotEmpty;
        if (selected) displayLabel = _selectedLabelFilter!;
        break;
      case "attachment":
        onPressed = () {
          setState(() {
            _hasAttachment = !_hasAttachment;
          });
          _performSearch();
        };
        selected = _hasAttachment;
        break;
      case "date":
        onPressed = () => _showDateFilterDialog(context);
        selected = _selectedDateRange != null;
        if (selected) {
          final range = _selectedDateRange!;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          if (range.start.isAtSameMomentAs(today)) {
            displayLabel = "Hôm nay";
          } else if (range.start.isAfter(now.subtract(const Duration(days: 7)))) {
            displayLabel = "7 ngày qua";
          } else if (range.start.isAfter(now.subtract(const Duration(days: 30)))) {
            displayLabel = "30 ngày qua";
          } else {
            displayLabel = "Tùy chỉnh";
          }
        }
        break;
      default:
        onPressed = () => print("$label ($filterKey) chip tapped");
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      child: Material(
        color: selected ? chipSelectedBg : chipBg,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: chipBorder.color, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayLabel,
                  style: TextStyle(
                    color: selected ? chipSelectedText : chipText,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    letterSpacing: 0.1,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        switch (filterKey) {
                          case "label":
                            _selectedLabelFilter = null;
                            break;
                          case "attachment":
                            _hasAttachment = false;
                            break;
                          case "date":
                            _selectedDateRange = null;
                            break;
                        }
                      });
                      _performSearch();
                    },
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: selected ? chipSelectedText : chipText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool showRecentSearches = _recentSearches.isNotEmpty && 
        _searchResults.isEmpty && 
        !_isSearching && 
        _searchController.text.isEmpty && 
        _selectedDateRange == null && 
        !_hasAttachment && 
        _selectedLabelFilter == null;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: theme.appBarTheme.elevation ?? 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.brightness == Brightness.dark ? theme.iconTheme.color : Colors.grey[800]),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Tìm trong thư',
            hintStyle: TextStyle(color: theme.hintColor),
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
          style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 18),
          onSubmitted: (_) => _performSearch(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            alignment: Alignment.center,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterChip("Nhãn", filterKey: "label"),
                  _buildFilterChip("Tệp đính kèm", filterKey: "attachment"),
                  _buildFilterChip("Ngày", filterKey: "date"),
                ],
              ),
            ),
          ),

          if (showRecentSearches)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Cụm từ tìm kiếm gần đây trong thư',
                style: theme.textTheme.titleSmall?.copyWith(color: theme.hintColor),
              ),
            ),
          if (showRecentSearches)
            Expanded(
              child: ListView.builder(
                itemCount: _recentSearches.length,
                itemBuilder: (context, index) {
                  final searchTerm = _recentSearches[index];
                  return ListTile(
                    leading: Icon(Icons.history, color: theme.brightness == Brightness.dark ? theme.iconTheme.color : Colors.grey[800]),
                    title: Text(searchTerm, style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                    trailing: IconButton(
                      icon: Icon(Icons.close, color: theme.brightness == Brightness.dark ? theme.iconTheme.color?.withOpacity(0.7) : Colors.grey[800]),
                      tooltip: "Xóa khỏi lịch sử tìm kiếm",
                      onPressed: () => _deleteRecentSearch(searchTerm),
                    ),
                    onTap: () {
                      _searchController.text = searchTerm;
                      _searchController.selection = TextSelection.fromPosition(TextPosition(offset: searchTerm.length));
                      _performSearch();
                    },
                  );
                },
              ),
            ),

          if (_isSearching)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final email = _searchResults[index];
                  return Column(
                    children: [
                      EmailListItem(
                        email: email,
                        isDetailedView: true,
                        isUnread: email['isUnread'] ?? true,
                        isSentView: email['emailLocation'] == 'Sent',
                        isDraft: email['isDraft'] ?? false,
                        currentUserDisplayName: _auth.currentUser?.displayName,
                        currentUserAvatarUrl: null,
                        onTap: () async {
                          final currentUser = _auth.currentUser;
                          if (currentUser != null && (email['isUnread'] ?? true) && email['isDraft'] != true) {
                            try {
                              final emailId = email['id'];
                              if (emailId != null) {
                                await _firestore.collection('emails').doc(emailId).update({
                                  'emailIsReadBy.${currentUser.uid}': true,
                                });
                              }
                            } catch (e) {
                              print("Error marking email as read: $e");
                            }
                          }

                          if (email['isDraft'] == true) {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ComposeEmailScreen(draftToLoad: email),
                              ),
                            );
                            if (result != null && mounted) {
                              _performSearch();
                            }
                          } else {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EmailDetailScreen(
                                  email: email,
                                  isSentView: email['emailLocation'] == 'Sent',
                                ),
                              ),
                            );
                            if (result != null && mounted) {
                              _performSearch();
                            }
                          }
                        },
                        onStarPressed: (bool newStarState) async {
                          final currentUser = _auth.currentUser;
                          if (currentUser == null) return;

                          final emailId = email['id'] as String?;
                          if (emailId == null) return;

                          final bool isDraftEmail = email['isDraft'] == true;

                          if (isDraftEmail) {
                            try {
                              await _firestore
                                  .collection('users')
                                  .doc(currentUser.uid)
                                  .collection('drafts')
                                  .doc(emailId)
                                  .update({'starred': newStarState});

                              setState(() {
                                email['starred'] = newStarState;
                              });
                            } catch (e) {
                              print("Error updating draft star: $e");
                            }
                          } else {
                            try {
                              Map<String, dynamic> updates = {};
                              if (newStarState) {
                                updates['emailLabels.${currentUser.uid}'] = FieldValue.arrayUnion(['Starred']);
                              } else {
                                updates['emailLabels.${currentUser.uid}'] = FieldValue.arrayRemove(['Starred']);
                              }

                              await _firestore.collection('emails').doc(emailId).update(updates);

                              setState(() {
                                email['starred'] = newStarState;
                              });
                            } catch (e) {
                              print("Error updating email star: $e");
                            }
                          }
                        },
                      ),
                      if (email['emailLocation'] != null && email['emailLocation'].isNotEmpty)
                        Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              email['emailLocation'],
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            )
          else if (!_isSearching && !showRecentSearches && (_searchController.text.isNotEmpty || _selectedDateRange != null || _hasAttachment || _selectedLabelFilter != null))
            Expanded(
              child: Center(
                child: Text(
                  'Không tìm thấy email nào phù hợp.',
                  style: TextStyle(color: theme.hintColor, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
