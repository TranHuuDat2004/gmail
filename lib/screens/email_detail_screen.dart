import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:typed_data';

// AI Feature Imports
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart' as mlkit_translation;

// Conditional import for web download functionality
import '../utils/web_download_utils_stub.dart'
    if (dart.library.html) '../utils/web_download_utils.dart'
    as web_download_utils;

// Conditional import for web PDF viewer
import '../utils/web_pdf_utils_stub.dart'
    if (dart.library.html) '../utils/web_pdf_utils_web.dart'
    as web_pdf_utils;

// Conditional import for web translation
import '../utils/web_translation_utils_stub.dart' 
    if (dart.library.html) '../utils/web_translation_utils_web.dart' 
    as web_translation_utils;

// Make sure these paths are correct for your project structure
import '../widgets/action_button.dart';
import 'compose_email_screen.dart';
import 'file_viewer_screen.dart';

class EmailDetailScreen extends StatefulWidget {
  final Map<String, dynamic> email; 
  final bool? isSentView;
  final Function(String, String, bool)? toggleSpamStatus;

  const EmailDetailScreen({
    super.key, 
    required this.email, 
    this.isSentView,
    this.toggleSpamStatus,
  });

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  bool _showMetaDetails = false;
  late bool _isStarredLocally;
  late bool _isReadLocally;
  User? _currentUser;
  String? _fetchedSenderDisplayNameForDetail;
  String? _fetchedSenderAvatarUrlForDetail;
  bool _isLoadingSenderDetailsForDetail = true;
  String? _fetchedRecipientAvatarUrl;

  Map<String, double> _downloadProgress = {}; 
  Set<String> _downloadingFiles = {}; 
  bool _emailDataWasUpdated = false; 

  // AI Feature: Language Detection & Translation State Variables
  String _identifiedLanguage = "Đang xác định ngôn ngữ...";
  String? _translatedText;
  bool _isTranslating = false;
  bool _isModelDownloading = false;
  bool _languageIdentificationAttempted = false; 

  late final LanguageIdentifier _languageIdentifier;
  mlkit_translation.OnDeviceTranslator? _onDeviceTranslator;
  mlkit_translation.TranslateLanguage? _sourceLanguage = mlkit_translation.TranslateLanguage.english; 
  final mlkit_translation.TranslateLanguage _targetLanguage = mlkit_translation.TranslateLanguage.vietnamese;


  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;

    if (_currentUser != null) {
      Map<String, dynamic>? emailLabelsMap;
      if (widget.email['emailLabels'] != null) {
        try {
          emailLabelsMap = Map<String, dynamic>.from(widget.email['emailLabels']);
        } catch (e) {
          print("Error casting emailLabels: $e. Value: ${widget.email['emailLabels']}");
          emailLabelsMap = null; 
        }
      }
      final userSpecificLabels = emailLabelsMap?[_currentUser!.uid] as List<dynamic>?;
      _isStarredLocally = userSpecificLabels?.contains('Starred') ?? false;

      Map<String, dynamic>? emailIsReadByMap;
      if (widget.email['emailIsReadBy'] != null) {
        try {
          emailIsReadByMap = Map<String, dynamic>.from(widget.email['emailIsReadBy']);
        } catch (e) {
          print("Error casting emailIsReadBy: $e. Value: ${widget.email['emailIsReadBy']}");
          emailIsReadByMap = null; 
        }
      }
      _isReadLocally = emailIsReadByMap?[_currentUser!.uid] as bool? ?? false;
    } else {
      _isStarredLocally = false;
      _isReadLocally = false;
    }

    if (!kIsWeb) {
      _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
    } else {
      _identifiedLanguage = "Đang xác định ngôn ngữ (web)...";
      _languageIdentificationAttempted = false; 
    }

    _fetchSenderDetailsForDetailScreen();

