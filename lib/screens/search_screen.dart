import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import '../widgets/email_list_item.dart';
import 'email_detail_screen.dart'; // Import EmailDetailScreen

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  bool _hasAttachment = false;
  String? _selectedLabelFilter;
  String? _selectedSender;
  String? _selectedRecipient;

  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _recentSearches = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty && mounted) {
        setState(() {
          // When search text is cleared, reset search results to show recent searches again
          // _searchResults = []; // Optionally clear results or handle differently
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
    } else {
      setState(() {
        _recentSearches = []; // No user, no recent searches
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
      _recentSearches.remove(term); // Remove if already exists to move to top
      _recentSearches.insert(0, term);
      if (_recentSearches.length > 10) { // Limit to 10 recent searches
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

  Future<void> _performSearch() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isNotEmpty) {
      _addRecentSearch(searchTerm);
    }

    if (searchTerm.isEmpty &&
        _selectedDateRange == null &&
        !_hasAttachment &&
        _selectedLabelFilter == null &&
        _selectedSender == null &&
        _selectedRecipient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search term or select a filter.')),
      );
      return;
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
      Query query = _firestore.collection('emails').where('involvedUserIds', arrayContains: currentUser.uid);

      if (_selectedDateRange != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: _selectedDateRange!.start);
        // Adjust end date to include the whole day
        query = query.where('timestamp', isLessThanOrEqualTo: DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59));
      }

      if (_hasAttachment) {
        query = query.where('hasAttachment', isEqualTo: true);
      }

      if (_selectedLabelFilter != null && _selectedLabelFilter!.isNotEmpty) {
        // Assuming labels are stored in a map like: {'userId': ['label1', 'label2']}
        // Or if it's a direct array field for all users: query = query.where('emailLabels', arrayContains: _selectedLabelFilter);
        query = query.where('emailLabels.${currentUser.uid}', arrayContains: _selectedLabelFilter);
      }
      if (_selectedSender != null && _selectedSender!.isNotEmpty) {
        // This requires an exact match. For partial, you'd need client-side filtering or a more advanced backend search.
        query = query.where('senderEmail', isEqualTo: _selectedSender);
      }
      if (_selectedRecipient != null && _selectedRecipient!.isNotEmpty) {
        query = query.where('recipientEmails', arrayContains: _selectedRecipient);
      }


      query = query.orderBy('timestamp', descending: true);

      final snapshot = await query.get();
      List<Map<String, dynamic>> results = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['isUnread'] = data['isUnread'] ?? !(data['emailIsReadBy']?[currentUser.uid] ?? false);
        data['starred'] = data['starred'] ?? (data['emailLabels']?[currentUser.uid] as List?)?.contains('Starred') ?? false;
        
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
        return data;
      }).toList();

      if (searchTerm.isNotEmpty) {
        final keyword = searchTerm.toLowerCase();
        results = results.where((email) {
          final subject = (email['subject'] as String? ?? '').toLowerCase();
          final preview = (email['preview'] as String? ?? '').toLowerCase();
          final sender = (email['senderDisplayName'] as String? ?? email['senderEmail'] as String? ?? '').toLowerCase();
          // Add more fields to search if needed, e.g., recipients
          return subject.contains(keyword) || preview.contains(keyword) || sender.contains(keyword);
        }).toList();
      }

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
    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day);

    Map<String, DateTimeRange?> dateOptions = {
      "Any time": null,
      "Today": DateTimeRange(start: todayStart, end: now),
      "Last 7 days": DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      "Last 30 days": DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now),
      // Đã bỏ 'Custom range...'
    };

    String? selectedOptionKey = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(
            'Select Date Range',
            style: TextStyle(
              color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.black87,
            ),
          ),
          backgroundColor: theme.dialogBackgroundColor,
          children: dateOptions.keys.map((String key) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, key);
              },
              child: Text(key, style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
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
  
  Future<void> _showFilterInputDialog(BuildContext context, String title, String currentValue, Function(String) onSave) async {
    final TextEditingController dialogController = TextEditingController(text: currentValue);
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF292929) : theme.dialogBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(title, style: TextStyle(color: isDark ? const Color(0xFFE8EAED) : theme.textTheme.titleLarge?.color, fontWeight: FontWeight.w600)),
          content: TextField(
            controller: dialogController,
            style: TextStyle(color: isDark ? const Color(0xFFE8EAED) : theme.textTheme.bodyMedium?.color),
            decoration: InputDecoration(
              hintText: "Enter $title",
              hintStyle: TextStyle(color: isDark ? Colors.grey[500] : theme.hintColor),
              filled: true,
              fillColor: isDark ? const Color(0xFF232323) : Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFFE8EAED) : theme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF3c4043) : theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                elevation: 0,
              ),
              child: const Text("Save", style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () {
                onSave(dialogController.text);
                Navigator.of(context).pop();
                _performSearch();
              },
            ),
          ],
        );
      },
    );
  }


  Widget _buildFilterChip(String label, {bool selected = false, required String filterKey}) {
    final theme = Theme.of(context);
    VoidCallback? onPressed;
    final bool isDark = theme.brightness == Brightness.dark;
    // Gmail dark theme colors
    final Color chipBg = isDark ? const Color(0xFF292929) : Colors.transparent;
    final Color chipSelectedBg = isDark ? const Color(0xFF3c4043) : theme.primaryColor.withOpacity(0.15);
    final Color chipText = isDark ? const Color(0xFFE8EAED) : Colors.black87;
    final Color chipSelectedText = isDark ? Colors.white : theme.primaryColor;
    final BorderSide chipBorder = BorderSide(color: isDark ? const Color(0xFF444746) : Colors.grey[400]!);

    switch (filterKey) {
      case "label":
        onPressed = () => _showFilterInputDialog(context, "Label", _selectedLabelFilter ?? "", (value) => setState(() => _selectedLabelFilter = value));
        selected = _selectedLabelFilter != null && _selectedLabelFilter!.isNotEmpty;
        break;
      case "from":
        onPressed = () => _showFilterInputDialog(context, "From (Sender Email)", _selectedSender ?? "", (value) => setState(() => _selectedSender = value));
        selected = _selectedSender != null && _selectedSender!.isNotEmpty;
        break;
      case "to":
        onPressed = () => _showFilterInputDialog(context, "To (Recipient Email)", _selectedRecipient ?? "", (value) => setState(() => _selectedRecipient = value));
        selected = _selectedRecipient != null && _selectedRecipient!.isNotEmpty;
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
        break;
      default:
        onPressed = () => print("$label ($filterKey) chip tapped - placeholder");
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
            child: Text(
              label,
              style: TextStyle(
                color: selected ? chipSelectedText : chipText,
                fontWeight: FontWeight.w500,
                fontSize: 16,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool showRecentSearches = _recentSearches.isNotEmpty && _searchResults.isEmpty && !_isSearching && _searchController.text.isEmpty && _selectedDateRange == null && !_hasAttachment && _selectedLabelFilter == null && _selectedSender == null && _selectedRecipient == null;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: theme.appBarTheme.elevation ?? 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
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
          onChanged: (text) {
            if (text.isEmpty && !_isSearching && _searchResults.isNotEmpty) {
              // If search bar cleared and we have results, user might want to see recent searches again
              // or we just clear the results. For now, let it be.
              // setState(() { _searchResults = []; });
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.mic_none, color: theme.iconTheme.color),
            onPressed: () { /* TODO: Implement voice search */ },
            tooltip: 'Search by voice',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            alignment: Alignment.center, // Center the row of chips
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8.0), // Padding for the scroll view
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterChip("Nhãn", filterKey: "label"),
                  _buildFilterChip("Từ", filterKey: "from"),
                  _buildFilterChip("Đến", filterKey: "to"),
                  _buildFilterChip("Tệp đính kèm", filterKey: "attachment"),
                  _buildFilterChip("Date", filterKey: "date"),
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
                    leading: Icon(Icons.history, color: theme.iconTheme.color),
                    title: Text(searchTerm, style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                    trailing: IconButton(
                      icon: Icon(Icons.close, color: theme.iconTheme.color?.withOpacity(0.7)),
                      tooltip: "Remove from recent searches",
                      onPressed: () => _deleteRecentSearch(searchTerm),
                    ),
                    onTap: () {
                      _searchController.text = searchTerm;
                      _searchController.selection = TextSelection.fromPosition(TextPosition(offset: searchTerm.length)); // Move cursor to end
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
                  return EmailListItem(
                    email: email,
                    isDetailedView: true, // Or make this configurable
                    isUnread: email['isUnread'] ?? true,
                    isSentView: false, // Search results are not typically a "Sent" view
                    onTap: () async {
                      final currentUser = _auth.currentUser;
                      if (currentUser != null && (email['isUnread'] ?? true)) {
                        try {
                          await _firestore.collection('emails').doc(email['id']).update({
                            'emailIsReadBy.${currentUser.uid}': true,
                          });
                          if (mounted) {
                            setState(() {
                              final emailIndex = _searchResults.indexWhere((e) => e['id'] == email['id']);
                              if (emailIndex != -1) {
                                _searchResults[emailIndex]['isUnread'] = false;
                                var emailIsReadBy = Map<String, dynamic>.from(_searchResults[emailIndex]['emailIsReadBy'] ?? {});
                                emailIsReadBy[currentUser.uid] = true;
                                _searchResults[emailIndex]['emailIsReadBy'] = emailIsReadBy;
                              }
                            });
                          }
                        } catch (e) {
                          print("Error marking email as read from search: $e");
                          // Optionally show a SnackBar
                        }
                      }
                      // Navigate to EmailDetailScreen
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmailDetailScreen(email: email),
                          ),
                        );
                      }
                    },
                    onStarPressed: (bool newStarState) async {
                      final currentUser = _auth.currentUser;
                      if (currentUser == null) return;

                      final emailId = email['id'] as String?;
                      if (emailId == null) return; // Corrected: Added parentheses

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
                          'starred': newStarState, 
                        });

                        if (mounted) {
                          setState(() {
                            final emailIndex = _searchResults.indexWhere((e) => e['id'] == emailId);
                            if (emailIndex != -1) {
                              _searchResults[emailIndex]['starred'] = newStarState;
                              var emailLabelsData = Map<String, dynamic>.from(_searchResults[emailIndex]['emailLabels'] ?? {});
                              emailLabelsData[currentUser.uid] = currentLabels;
                              _searchResults[emailIndex]['emailLabels'] = emailLabelsData;
                            }
                          });
                        }
                      } catch (e) {
                        print("Error updating star status from search: $e");
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
            )
          else if (!_isSearching && !showRecentSearches && (_searchController.text.isNotEmpty || _selectedDateRange != null || _hasAttachment || _selectedLabelFilter != null || _selectedSender != null || _selectedRecipient != null))
             Expanded(
                child: Center(
                  child: Text(
                    'No emails found for your criteria.',
                    style: TextStyle(color: theme.hintColor, fontSize: 16),
                  ),
                ),
              )
        ],
      ),
    );
  }
}
