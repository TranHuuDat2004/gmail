// lib/screens/label_management_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LabelManagementScreen extends StatefulWidget {
  const LabelManagementScreen({super.key});

  @override
  State<LabelManagementScreen> createState() => _LabelManagementScreenState();
}

class _LabelManagementScreenState extends State<LabelManagementScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _newLabelController = TextEditingController();
  final FocusNode _newLabelFocusNode = FocusNode();

  Stream<QuerySnapshot<Map<String, dynamic>>>? _labelsStream;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      _labelsStream = _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('labels')
          .orderBy('name', descending: false)
          .snapshots();
    }
  }

  CollectionReference<Map<String, dynamic>> get _userLabelsCollection {
    if (_currentUser == null) {
      throw Exception("User not logged in, cannot access labels.");
    }
    return _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('labels');
  }

  Future<void> _addNewLabel(String? selectedParentLabel, bool nestUnderParent) async {
    if (_newLabelController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng nhập tên nhãn.")),
        );
      }
      return; // Dừng hàm tại đây
    }

    if (_currentUser == null) {
      return; // Giữ lại kiểm tra user
    }
    String newEditableNamePart = _newLabelController.text.trim();

    if (newEditableNamePart.contains('/')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tên nhãn không được chứa ký tự '/'.")),
        );
      }
      return;
    }

    String finalNewLabelName;
    if (nestUnderParent && selectedParentLabel != null && selectedParentLabel.isNotEmpty) {
      finalNewLabelName = "$selectedParentLabel/$newEditableNamePart";
    } else {
      finalNewLabelName = newEditableNamePart;
    }

    if (finalNewLabelName.split('/').length > 5) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhãn được lồng quá sâu (tối đa 5 cấp).')));
        return;
    }

    try {
      final existingLabelQuery = await _userLabelsCollection
          .where('name', isEqualTo: finalNewLabelName)
          .limit(1)
          .get();

      if (existingLabelQuery.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nhãn "$finalNewLabelName" đã tồn tại.')),
          );
        }
        return;
      }

      await _userLabelsCollection.add({
        'name': finalNewLabelName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _newLabelController.clear();
      if (mounted) {
        _newLabelFocusNode.requestFocus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm nhãn "$finalNewLabelName".')),
        );
      }
    } catch (e) {
      print("Error adding new label to Firestore: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi thêm nhãn: $e')),
        );
      }
    }
  }
  Future<void> _editLabel(String labelId, String currentFullName, String currentEditablePart, String parentPrefix) async {
    if (_currentUser == null || !mounted) return;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final TextEditingController editController = TextEditingController(text: currentEditablePart);

    final newEditableName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Sửa tên nhãn',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[200] : Colors.black87,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parentPrefix.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  "Sửa tên cho nhãn con trong: \"${parentPrefix.substring(0, parentPrefix.length -1)}\"",
                  style: TextStyle(
                    fontSize: 12, 
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            TextField(
              controller: editController,
              autofocus: true,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[200] : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: "Tên nhãn mới",
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.blue[400]! : Colors.blue[600]!,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), 
            child: Text(
              'HỦY',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode ? Colors.blue[600] : Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (editController.text.trim().isNotEmpty && !editController.text.trim().contains('/')) {
                Navigator.pop(dialogContext, editController.text.trim());
              } else if (editController.text.trim().contains('/')) {
                 ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text("Tên nhãn không được chứa ký tự '/'.")),
                  );
              } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text("Tên nhãn không được để trống.")),
                  );
              }
            },
            child: const Text('LƯU'),
          ),
        ],
      ),
    );

    if (newEditableName != null && newEditableName != currentEditablePart) {
      final String newFullName = parentPrefix + newEditableName;
      try {
        final existingLabelQuery = await _userLabelsCollection
            .where('name', isEqualTo: newFullName)
            .limit(1)
            .get();
        if (existingLabelQuery.docs.isNotEmpty && existingLabelQuery.docs.first.id != labelId) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tên nhãn "$newFullName" đã tồn tại.')));
          return;
        }

        WriteBatch batch = _firestore.batch();
        // Cập nhật nhãn chính
        batch.update(_userLabelsCollection.doc(labelId), {'name': newFullName});

        // Nếu tên nhãn cha thay đổi (parentPrefix rỗng và tên đầy đủ thay đổi), cập nhật các nhãn con
        if (parentPrefix.isEmpty && currentFullName != newFullName) {
            QuerySnapshot childrenSnapshot = await _userLabelsCollection
                .where('name', isGreaterThanOrEqualTo: "$currentFullName/")
                 .where('name', isLessThan: "$currentFullName\uF8FF") // \uF8FF là ký tự Unicode rất cao
                .get();
            for (var childDoc in childrenSnapshot.docs) {
                String oldChildName = childDoc['name'] as String;
                String newChildName = oldChildName.replaceFirst("$currentFullName/", "$newFullName/");
                batch.update(childDoc.reference, {'name': newChildName});
            }
        }
        await batch.commit();

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật nhãn.')));
      } catch (e) {
        print("Error editing label in Firestore: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi sửa nhãn: $e')));
      }
    }
  }
  Future<void> _deleteLabel(String labelId, String labelName) async {
    if (_currentUser == null || !mounted) return;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Xóa nhãn "$labelName"?',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[200] : Colors.black87,
          ),
        ),
        content: Text(
          'Hành động này sẽ xóa nhãn này. Các email sẽ không bị xóa, chỉ mất các nhãn bị xoá này.',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false), 
            child: Text(
              'HỦY',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'XÓA', 
              style: TextStyle(
                color: isDarkMode ? Colors.red[400] : Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        WriteBatch batch = _firestore.batch();
        List<String> labelsAffectedByDeletion = [labelName];

        // Xóa nhãn chính
        batch.delete(_userLabelsCollection.doc(labelId));

        // Query và xóa tất cả các nhãn con
        QuerySnapshot childrenSnapshot = await _userLabelsCollection
            .where('name', isGreaterThanOrEqualTo: "$labelName/")
            .where('name', isLessThan: "$labelName\uF8FF") // \uF8FF là ký tự Unicode rất cao
            .get();

        for (var childDoc in childrenSnapshot.docs) {
          labelsAffectedByDeletion.add(childDoc['name'] as String);
          batch.delete(childDoc.reference);
        }
        await batch.commit();

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa nhãn và các nhãn con (nếu có).')));
      } catch (e) {
        print("Error deleting label from Firestore: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi xóa nhãn: $e')));
      }
    }
  }

 
  @override
  void dispose() {
    _newLabelController.dispose();
    _newLabelFocusNode.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: const Text("Quản lý Nhãn"),
        backgroundColor: isDarkMode ? const Color(0xFF202124) : Colors.white,
        foregroundColor: isDarkMode ? Colors.grey[200] : Colors.black87,
        elevation: isDarkMode ? 0.5 : 1.0,
      ),      body: _currentUser == null
          ? Center(
              child: Text(
                "Vui lòng đăng nhập để quản lý nhãn.",
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  color: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newLabelController,
                          focusNode: _newLabelFocusNode,
                           maxLength: 20,
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[200] : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tạo nhãn mới nhanh...',

                            counterStyle: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDarkMode ? Colors.blue[400]! : Colors.blue[600]!,
                              ),
                            ),
                            filled: true,
                            fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _addNewLabel(null, false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: "Thêm nhãn",
                        onPressed: () => _addNewLabel(null, false),
                        color: isDarkMode ? Colors.blue[400] : Colors.blue[600],
                      )
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _labelsStream,
                    builder: (context, snapshot) {                      if (snapshot.hasError) return Center(
                        child: Text(
                          'Lỗi: ${snapshot.error}',
                          style: TextStyle(
                            color: isDarkMode ? Colors.red[400] : Colors.red[700],
                          ),
                        ),
                      );
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: isDarkMode ? Colors.blue[400] : Colors.blue[600],
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            "Không có nhãn nào. Nhấn '+' ở trên để tạo.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        );
                      }                      final labels = snapshot.data!.docs;
                      return ListView.separated(
                        itemCount: labels.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1, 
                          indent: 56,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        ),
                        itemBuilder: (context, index) {
                          final labelDoc = labels[index];
                          final labelData = labelDoc.data();
                          final labelFullName = labelData['name'] as String? ?? 'Unnamed Label';
                          List<String> parts = labelFullName.split('/');
                          String displayName = parts.last;
                          int depth = parts.length - 1;
                          String parentPrefix = depth > 0 ? labelFullName.substring(0, labelFullName.lastIndexOf('/') + 1) : "";                          return Container(
                            color: isDarkMode ? const Color(0xFF1F1F1F) : Colors.white,
                            child: ListTile(
                              contentPadding: EdgeInsets.only(left: 16.0 + (depth * 24.0), right: 8.0),
                              leading: Icon(
                                depth > 0 ? Icons.subdirectory_arrow_right : Icons.label_outline,
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                size: 20,
                              ),
                              title: Text(
                                displayName, 
                                style: TextStyle(
                                  color: isDarkMode ? Colors.grey[200] : Colors.black87,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [                                  IconButton(
                                    icon: Icon(
                                      Icons.open_in_new, 
                                      color: isDarkMode ? Colors.green[400] : Colors.green[600], 
                                      size: 22,
                                    ),
                                    tooltip: "Mở nhãn",
                                    onPressed: () {
                                      Navigator.pop(context, {'action': 'selectLabel', 'label': labelFullName});
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined, 
                                      color: isDarkMode ? Colors.blue[400] : Colors.blue[600], 
                                      size: 22,
                                    ),
                                    tooltip: "Sửa tên",
                                    onPressed: () => _editLabel(labelDoc.id, labelFullName, displayName, parentPrefix),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline, 
                                      color: isDarkMode ? Colors.red[400] : Colors.red[600], 
                                      size: 22,
                                    ),
                                    tooltip: "Xóa nhãn",
                                    onPressed: () => _deleteLabel(labelDoc.id, labelFullName),
                                  ),
                                ],
                              ),                              onTap: () {
                                Navigator.pop(context, {'action': 'selectLabel', 'label': labelFullName});
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      
    );
  }
}