    if (widget.isSentView == true) {
      _fetchRecipientAvatarForSentView();
    }

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
                    // Update local email data 
                    widget.email['emailIsReadBy'] = {
                      ...widget.email['emailIsReadBy'] ?? {},
                      _currentUser!.uid: true,
                    };
                  });
                }
              })              .catchError((error) {
                print("Error marking email as read in Firestore: $error");
                return null;
              });
          _emailDataWasUpdated = true;
        }
      });
    }
  }
  Future<void> _fetchSenderDetailsForDetailScreen() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSenderDetailsForDetail = true;
    });

    if (widget.isSentView == true && _currentUser != null) {
        try {
            DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
            if (mounted && userDoc.exists) {
                final data = userDoc.data() as Map<String, dynamic>;
                _fetchedSenderDisplayNameForDetail = data['displayName'] as String? ?? _currentUser!.displayName ?? _currentUser!.email ?? "Bạn";
                _fetchedSenderAvatarUrlForDetail = data['avatarUrl'] as String? ?? _currentUser!.photoURL;
            } else {
                _fetchedSenderDisplayNameForDetail = _currentUser!.displayName ?? _currentUser!.email ?? "Bạn";
                _fetchedSenderAvatarUrlForDetail = _currentUser!.photoURL;
            }
        } catch (e) {
            print("Error fetching current user details for Sent view in DetailScreen: $e");
            _fetchedSenderDisplayNameForDetail = _currentUser!.displayName ?? _currentUser!.email ?? "Bạn";
            _fetchedSenderAvatarUrlForDetail = _currentUser!.photoURL;
        }
         if (mounted) {
            setState(() {
                _isLoadingSenderDetailsForDetail = false;
            });
        }
        return; 
    }


    String? senderId = widget.email['senderId'] as String?;
    String? senderEmail = widget.email['senderEmail'] as String? ?? widget.email['from'] as String?;
    String fallbackDisplayName = widget.email['senderDisplayName'] as String? ??
                                 senderEmail ??'Không rõ';

    if (senderId != null && senderId.isNotEmpty) {
      try {
        DocumentSnapshot senderDoc = await FirebaseFirestore.instance.collection('users').doc(senderId).get();
        if (mounted && senderDoc.exists) {
          final data = senderDoc.data() as Map<String, dynamic>;
          _fetchedSenderDisplayNameForDetail = data['displayName'] as String? ?? data['name'] as String? ?? fallbackDisplayName;
          _fetchedSenderAvatarUrlForDetail = data['avatarUrl'] as String?;
        } else { 
          _fetchedSenderDisplayNameForDetail = fallbackDisplayName;
          _fetchedSenderAvatarUrlForDetail = null;
        }
      } catch (e) {
        print('Error fetching sender details by ID for EmailDetailScreen: $e');
        _fetchedSenderDisplayNameForDetail = fallbackDisplayName;
        _fetchedSenderAvatarUrlForDetail = null;
      }
    } else if (senderEmail != null && senderEmail.isNotEmpty) { 
      try {
        QuerySnapshot senderQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: senderEmail)
            .limit(1)
            .get();
        if (mounted && senderQuery.docs.isNotEmpty) {
          final senderDoc = senderQuery.docs.first;
          final data = senderDoc.data() as Map<String, dynamic>;
          _fetchedSenderDisplayNameForDetail = data['displayName'] as String? ?? data['name'] as String? ?? fallbackDisplayName;
          _fetchedSenderAvatarUrlForDetail = data['avatarUrl'] as String?;
        } else { 
          _fetchedSenderDisplayNameForDetail = fallbackDisplayName;
          _fetchedSenderAvatarUrlForDetail = null;
        }
      } catch (e) {
        print('Error fetching sender details by email for EmailDetailScreen: $e');
        _fetchedSenderDisplayNameForDetail = fallbackDisplayName;
        _fetchedSenderAvatarUrlForDetail = null;
      }
    } else { 
      _fetchedSenderDisplayNameForDetail = fallbackDisplayName;
      _fetchedSenderAvatarUrlForDetail = null;
    }

    if (mounted) {
      setState(() {
        _isLoadingSenderDetailsForDetail = false;
      });
    }
  }  Future<void> _fetchRecipientAvatarForSentView() async {
    if (!mounted || widget.isSentView != true) return;

    String? fetchedUrl;
    final List<dynamic>? toRecipients = widget.email['toRecipients'] as List<dynamic>?;

    if (toRecipients != null && toRecipients.isNotEmpty) {
      final String firstRecipientEmail = toRecipients.first.toString();
      try {
        print("EmailDetailScreen (Sent View): Fetching avatar for recipient email: $firstRecipientEmail");
        QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: firstRecipientEmail)
            .limit(1)
            .get();
        
        if (userQuery.docs.isNotEmpty) {
          final data = userQuery.docs.first.data() as Map<String, dynamic>;
          fetchedUrl = data['avatarUrl'] as String?;
        } else {
          print("EmailDetailScreen (Sent View): Recipient not found for email: $firstRecipientEmail");
        }
      } catch (e) {
        print('Error fetching recipient avatar for email $firstRecipientEmail: $e');
      }
    } else {
      print("EmailDetailScreen (Sent View): No recipient emails found in email data.");
    }

    if (mounted) {
      setState(() {
        _fetchedRecipientAvatarUrl = fetchedUrl;
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
          widget.email['starred'] = newStarStatus;   
        });
        _emailDataWasUpdated = true; 
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
    final theme = Theme.of(context); 

    try {
      await FirebaseFirestore.instance
          .collection('emails')
          .doc(widget.email['id'])
          .update({'emailIsReadBy.${_currentUser!.uid}': newReadStatus});

if (mounted) {
  setState(() {
    _isReadLocally = newReadStatus;
    Map<String, dynamic> currentEmailIsReadBy = {};
    if (widget.email['emailIsReadBy'] != null) {
      try {
        currentEmailIsReadBy = Map<String, dynamic>.from(widget.email['emailIsReadBy']);
      } catch (e) {
        print("Warning: Could not cast widget.email['emailIsReadBy'] to Map<String, dynamic>");
      }
    }
    widget.email['emailIsReadBy'] = {
      ...currentEmailIsReadBy, 
      _currentUser!.uid: newReadStatus,
    };
    _emailDataWasUpdated = true; 
  });
}
// 
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
  final docRef = FirebaseFirestore.instance.collection('emails').doc(widget.email['id']);
  final bool isInTrash = (widget.email['isTrashedBy'] as List<dynamic>?)?.contains(_currentUser!.uid) ?? false;

  try {
    if (isInTrash) {
      await docRef.update({
        'permanentlyDeletedBy': FieldValue.arrayUnion([_currentUser!.uid]),
        'isTrashedBy': FieldValue.arrayRemove([_currentUser!.uid]) 
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email đã được bạn đánh dấu xóa vĩnh viễn.'),
            backgroundColor: theme.brightness == Brightness.dark ? Colors.green[700] : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        List<dynamic> permanentlyDeletedByList = List<dynamic>.from(widget.email['permanentlyDeletedBy'] ?? []);
        if (!permanentlyDeletedByList.contains(_currentUser!.uid)) {
          permanentlyDeletedByList.add(_currentUser!.uid);
        }
        widget.email['permanentlyDeletedBy'] = permanentlyDeletedByList;

        List<dynamic> isTrashedByList = List<dynamic>.from(widget.email['isTrashedBy'] ?? []);
        isTrashedByList.removeWhere((id) => id == _currentUser!.uid);
        widget.email['isTrashedBy'] = isTrashedByList;
        
        _emailDataWasUpdated = true;
        Navigator.pop(context, widget.email); 
      }
    } else {
      await docRef.update({
        'isTrashedBy': FieldValue.arrayUnion([_currentUser!.uid])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email đã được chuyển vào Thùng rác'),
            backgroundColor: theme.brightness == Brightness.dark ? Colors.green[700] : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        List<dynamic> isTrashedByList = List<dynamic>.from(widget.email['isTrashedBy'] ?? []);
        if (!isTrashedByList.contains(_currentUser!.uid)) {
          isTrashedByList.add(_currentUser!.uid);
        }
        widget.email['isTrashedBy'] = isTrashedByList;
        _emailDataWasUpdated = true;
        Navigator.pop(context, widget.email);
      }
    }
  } catch (e) {
    print("Error in _deleteEmail: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xử lý email: $e'),
          backgroundColor: theme.brightness == Brightness.dark ? Colors.red[700] : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

  void _assignLabels() async {
    if (_currentUser == null || widget.email['id'] == null) return;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final userId = _currentUser!.uid;
    final emailId = widget.email['id'];
    final emailRef = FirebaseFirestore.instance.collection('emails').doc(emailId);

    final labelsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('labels')
        .orderBy('name')
        .get();
    final List<String> allLabels = labelsSnapshot.docs.map((doc) => doc['name'] as String).toList();

    Map<String, dynamic> emailLabelsMap = Map<String, dynamic>.from(widget.email['emailLabels'] ?? {});
    List<String> currentLabels = List<String>.from(emailLabelsMap[userId] ?? []);
    List<String> selectedLabels = List<String>.from(currentLabels);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, dialogSetState) {
            final dialogTheme = Theme.of(context);
            final isDialogDark = dialogTheme.brightness == Brightness.dark;
            final dialogBackgroundColor = isDialogDark ? const Color(0xFF2C2C2C) : Colors.white;
            final dialogTitleColor = isDialogDark ? Colors.grey[200] : Colors.black87;
            final dialogLabelColor = isDialogDark ? Colors.grey[300] : Colors.black87;
            final dialogCheckColor = isDialogDark ? Colors.blue[300] : Colors.blue[700];
            final dialogDividerColor = isDialogDark ? Colors.grey[700]! : Colors.grey[300]!;
            final dialogButtonBg = isDialogDark ? Colors.blue[600] : Colors.blue[700];
            final dialogButtonFg = Colors.white;
            final dialogCancelColor = isDialogDark ? Colors.grey[400] : Colors.grey[700];

            return AlertDialog(
              backgroundColor: dialogBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Gán nhãn cho thư', style: TextStyle(color: dialogTitleColor, fontWeight: FontWeight.bold)),
              contentPadding: const EdgeInsets.only(top: 12.0),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.add, color: dialogCheckColor),
                      title: Text('Tạo nhãn mới', style: TextStyle(color: dialogCheckColor, fontWeight: FontWeight.w500)),
                      onTap: () async {
                        final newLabelName = await _promptForNewLabel();
                        if (newLabelName != null && newLabelName.isNotEmpty) {
                          dialogSetState(() {
                            if (!allLabels.contains(newLabelName)) {
                              allLabels.add(newLabelName);
                              allLabels.sort();
                            }
                            if (!selectedLabels.contains(newLabelName)) {
                              selectedLabels.add(newLabelName);
                            }
                          });
                        }
                      },
                    ),
                    Divider(height: 1, color: dialogDividerColor),
                    Flexible(
                      child: allLabels.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                'Chưa có nhãn nào. Hãy tạo nhãn mới.',
                                textAlign: TextAlign.center,
                                  style: TextStyle(color: isDialogDark ? Colors.grey.shade600 : Colors.grey.shade500),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: allLabels.length,
                              itemBuilder: (context, idx) {
                                final label = allLabels[idx];
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    checkboxTheme: CheckboxThemeData(
                                      side: MaterialStateBorderSide.resolveWith((states) {
                                        if (isDialogDark) {
                                          return BorderSide(color: Colors.grey.shade400, width: 1.5);
                                        }
                                        return BorderSide(color: Colors.grey.shade600, width: 1.5);
                                      }),
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: selectedLabels.contains(label),
                                    title: Text(label, style: TextStyle(color: dialogLabelColor)),
                                    activeColor: dialogCheckColor,
                                    checkColor: Colors.white,
                                    onChanged: (checked) {
                                      dialogSetState(() {
                                        if (checked == true) {
                                          if (!selectedLabels.contains(label)) selectedLabels.add(label);
                                        } else {
                                          selectedLabels.remove(label);
                                        }
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: const EdgeInsets.only(left: 16, right: 16),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Hủy'),
                  style: TextButton.styleFrom(foregroundColor: dialogCancelColor),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, List<String>.from(selectedLabels)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dialogButtonBg,
                    foregroundColor: dialogButtonFg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      emailLabelsMap[userId] = result;
      await emailRef.update({'emailLabels': emailLabelsMap});
      if (mounted) {
        setState(() {
          widget.email['emailLabels'] = emailLabelsMap;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã gán nhãn thành công!'),
          backgroundColor: isDarkMode ? Colors.green[700] : Colors.green,
        ),
      );
      _emailDataWasUpdated = true;
    }
  }

    Future<String?> _promptForNewLabel() async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final newLabelController = TextEditingController();
    
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text('Tạo nhãn mới', style: TextStyle(color: isDarkMode ? Colors.grey[200] : Colors.black87)),
        content: TextField(
          controller: newLabelController,
          autofocus: true,
          maxLength: 50,
          decoration: InputDecoration(
            hintText: 'Nhập tên nhãn...',
            counterStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? Colors.blue[600] : Colors.blue[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onPressed: () async {
              final newLabelName = newLabelController.text.trim();
              if (newLabelName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tên nhãn không được để trống.')));
                return;
              }
              if (newLabelName.contains('/')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tên nhãn không được chứa ký tự '/'.")));
                return;
              }

              final existingLabelQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .collection('labels')
                  .where('name', isEqualTo: newLabelName)
                  .limit(1)
                  .get();

              if (existingLabelQuery.docs.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nhãn "$newLabelName" đã tồn tại.')));
                return;
              }

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .collection('labels')
                  .add({'name': newLabelName, 'createdAt': FieldValue.serverTimestamp()});
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã tạo nhãn "$newLabelName".')));
                Navigator.pop(context, newLabelName);
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }  // File viewing and downloading methods
  Future<void> _viewPdfAttachment(String attachmentUrl, String fileName) async {
    final theme = Theme.of(context); // Get theme for SnackBar & Dialog
    final isDarkMode = theme.brightness == Brightness.dark;
    final extension = fileName.split('.').last.toLowerCase();

    if (extension == 'pdf') {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
        if (kIsWeb) {
          // For web - fetch PDF data and show in WebPdfViewerScreen
          final response = await Dio().get(
            attachmentUrl,
            options: Options(responseType: ResponseType.bytes),
          );

          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => web_pdf_utils.createWebPdfViewer(
                  Uint8List.fromList(response.data),
                  fileName,
                ),
              ),
            );
          }
        } else {
          // For mobile - use SfPdfViewer.network
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    title: Text(fileName),
                    backgroundColor: isDarkMode ? const Color(0xFF202124) : Colors.white,
                    iconTheme: IconThemeData(color: isDarkMode ? Colors.grey[400] : Colors.black54),
                  ),
                  body: SfPdfViewer.network(attachmentUrl),
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog if still open
          _showErrorSnackBar('Không thể mở file PDF: $e');
        }
      }
    } else {
      // For non-PDF files, fallback to download or other viewers
      await _viewAttachment(attachmentUrl, fileName); // Call general view for other types
    }
  }

  Future<void> _viewAttachment(String attachmentUrl, String fileName) async {
    final extension = fileName.split('.').last.toLowerCase();

    // Check if it's PDF first
    if (extension == 'pdf') {
      await _viewPdfAttachment(attachmentUrl, fileName);
      return;
    }

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
        // Call the conditionally imported function
        await web_download_utils.actualDownloadFileForWeb(
          url,
          fileName,
          context, // Pass context
          (double progress) { // Pass progress callback
            if (mounted) {
              setState(() {
                _downloadProgress[fileName] = progress;
              });
            }
          },
        );
      } else {
        // Fallback for non-web platforms
        throw Exception('Web download chỉ hoạt động trên nền tảng web');
      }
    } catch (e) {
      _showErrorSnackBar('Lỗi web download: $e');
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Check if email is in trash for current user only
    final bool isInTrash = widget.email['isTrashedBy']?.contains(_currentUser?.uid) == true;

    // Get email content for display
    String emailBodyToDisplay;
    bool hasRichContent;
    bool isBodyPlaceholder = false; // Flag for body placeholder

    final rawSubject = widget.email['subject'] as String? ?? '';
    final bool isSubjectEmpty = rawSubject.trim().isEmpty;
    final String displaySubject = isSubjectEmpty ? '(Không có tiêu đề)' : rawSubject;

    if (widget.email['bodyDeltaJson'] != null) {
      try {
        final deltaJson = jsonDecode(widget.email['bodyDeltaJson'] as String);
        final quillDocument = quill.Document.fromJson(deltaJson);
        emailBodyToDisplay = quillDocument.toPlainText().trim();
        if (emailBodyToDisplay.isEmpty) {
          emailBodyToDisplay = '(Không có nội dung)';
          isBodyPlaceholder = true;
          hasRichContent = false; // Treat placeholder as not rich for simple display
        } else {
          hasRichContent = true;
        }
      } catch (e) {
        print("Error parsing rich content: $e");
        String plainBody = widget.email['body'] as String? ?? '';
        emailBodyToDisplay = plainBody.trim();
        if (emailBodyToDisplay.isEmpty) {
          emailBodyToDisplay = '(Không có nội dung)';
          isBodyPlaceholder = true;
        }
        hasRichContent = false;
      }
    } else {
      String plainBody = widget.email['body'] as String? ?? widget.email['bodyPlainText'] as String? ?? '';
      emailBodyToDisplay = plainBody.trim();
      if (emailBodyToDisplay.isEmpty) {
        emailBodyToDisplay = '(Không có nội dung)';
        isBodyPlaceholder = true;
      }
      hasRichContent = false;
    }

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
    // String senderInitialToShow;
    String recipientDisplayToShow = '';

    if (isSentEmail) {
      // For sent emails, show recipient info
      final List<dynamic>? toRecipients = email['toRecipients'] as List<dynamic>?;      
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
      
      senderAvatarUrlToShow = _fetchedRecipientAvatarUrl; 
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
    final List<String> bccRecipientsList = (email['bccRecipients'] as List<dynamic>?)
        ?.map((e) => e.toString()) 
        .where((s) => s.isNotEmpty)
        .toList() ?? [];
    // Define colors based on theme
    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.grey[50];
    final appBarBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final appBarIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final starColor = Colors.amber;
    final unstarColor = isDarkMode ? Colors.grey[500] : Colors.grey[600];
    final subjectColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final senderNameColor = isDarkMode ? Colors.grey[200] : Colors.black87;
    final recipientMetaColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final timeColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final metaDetailBorderColor = isDarkMode ? Colors.grey[700]! : Colors.grey.shade300;
    final dividerColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final attachmentHeaderColor = isDarkMode ? Colors.grey[300] : Colors.black87;    final bottomNavBarBackgroundColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final bottomNavBarBorderColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];
    final actionButtonBackgroundColor = isDarkMode ? const Color(0xFF3C4043) : Colors.blue[700]; 
    final actionButtonForegroundColor = isDarkMode ? const Color(0xFF8AB4F8) : Colors.white; 

    final Color translateButtonIconColor = isDarkMode ? actionButtonForegroundColor : Colors.white; 

    if (!_languageIdentificationAttempted && emailBodyToDisplay.isNotEmpty && emailBodyToDisplay != '(Không có nội dung)') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _identifyLanguage(emailBodyToDisplay); 
        }
      });
    }

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor,
        elevation: isDarkMode ? 0.5 : 1.0,        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appBarIconColor),
          onPressed: () {
            Navigator.pop(context, _emailDataWasUpdated ? widget.email : null);
          },
        ),        actions: [
          if (!isInTrash) ...[
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
              icon: Icon(
                _isSpamEmail() ? Icons.report : Icons.report_outlined,
                color: _isSpamEmail() ? Colors.red : appBarIconColor,
              ),
              tooltip: _isSpamEmail() ? 'Bỏ khỏi thư rác' : 'Đánh dấu thư rác',
              onPressed: _toggleSpamLabel,
            ),
            IconButton(
              icon: const Icon(Icons.label_outline),
              tooltip: 'Gán nhãn',
              onPressed: _assignLabels,
              color: appBarIconColor,
            ),
          ],
          if (isInTrash) ...[
            IconButton(
              icon: const Icon(Icons.restore_from_trash_outlined),
              tooltip: 'Khôi phục',
              onPressed: _restoreFromTrash,
              color: appBarIconColor,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: isInTrash ? 'Xóa vĩnh viễn' : 'Chuyển vào Thùng rác',
            onPressed: _deleteEmail,
            color: appBarIconColor,
          ),
          if (!isInTrash) ...[
            IconButton(
              icon: Icon(_isReadLocally ? Icons.mark_email_unread_outlined : Icons.drafts_outlined),
              tooltip: _isReadLocally ? 'Đánh dấu là chưa đọc' : 'Đánh dấu là đã đọc',
              onPressed: _toggleReadStatus,
              color: appBarIconColor,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      displaySubject 
                      ,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: subjectColor,
                        fontStyle: isSubjectEmpty ? FontStyle.italic : FontStyle.normal, // Italic for placeholder
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: (senderAvatarUrlToShow != null && senderAvatarUrlToShow.isNotEmpty)
                      ? NetworkImage(senderAvatarUrlToShow)
                      : const AssetImage('assets/images/default_avatar.png'),
                  child: null, 
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
                      if (_currentUser?.uid == widget.email['senderId'] && bccRecipientsList.isNotEmpty)
                        _buildMetaDetailRow(context, "Bcc", bccRecipientsList.join(', ')),
                      _buildMetaDetailRow(context, "Date", formattedDate),
                    ],
                  ),
                ),
              ),
            Divider(height: 32, color: dividerColor),
            // Email body section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0),
              child: (hasRichContent && !isBodyPlaceholder && widget.email['bodyDeltaJson'] != null)
                  ? _buildRichEmailContent(widget.email['bodyDeltaJson'] as String, isDarkMode)
                  : SelectableText(
                      emailBodyToDisplay,
                      style: TextStyle(
                        fontSize: 16,
                        color: isBodyPlaceholder
                            ? (isDarkMode ? Colors.grey[500] : Colors.grey[600]) // Lighter color for placeholder
                            : (isDarkMode ? Colors.grey[200] : Colors.black87),
                        height: 1.5,
                        fontStyle: isBodyPlaceholder ? FontStyle.italic : FontStyle.normal, // Italic for placeholder
                      ),
                    ),
            ),

            // AI Features UI
            // Updated condition to show AI features on web as well
            if (_languageIdentificationAttempted && !isBodyPlaceholder)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _identifiedLanguage, // This will show "Đang xác định (web)..." or the result
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                    if (_sourceLanguage != null && // Ensures identification was successful enough to set a source language
                        _sourceLanguage != _targetLanguage &&
                        !_isTranslating &&
                        !_isModelDownloading) // _isModelDownloading is for MLKit, but good to keep
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.translate, size: 18, color: translateButtonIconColor),
                          label: Text(
                            _translatedText == null
                                ? 'Dịch sang ${_getLanguageDisplayName(_targetLanguage)}'
                                : (_translatedText!.startsWith("Lỗi") || _translatedText!.startsWith("Ngoại lệ") || _translatedText!.startsWith("Dịch thuật yêu cầu") ? 'Thử dịch lại' : 'Xem bản gốc'), // Toggle to show original
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: () {
                            if (emailBodyToDisplay.isNotEmpty && emailBodyToDisplay != '(Không có nội dung)') {
                              if (_translatedText != null && !(_translatedText!.startsWith("Lỗi") || _translatedText!.startsWith("Ngoại lệ")|| _translatedText!.startsWith("Dịch thuật yêu cầu"))) {
                                setState(() {
                                  _translatedText = null;
                                });
                              } else {
                                // Otherwise, perform translation
                                _translateText(emailBodyToDisplay);
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Không có nội dung để dịch.")),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode ? Colors.blueGrey[700] : Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    if (_isTranslating) 
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: isDarkMode ? Colors.blueGrey[300] : Colors.blue[700])),
                            SizedBox(width: 8),
                            Text( kIsWeb ? "Đang dịch (web)..." : "Đang dịch...", style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700])),
                          ],
                        ),
                      ),
                    if (_translatedText != null && !_isTranslating) 
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _translatedText!.startsWith("Lỗi") || _translatedText!.startsWith("Ngoại lệ") || _translatedText!.startsWith("Dịch thuật yêu cầu") ? "Thông báo:" : "Bản dịch sang ${_getLanguageDisplayName(_targetLanguage)}:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.grey[300] : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              _translatedText!,
                              style: TextStyle(
                                fontSize: 16,
                                color: (_translatedText!.startsWith("Lỗi") || _translatedText!.startsWith("Ngoại lệ") || _translatedText!.startsWith("Dịch thuật yêu cầu"))
                                    ? (isDarkMode ? Colors.red[300] : Colors.red[700])
                                    : (isDarkMode ? Colors.grey[200] : Colors.black87),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
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
                label: "Trả lời",                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ComposeEmailScreen(
                        replyOrForwardEmail: widget.email,
                        composeMode: 'reply',
                        isReply: true,
                        originalEmail: widget.email,
                      ),
                    ),
                  );
                },
                buttonBackgroundColor: actionButtonBackgroundColor,
                buttonForegroundColor: actionButtonForegroundColor,
              ),
            ),            const SizedBox(width: 10),
            if (_shouldShowReplyAll()) ...[
              Expanded(
                child: ActionButton(
                  icon: Icons.reply_all_outlined,
                  label: "Trả lời tất cả",                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ComposeEmailScreen(
                          replyOrForwardEmail: widget.email,
                          composeMode: 'replyAll',
                          isReplyAll: true,
                          originalEmail: widget.email,
                        ),
                      ),
                    );
                  },
                  buttonBackgroundColor: actionButtonBackgroundColor,
                  buttonForegroundColor: actionButtonForegroundColor,
                ),
              ),
              const SizedBox(width: 10),
            ],
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

  Widget _buildRichEmailContent(String deltaJsonString, bool isDarkMode) {
    try {
      final deltaJson = jsonDecode(deltaJsonString);
      final quillDocument = quill.Document.fromJson(deltaJson);
      final quillController = quill.QuillController(
        document: quillDocument,
        selection: const TextSelection.collapsed(offset: 0),
      );

      return Container(
        constraints: const BoxConstraints(
          minHeight: 100,
        ),
        child: quill.QuillEditor.basic(
          configurations: quill.QuillEditorConfigurations(
            controller: quillController,
            autoFocus: false,
            showCursor: false,
            enableInteractiveSelection: true,
            padding: EdgeInsets.zero,
            customStyles: quill.DefaultStyles(
              paragraph: quill.DefaultTextBlockStyle(
                TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey[200] : Colors.black87,
                  height: 1.5,
                ),
                const quill.VerticalSpacing(0, 8),
                const quill.VerticalSpacing(0, 0),
                null,
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      print("Error rendering rich content: $e");
      return SelectableText(
        "Error loading rich content",
        style: TextStyle(
          fontSize: 16,
          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      );
    }
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
  }  bool _shouldShowReplyAll() {
    if (widget.isSentView == true) return false;
    
    final List<String> toRecipients = (widget.email['toRecipients'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList() ?? [];
        
    final List<String> ccRecipients = (widget.email['ccRecipients'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList() ?? [];
    
    final int totalRecipients = toRecipients.length + ccRecipients.length;
    
    return totalRecipients > 1;
  }  Future<void> _restoreFromTrash() async {
    if (_currentUser == null || widget.email['id'] == null) {
      return;
    }
    final theme = Theme.of(context);

    try {
      final docRef = FirebaseFirestore.instance.collection('emails').doc(widget.email['id']);
      
      await docRef.update({
        'isTrashedBy': FieldValue.arrayRemove([_currentUser!.uid])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email đã được khôi phục'),
            backgroundColor: theme.brightness == Brightness.dark ? Colors.green[700] : Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Update local email data and go back
        widget.email['isTrashedBy'] = (widget.email['isTrashedBy'] as List<dynamic>? ?? [])
            .where((id) => id != _currentUser!.uid).toList();
        _emailDataWasUpdated = true;
        Navigator.pop(context, widget.email);
      }
    } catch (e) {
      print("Error restoring email: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khôi phục email: $e'),
            backgroundColor: theme.brightness == Brightness.dark ? Colors.red[700] : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _isSpamEmail() {
    if (_currentUser == null) return false;
    final emailLabelsMap = widget.email['emailLabels'] as Map<String, dynamic>?;
    if (emailLabelsMap != null && emailLabelsMap[_currentUser!.uid] is List) {
      final userLabels = List<String>.from(emailLabelsMap[_currentUser!.uid] as List);
      return userLabels.contains('Spam');
    }
    return false;
  }

  Future<void> _toggleSpamLabel() async {
    if (_currentUser == null || widget.email['id'] == null) return;
    
    final isCurrentlySpam = _isSpamEmail();
    
    try {
      if (widget.toggleSpamStatus != null) {
        await widget.toggleSpamStatus!(
          widget.email['id'], 
          _currentUser!.uid, 
          !isCurrentlySpam
        );
        
        if (mounted) {
          setState(() {
            final emailLabelsMap = widget.email['emailLabels'] as Map<String, dynamic>? ?? {};
            final userLabels = List<String>.from(emailLabelsMap[_currentUser!.uid] ?? []);
            
            if (!isCurrentlySpam) {
              if (!userLabels.contains('Spam')) {
                userLabels.add('Spam');
              }
              userLabels.remove('Inbox');
            } else {
              userLabels.remove('Spam');
              if (!userLabels.contains('Inbox')) {
                userLabels.add('Inbox');
              }
            }
            
            emailLabelsMap[_currentUser!.uid] = userLabels;
            widget.email['emailLabels'] = emailLabelsMap;
            _emailDataWasUpdated = true;
          });
        }
      }
    } catch (e) {
      print('Error toggling spam status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating spam status: $e')),
        );
      }
    }
  }
  @override
  void dispose() {
    if (!kIsWeb) {
      _languageIdentifier.close();
      _onDeviceTranslator?.close();
    }
    super.dispose();
  }

  // Helper function to get BCP-47 code from TranslateLanguage
String _getBcp47Code(mlkit_translation.TranslateLanguage? lang) { 
  if (lang == null) return 'und'; 

  final Map<mlkit_translation.TranslateLanguage, String> bcp47Map = {
    mlkit_translation.TranslateLanguage.afrikaans: 'af', mlkit_translation.TranslateLanguage.albanian: 'sq', mlkit_translation.TranslateLanguage.arabic: 'ar',
    mlkit_translation.TranslateLanguage.belarusian: 'be', mlkit_translation.TranslateLanguage.bengali: 'bn', mlkit_translation.TranslateLanguage.bulgarian: 'bg',
    mlkit_translation.TranslateLanguage.catalan: 'ca', mlkit_translation.TranslateLanguage.chinese: 'zh', mlkit_translation.TranslateLanguage.croatian: 'hr',
    mlkit_translation.TranslateLanguage.czech: 'cs', mlkit_translation.TranslateLanguage.danish: 'da', mlkit_translation.TranslateLanguage.dutch: 'nl',
    mlkit_translation.TranslateLanguage.english: 'en', mlkit_translation.TranslateLanguage.esperanto: 'eo', mlkit_translation.TranslateLanguage.estonian: 'et',
    mlkit_translation.TranslateLanguage.finnish: 'fi', mlkit_translation.TranslateLanguage.french: 'fr', mlkit_translation.TranslateLanguage.galician: 'gl',
    mlkit_translation.TranslateLanguage.georgian: 'ka', mlkit_translation.TranslateLanguage.german: 'de', mlkit_translation.TranslateLanguage.greek: 'el',
    mlkit_translation.TranslateLanguage.gujarati: 'gu',
    mlkit_translation.TranslateLanguage.hebrew: 'he', // BCP-47 is 'he', not 'iw' for modern use
    mlkit_translation.TranslateLanguage.hindi: 'hi', mlkit_translation.TranslateLanguage.hungarian: 'hu', mlkit_translation.TranslateLanguage.icelandic: 'is',
    mlkit_translation.TranslateLanguage.indonesian: 'id', mlkit_translation.TranslateLanguage.irish: 'ga', mlkit_translation.TranslateLanguage.italian: 'it',
    mlkit_translation.TranslateLanguage.japanese: 'ja', mlkit_translation.TranslateLanguage.kannada: 'kn', mlkit_translation.TranslateLanguage.korean: 'ko',
    mlkit_translation.TranslateLanguage.latvian: 'lv', mlkit_translation.TranslateLanguage.lithuanian: 'lt', mlkit_translation.TranslateLanguage.macedonian: 'mk',
    mlkit_translation.TranslateLanguage.malay: 'ms', mlkit_translation.TranslateLanguage.maltese: 'mt', mlkit_translation.TranslateLanguage.marathi: 'mr',
    mlkit_translation.TranslateLanguage.norwegian: 'no', mlkit_translation.TranslateLanguage.persian: 'fa', mlkit_translation.TranslateLanguage.polish: 'pl',
    mlkit_translation.TranslateLanguage.portuguese: 'pt', mlkit_translation.TranslateLanguage.romanian: 'ro', mlkit_translation.TranslateLanguage.russian: 'ru',
    mlkit_translation.TranslateLanguage.slovak: 'sk', mlkit_translation.TranslateLanguage.slovenian: 'sl', mlkit_translation.TranslateLanguage.spanish: 'es',
    mlkit_translation.TranslateLanguage.swahili: 'sw', mlkit_translation.TranslateLanguage.swedish: 'sv', mlkit_translation.TranslateLanguage.tagalog: 'tl',
    mlkit_translation.TranslateLanguage.tamil: 'ta', mlkit_translation.TranslateLanguage.telugu: 'te', mlkit_translation.TranslateLanguage.thai: 'th',
    mlkit_translation.TranslateLanguage.turkish: 'tr', mlkit_translation.TranslateLanguage.ukrainian: 'uk', mlkit_translation.TranslateLanguage.urdu: 'ur',
    mlkit_translation.TranslateLanguage.vietnamese: 'vi', mlkit_translation.TranslateLanguage.welsh: 'cy',
  };
  return bcp47Map[lang] ?? 'und'; 
}

  // Helper function to get a displayable name for TranslateLanguage
  String _getLanguageDisplayName(mlkit_translation.TranslateLanguage? lang) { 
    if (lang == null) return 'Không xác định'; 

    final bcp47 = _getBcp47Code(lang);
    switch (bcp47) {
      case 'en': return 'English';
      case 'vi': return 'Tiếng Việt';
     
      case 'zh': return 'Chinese';
      case 'es': return 'Spanish';
      case 'fr': return 'French';
      case 'de': return 'German';
      case 'ja': return 'Japanese';
      case 'ko': return 'Korean';
      // Add more mappings as needed
      default:
        String name = lang.name;
        if (name.isNotEmpty) return name[0].toUpperCase() + name.substring(1).toLowerCase(); 
        return bcp47;
    }
  }
  
  // Helper function to get TranslateLanguage from BCP-47 code
  mlkit_translation.TranslateLanguage? _getTranslateLanguageFromBcp47(String bcp47Code) { 
    final String lowerCode = bcp47Code.toLowerCase();
    if (lowerCode == 'und') return null; 

    for (final langEnum in mlkit_translation.TranslateLanguage.values) {
      if (_getBcp47Code(langEnum) == lowerCode) {
        return langEnum;
      }
    }
    return null; 
  }

  // AI Feature Methods
  Future<void> _identifyLanguage(String textToIdentify) async {
    if (textToIdentify.isEmpty || textToIdentify == '(Không có nội dung)') {
      if (mounted) {
        setState(() {
          _identifiedLanguage = "Không có nội dung để xác định.";
          _languageIdentificationAttempted = true;
        });
      }
      return;
    }

    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _identifiedLanguage = "Đang xác định ngôn ngữ (web)... ";
        _translatedText = null;
      });
      try {
        final String languageCode = await web_translation_utils.identifyLanguageJS(textToIdentify);
        if (!mounted) return;

        if (languageCode.startsWith('und_') || languageCode.isEmpty) {
            setState(() {
                _identifiedLanguage = "Lỗi xác định ngôn ngữ (web): ${languageCode.isEmpty ? 'empty_code' : languageCode}";
                _languageIdentificationAttempted = true;
                _sourceLanguage = null; 
            });
            return;
        }
        _sourceLanguage = _getTranslateLanguageFromBcp47(languageCode); 

        setState(() {
          if (_sourceLanguage == null) { 
            _identifiedLanguage = "Ngôn ngữ không xác định (web): ($languageCode)";
          } else {
            _identifiedLanguage = "Ngôn ngữ gốc: ${_getLanguageDisplayName(_sourceLanguage)} ($languageCode)";
          }
          _languageIdentificationAttempted = true;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _identifiedLanguage = "Lỗi xác định ngôn ngữ (web API).";
          _languageIdentificationAttempted = true;
          _sourceLanguage = null; 
        });
        print("Error identifying language via Cloud API: $e");
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _identifiedLanguage = "Đang xác định ngôn ngữ...";
      _translatedText = null;
    });

    try {
      final String languageCode = await _languageIdentifier.identifyLanguage(textToIdentify);
      if (!mounted) return;

      mlkit_translation.TranslateLanguage? identifiedSourceLang; 
      String displayLangCode = languageCode;

      if (languageCode == "und") {
        displayLangCode = "Không xác định";
        identifiedSourceLang = null; 
      } else {
        identifiedSourceLang = _getTranslateLanguageFromBcp47(languageCode); 
      }
      
      if (mounted) {
        setState(() {
          _sourceLanguage = identifiedSourceLang;
          if (_sourceLanguage == null) { 
             _identifiedLanguage = "Ngôn ngữ gốc: Không xác định ($displayLangCode)";
          } else {
             _identifiedLanguage = "Ngôn ngữ gốc: ${_getLanguageDisplayName(_sourceLanguage)} ($displayLangCode)";
          }
          _languageIdentificationAttempted = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _identifiedLanguage = "Lỗi xác định ngôn ngữ.";
        _languageIdentificationAttempted = true;
        _sourceLanguage = null; 
      });
      print("Error identifying language with ML Kit: $e");
    }
  }

  Future<void> _downloadModel(mlkit_translation.OnDeviceTranslatorModelManager modelManager, mlkit_translation.TranslateLanguage language, String languageNameForSnackBar) async { 
    if (kIsWeb) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tính năng tải model không khả dụng trên web.'))
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() { _isModelDownloading = true; });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đang tải model ngôn ngữ: $languageNameForSnackBar...'))
    );
    final String bcp47Code = _getBcp47Code(language);
    try {
      final bool result = await modelManager.downloadModel(bcp47Code, isWifiRequired: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result ? 'Đã tải xong model: $languageNameForSnackBar' : 'Không thể tải model: $languageNameForSnackBar'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải model $languageNameForSnackBar: $e'))
        );
      }
      print("Error downloading model $bcp47Code: $e");
    } finally {
      if (mounted) {
        setState(() { _isModelDownloading = false; });
      }
    }
  }

  Future<void> _translateText(String textToTranslate) async {
    if (kIsWeb) {
      if (!mounted) return;

      final String currentSourceBcp47 = _getBcp47Code(_sourceLanguage); // Handles null _sourceLanguage
      if (_identifiedLanguage.contains("Lỗi") ||
          _identifiedLanguage.contains("Không có") ||
          _identifiedLanguage.contains("Đang xác định") ||
          _sourceLanguage == null || 
          currentSourceBcp47 == 'und') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không thể dịch do chưa xác định rõ ngôn ngữ gốc (web).")),
        );
        return;
      }

      final String targetBcp47 = _getBcp47Code(_targetLanguage);

      if (currentSourceBcp47 == targetBcp47) {
        setState(() {
          _translatedText = "Nội dung đã ở ngôn ngữ đích (web).";
        });
        return;
      }
      if (textToTranslate.isEmpty || textToTranslate == '(Không có nội dung)') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không có nội dung để dịch (web).")),
        );
        return;
      }

      setState(() {
        _isTranslating = true;
        _translatedText = "Đang dịch (web)...";
      });
      try {
        final String result = await web_translation_utils.translateTextJS(textToTranslate, currentSourceBcp47, targetBcp47);
        if (!mounted) return;
        setState(() {
          _translatedText = result; // Display result or error message from API
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _translatedText = "Lỗi dịch thuật (web API).";
        });
        print("Error translating text via Cloud API: $e");
      } finally {
        if (mounted) {
          setState(() {
            _isTranslating = false;
          });
        }
      }
      return;
    }

    // Non-web (ML Kit) logic
    if (!mounted) return;
    setState(() {
      _translatedText = null; 
      _isTranslating = true;
    });

    if (_sourceLanguage == null) { 
        if (mounted) {
            setState(() { _isTranslating = false; });
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không thể dịch: Ngôn ngữ gốc không xác định.'))
            );
        }
        return;
    }

    try {
      _onDeviceTranslator?.close(); 
      _onDeviceTranslator = mlkit_translation.OnDeviceTranslator(
        sourceLanguage: _sourceLanguage!, 
        targetLanguage: _targetLanguage,
      );

      final modelManager = mlkit_translation.OnDeviceTranslatorModelManager();
      final String sourceBcp47 = _getBcp47Code(_sourceLanguage); 
      final String targetBcp47 = _getBcp47Code(_targetLanguage);

      bool sourceModelReady = await modelManager.isModelDownloaded(sourceBcp47);

      if (!sourceModelReady) {
        await _downloadModel(modelManager, _sourceLanguage!, _getLanguageDisplayName(_sourceLanguage));
        if (!mounted) return; // Check mounted after async operation
        sourceModelReady = await modelManager.isModelDownloaded(sourceBcp47);
        if (!sourceModelReady) {
           if (mounted) setState(() { _isTranslating = false; });
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể tải model ngôn ngữ nguồn: ${_getLanguageDisplayName(_sourceLanguage)}'))
          );
           return; 
        }
      }

      bool targetModelReady = await modelManager.isModelDownloaded(targetBcp47);
      if (!targetModelReady) {
        await _downloadModel(modelManager, _targetLanguage, _getLanguageDisplayName(_targetLanguage));
        if (!mounted) return; // Check mounted after async operation
        targetModelReady = await modelManager.isModelDownloaded(targetBcp47);
         if (!targetModelReady){
           if (mounted) setState(() { _isTranslating = false; });
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể tải model ngôn ngữ đích: ${_getLanguageDisplayName(_targetLanguage)}'))
          );
           return; 
        }
      }
      
      final String result = await _onDeviceTranslator!.translateText(textToTranslate);
      if (mounted) {
        setState(() {
          _translatedText = result;
        });
      }
    } catch (e) {
      print("Error translating text: $e");
      if (mounted) {
        setState(() {
          _translatedText = "Lỗi dịch thuật: Vui lòng thử lại.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi dịch thuật: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }
  // End AI Feature Methods
}