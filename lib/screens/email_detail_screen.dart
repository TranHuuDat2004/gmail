import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
// Web specific imports - conditional import
import 'dart:html' as html show document, AnchorElement;
// Make sure these paths are correct for your project structure
import '../widgets/action_button.dart';
import 'compose_email_screen.dart';
import 'file_viewer_screen.dart';

class EmailDetailScreen extends StatefulWidget {
  final Map<String, dynamic> email; // email should have 'id', and potentially 'senderId'
  final bool? isSentView; // ADDED: To indicate if this is a sent email view
  const EmailDetailScreen({super.key, required this.email, this.isSentView});

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
  
  // For fetched recipient details (for Sent view)
  String? _fetchedRecipientAvatarUrl;
  bool _isLoadingRecipientDetails = false;

  Map<String, double> _downloadProgress = {}; // Track download progress for each file
  Set<String> _downloadingFiles = {}; // Track which files are being downloaded
  bool _emailDataWasUpdated = false; // Ensure this flag is present

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

    // Fetch recipient avatar if this is a Sent view
    if (widget.isSentView == true) {
      _fetchRecipientAvatarForSentView();
    }

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
                    widget.email['emailIsReadBy'] = {
                      ...widget.email['emailIsReadBy'] ?? {},
                      _currentUser!.uid: true,
                    };
                  });
                }
              })
              .catchError((error) {
                print("Error marking email as read in Firestore: $error");
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

  Future<void> _fetchRecipientAvatarForSentView() async {
    if (!mounted || widget.isSentView != true) return;

    if (mounted) {
      setState(() {
        _isLoadingRecipientDetails = true;
      });
    }

    String? fetchedUrl;
    final List<dynamic>? recipientIds = widget.email['recipientIds'] as List<dynamic>?;

    if (recipientIds != null && recipientIds.isNotEmpty) {
      final String firstRecipientId = recipientIds.first.toString();
      try {
        print("EmailDetailScreen (Sent View): Fetching avatar for recipient ID: $firstRecipientId");
        DocumentSnapshot recipientDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firstRecipientId)
            .get();
        
        if (recipientDoc.exists) {
          final data = recipientDoc.data() as Map<String, dynamic>;
          fetchedUrl = data['avatarUrl'] as String?;
          print("EmailDetailScreen (Sent View): Fetched recipient avatar URL: $fetchedUrl for ID: $firstRecipientId");
        } else {
          print("EmailDetailScreen (Sent View): Recipient document not found for ID: $firstRecipientId");
        }
      } catch (e) {
        print('Error fetching recipient avatar for ID $firstRecipientId: $e');
      }
    } else {
      print("EmailDetailScreen (Sent View): No recipient IDs found in email data.");
    }

    if (mounted) {
      setState(() {
        _fetchedRecipientAvatarUrl = fetchedUrl;
        _isLoadingRecipientDetails = false;
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
          widget.email['emailLabels'] = emailLabelsMap; // Update the local email map
          widget.email['starred'] = newStarStatus;   // CRITICAL: Update 'starred' field in the local email map
        });
        _emailDataWasUpdated = true; // Set the flag
      }
    } catch (e) {
      print("Error updating star status for user $userId on email $emailId: $e");
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật trạng thái sao: $e'),
            backgroundColor: theme.colorScheme.error,
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
          widget.email['emailIsReadBy'] = {
            ...widget.email['emailIsReadBy'] ?? {},
            _currentUser!.uid: newReadStatus,
          };
        });
      }
    } catch (e) {
      print("Error updating read status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật trạng thái đọc: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

Future<void> _deleteEmail() async {
  if (_currentUser == null || widget.email['id'] == null) {
    print("No authenticated user or invalid email ID");
    return;
  }
  final theme = Theme.of(context);

  try {
    final docRef = FirebaseFirestore.instance.collection('emails').doc(widget.email['id']);
    final doc = await docRef.get();
    if (!doc.exists) {
      print("Document does not exist");
      return;
    }
    print("Document data: ${doc.data()}");

    await docRef.update({
      'isTrashedBy': FieldValue.arrayUnion([_currentUser!.uid])
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Email đã được chuyển vào thùng rác'),
          backgroundColor: theme.brightness == Brightness.dark ? Colors.green[700] : Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  } catch (e) {
    print("Error deleting email: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi xóa email: $e'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }
}

  void _assignLabels() {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Gán nhãn (chưa triển khai)'),
        backgroundColor: theme.brightness == Brightness.dark ? Colors.orange[700] : Colors.orange,
      ),
    );
  }
  // File viewing and downloading methods
  Future<void> _viewAttachment(String attachmentUrl, String fileName) async {
    final extension = fileName.split('.').last.toLowerCase();
    
    // Check if file can be viewed directly in app
    if (_canViewInApp(extension)) {
      try {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Navigate to file viewer
        Navigator.pop(context); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FileViewerScreen(
              fileUrl: attachmentUrl,
              fileName: fileName,
              fileExtension: extension,
            ),
          ),
        );
      } catch (e) {
        Navigator.pop(context); // Close loading dialog if still open
        _showErrorSnackBar('Không thể mở file: $e');
      }
    } else {
      // For non-viewable files, download them
      await _downloadAttachment(attachmentUrl, fileName);
    }
  }

  bool _canViewInApp(String extension) {
    const viewableExtensions = [
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
      'txt', 'json', 'xml', 'html', 'css', 'js'
    ];
    return viewableExtensions.contains(extension);
  }  Future<void> _downloadAttachment(String attachmentUrl, String fileName) async {
    try {
      // Start download tracking
      setState(() {
        _downloadingFiles.add(fileName);
        _downloadProgress[fileName] = 0.0;
      });

      // Show immediate feedback
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đang tải xuống "$fileName"...'),
          backgroundColor: theme.brightness == Brightness.dark ? Colors.blue[700] : Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (kIsWeb) {
        // For web platforms - trigger browser download
        await _downloadFileForWeb(attachmentUrl, fileName);
      } else {
        // For mobile platforms - download to device storage
        await _downloadFileForMobile(attachmentUrl, fileName);
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi tải xuống file: $e');
    } finally {
      // Clean up download tracking
      if (mounted) {
        setState(() {
          _downloadingFiles.remove(fileName);
          _downloadProgress.remove(fileName);
        });
      }
    }
  }  Future<void> _downloadFileForWeb(String url, String fileName) async {
    try {
      if (kIsWeb) {
        // For web platforms - use platform-specific download
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          // Update progress during download
          for (int i = 0; i <= 100; i += 25) {
            await Future.delayed(const Duration(milliseconds: 50));
            if (mounted) {
              setState(() {
                _downloadProgress[fileName] = i / 100.0;
              });
            }
          }
          
          // For web, we'll use a data URL to trigger download
          final base64 = base64Encode(response.bodyBytes);
          final dataUrl = 'data:application/octet-stream;base64,$base64';
          
          // Create download element and trigger click
          final anchor = html.document.createElement('a') as html.AnchorElement;
          anchor.href = dataUrl;
          anchor.download = fileName;
          anchor.style.display = 'none';
          html.document.body!.children.add(anchor);
          anchor.click();
          html.document.body!.children.remove(anchor);
          
          // Show success message
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tải xuống "$fileName" thành công!'),
              backgroundColor: theme.brightness == Brightness.dark ? Colors.green[700] : Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          throw Exception('Lỗi tải file từ server (Status: ${response.statusCode})');
        }
      } else {
        // Fallback for non-web platforms
        throw Exception('Web download chỉ hoạt động trên nền tảng web');
      }
    } catch (e) {
      throw Exception('Lỗi web download: $e');
    }
  }

  Future<void> _downloadFileForMobile(String url, String fileName) async {
    try {
      // Request storage permission
      var status = await Permission.storage.request();
      if (status != PermissionStatus.granted) {
        // For Android 11+, try with manageExternalStorage
        status = await Permission.manageExternalStorage.request();
        if (status != PermissionStatus.granted) {
          throw Exception('Cần quyền truy cập bộ nhớ để tải file');
        }
      }

      // Get Downloads directory
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        // Try to use the standard Downloads folder first
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          // Fallback to external storage directory
          downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir != null) {
            downloadsDir = Directory('${downloadsDir.path}/Download');
            if (!await downloadsDir.exists()) {
              await downloadsDir.create(recursive: true);
            }
          }
        }
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Không thể truy cập thư mục tải xuống');
      }

      // Create full file path with unique name if needed
      String savePath = '${downloadsDir.path}/$fileName';
      
      // Ensure unique filename if file already exists
      int counter = 1;
      String originalFileName = fileName;
      String nameWithoutExt = originalFileName.contains('.') 
          ? originalFileName.substring(0, originalFileName.lastIndexOf('.'))
          : originalFileName;
      String extension = originalFileName.contains('.') 
          ? originalFileName.substring(originalFileName.lastIndexOf('.'))
          : '';
      
      while (await File(savePath).exists()) {
        fileName = '${nameWithoutExt}_$counter$extension';
        savePath = '${downloadsDir.path}/$fileName';
        counter++;
      }

      // Download file using Dio with progress tracking
      Dio dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress[originalFileName] = received / total;
            });
          }
        },
      );

      // Show success message
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tải xuống "$fileName" vào thư mục Downloads'),
          backgroundColor: theme.brightness == Brightness.dark ? Colors.green[700] : Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      throw Exception('Lỗi mobile download: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildMetaDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final labelColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final valueColor = isDarkMode ? Colors.grey[200] : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 13, color: labelColor, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 13, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_emailDataWasUpdated) {
          Navigator.pop(context, widget.email); // Return the updated email data
          return false; // Prevent default pop, as we've handled it
        }
        return true; // Allow default pop if no data was changed
      },
      child: _buildEmailDetailScaffold(context), // Original Scaffold UI moved to a new method
    );
  }

  // This new method contains the entire Scaffold and its UI logic from your original build method
  Widget _buildEmailDetailScaffold(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Get email data
    final Map<String, dynamic> email = widget.email;

    // Format timestamp
    String formattedDate = '';
    if (email['timestamp'] != null) {
      DateTime dateTime;
      if (email['timestamp'] is Timestamp) {
        dateTime = (email['timestamp'] as Timestamp).toDate();
      } else if (email['timestamp'] is String) { // Handle case where timestamp might be a String
        dateTime = DateTime.parse(email['timestamp'].toString());
      } else {
        // Fallback or error handling if timestamp is neither Timestamp nor String
        dateTime = DateTime.now(); // Or some other default
      }
      formattedDate = DateFormat('dd/MM/yyyy HH:mm', 'vi_VN').format(dateTime);
    }

    // Get attachments
    final List<dynamic> attachments = email['attachments'] ?? [];

    // Determine display names and recipient info
    final bool isSentEmail = widget.isSentView == true;
    String senderDisplayNameToShow;
    String? senderAvatarUrlToShow;
    String senderInitialToShow;
    String recipientDisplayToShow = '';

    if (isSentEmail) {
      // For sent emails, show recipient info
      final List<dynamic>? toRecipients = email['toRecipients'] as List<dynamic>?;
      // final List<dynamic>? recipientDisplayNames = email['recipientDisplayNames'] as List<dynamic>?; // This was marked as unused by analyzer
      
      if (toRecipients != null && toRecipients.isNotEmpty) {
        final firstRecipient = toRecipients.first;
        if (firstRecipient is Map && firstRecipient['email'] != null) {
          recipientDisplayToShow = firstRecipient['name'] as String? ?? firstRecipient['email'].toString().split('@')[0];
        } else if (firstRecipient is String) {
          recipientDisplayToShow = firstRecipient.contains('@') ? firstRecipient.split('@')[0] : firstRecipient;
        } else {
          recipientDisplayToShow = 'Người nhận không rõ';
        }
        senderDisplayNameToShow = recipientDisplayToShow; // For avatar initial
      } else {
        senderDisplayNameToShow = 'Người nhận không rõ';
        recipientDisplayToShow = senderDisplayNameToShow;
      }
      
      senderAvatarUrlToShow = _fetchedRecipientAvatarUrl; // Assuming this is fetched correctly
      senderInitialToShow = senderDisplayNameToShow.isNotEmpty ? senderDisplayNameToShow[0].toUpperCase() : '?';
    } else {
      // For received emails, show sender info
      if (_isLoadingSenderDetailsForDetail) {
        senderDisplayNameToShow = email['senderDisplayName'] as String? ??
                                  email["senderEmail"] as String? ??
                                  email["from"] as String? ??
                                  'Đang tải...';
      } else {
        senderDisplayNameToShow = _fetchedSenderDisplayNameForDetail ??
                                  email['senderDisplayName'] as String? ??
                                  email["senderEmail"] as String? ??
                                  email["from"] as String? ??
                                  'Không rõ';
      }
      senderAvatarUrlToShow = _fetchedSenderAvatarUrlForDetail ?? email['senderAvatarUrl'] as String?;
      senderInitialToShow = _senderInitialLetterForDetail;
    }

    // Recipients for meta details
    final List<String> toRecipientsList = (email['toRecipients'] as List<dynamic>?)
        ?.map((e) {
          if (e is Map) return e['email']?.toString() ?? e['name']?.toString() ?? e.toString();
          return e.toString();
        })
        .where((s) => s.isNotEmpty)
        .toList() ?? [];
    final List<String> ccRecipientsList = (email['ccRecipients'] as List<dynamic>?)
        ?.map((e) {
          if (e is Map) return e['email']?.toString() ?? e['name']?.toString() ?? e.toString();
          return e.toString();
        })
        .where((s) => s.isNotEmpty)
        .toList() ?? [];


    // Define colors based on theme
    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.grey[50];
    final appBarBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final appBarIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final starColor = Colors.amber;
    final unstarColor = isDarkMode ? Colors.grey[500] : Colors.grey[600];
    final popupMenuIconColor = appBarIconColor;
    final popupMenuBackgroundColor = isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;
    final popupMenuTextColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final subjectColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final avatarBackgroundColor = isDarkMode ? Colors.blue[700] : Colors.blue[700];
    final avatarTextColor = Colors.white;
    final senderNameColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final recipientMetaColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final timeColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final metaDetailBorderColor = isDarkMode ? Colors.grey[700]! : Colors.grey.shade300;
    final dividerColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final bodyTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final attachmentHeaderColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final bottomNavBarBackgroundColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final bottomNavBarBorderColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final actionButtonBackgroundColor = isDarkMode ? const Color(0xFF3C4043) : Colors.blue[700]; // Dark grey background for dark mode
    final actionButtonForegroundColor = isDarkMode ? const Color(0xFF8AB4F8) : Colors.white;    // Light blue text/icon for dark mode

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor,
        elevation: isDarkMode ? 0.5 : 1.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appBarIconColor),
          onPressed: () {
            if (_emailDataWasUpdated) {
              Navigator.pop(context, widget.email);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isStarredLocally ? Icons.star : Icons.star_border,
              color: _isStarredLocally ? starColor : unstarColor,
              size: 20,
            ),
            onPressed: _toggleStarStatus,
            tooltip: _isStarredLocally ? 'Bỏ gắn dấu sao' : 'Gắn dấu sao',
          ),
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Gán nhãn',
            onPressed: _assignLabels,
            color: appBarIconColor,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Chuyển vào Thùng rác',
            onPressed: _deleteEmail,
            color: appBarIconColor,
          ),
          IconButton(
            icon: Icon(_isReadLocally ? Icons.mark_email_unread_outlined : Icons.drafts_outlined),
            tooltip: _isReadLocally ? 'Đánh dấu là chưa đọc' : 'Đánh dấu là đã đọc',
            onPressed: _toggleReadStatus,
            color: appBarIconColor,
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
                    backgroundColor: isDarkMode ? Colors.grey[700] : Colors.black87,
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
                  backgroundColor: (senderAvatarUrlToShow != null && senderAvatarUrlToShow.isNotEmpty)
                      ? Colors.transparent // Transparent if network image is shown
                      : avatarBackgroundColor, // Background color for default asset or initials
                  backgroundImage: (senderAvatarUrlToShow != null && senderAvatarUrlToShow.isNotEmpty)
                      ? NetworkImage(senderAvatarUrlToShow)
                      : const AssetImage('assets/images/default_avatar.png'), // Fallback to default asset
                  child: (senderAvatarUrlToShow == null || senderAvatarUrlToShow.isEmpty)
                      // Show initials if network avatar is not available (displayed on top of default asset image)
                      ? Text(
                          senderInitialToShow,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: avatarTextColor)
                        )
                      : null, // No child if network image is successfully loaded
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
                              isSentEmail ? "đến ${recipientDisplayToShow}" : "từ ${senderDisplayNameToShow}", 
                              style: TextStyle(fontSize: 13, color: recipientMetaColor),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showMetaDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 16,
                              color: recipientMetaColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 13, color: timeColor),
                ),
              ],
            ),
            if (_showMetaDetails)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Container( 
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: metaDetailBorderColor, width: 0.8),
                    color: isDarkMode ? Colors.grey[850] : Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetaDetailRow(context, "From", email['senderEmail'] ?? email['from'] ?? 'Không rõ'),
                      _buildMetaDetailRow(context, "To", toRecipientsList.join(', ')),
                      if (ccRecipientsList.isNotEmpty) _buildMetaDetailRow(context, "Cc", ccRecipientsList.join(', ')),
                      _buildMetaDetailRow(context, "Date", formattedDate),
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
                    Text("Tệp đính kèm (${attachments.length})", 
                         style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: attachmentHeaderColor)),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: attachments.length,
                      itemBuilder: (context, index) {
                        final attachment = attachments[index];
                        String fileName;
                        String? downloadUrl;
                        
                        if (attachment is String) {
                          downloadUrl = attachment;
                          fileName = _extractFileNameFromUrl(attachment);
                        } else if (attachment is Map<String, dynamic>) {
                          fileName = attachment['name'] ?? attachment['fileName'] ?? 'Unknown file';
                          downloadUrl = attachment['downloadUrl'] ?? attachment['url'] ?? attachment.toString();
                        } else {
                          fileName = 'Unknown file';
                          downloadUrl = attachment.toString();
                        }
                        
                        final bool isDownloading = _downloadingFiles.contains(fileName);
                        final double? progress = _downloadProgress[fileName];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                          child: ListTile(
                            leading: Icon(
                              _getFileIcon(fileName),
                              color: isDarkMode ? Colors.blue[300] : Colors.blueAccent,
                            ),
                            title: Text(
                              fileName,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode ? Colors.grey[200] : Colors.black87,
                              ),
                            ),
                            subtitle: attachment is Map<String, dynamic> && attachment['size'] != null 
                                ? Text(
                                    _formatFileSize(attachment['size']),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  )
                                : null,
                            trailing: isDownloading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 2,
                                      color: isDarkMode ? Colors.blue[300] : Colors.blueAccent,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_canViewInApp(fileName.split('.').last.toLowerCase()))
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined),
                                          onPressed: downloadUrl != null
                                              ? () => _viewAttachment(downloadUrl!, fileName)
                                              : null,
                                          tooltip: 'Xem file',
                                          iconSize: 20,
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.download_outlined),
                                        onPressed: downloadUrl != null
                                            ? () => _downloadAttachment(downloadUrl!, fileName)
                                            : null,
                                        tooltip: 'Tải xuống',
                                        iconSize: 20,
                                      ),
                                    ],
                                  ),
                            onTap: downloadUrl != null
                                ? () => _viewAttachment(downloadUrl!, fileName)
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 80), // Space for bottom navigation bar
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            color: bottomNavBarBackgroundColor,
            border: Border(top: BorderSide(color: bottomNavBarBorderColor ?? Colors.transparent, width: 0.5))),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0).copyWith(bottom: MediaQuery.of(context).padding.bottom /2 + 10), // Adjust for safe area
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

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
      case 'wmv':
      case 'webm':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'ogg':
      case 'flac':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }  String _formatFileSize(dynamic size) {
    if (size == null) return 'Unknown size';
    int bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _extractFileNameFromUrl(String url) {
    try {
      // Extract filename from Firebase Storage URL
      final uri = Uri.parse(url);
      String path = uri.path;
      
      // For Firebase Storage URLs, the file name is usually in the path
      if (path.contains('/o/')) {
        // Firebase Storage format: /v0/b/{bucket}/o/{path}
        String encoded = path.split('/o/').last.split('?').first;
        String decoded = Uri.decodeComponent(encoded);
        
        // Extract just the filename part
        if (decoded.contains('/')) {
          return decoded.split('/').last;
        }
        return decoded;
      }
      
      // Fallback: get last segment of path
      return path.split('/').last.split('?').first;
    } catch (e) {
      // If URL parsing fails, return a default name
      return 'attachment_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}