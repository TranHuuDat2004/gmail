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
    if (_newLabelController.text.trim().isEmpty || _currentUser == null) {
      return;
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
    final TextEditingController editController = TextEditingController(text: currentEditablePart);

    final newEditableName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Sửa tên nhãn'),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            TextField(
              controller: editController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Tên nhãn mới",
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('HỦY')),
          ElevatedButton(
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

        // TODO (RẤT QUAN TRỌNG & PHỨC TẠP): Cập nhật tên nhãn trong tất cả các email
        // Sử dụng Cloud Function cho việc này là tốt nhất.
        // Client-side code (chỉ để minh họa, không khuyến khích cho nhiều email):
        /*
        if (_currentUser != null) {
            QuerySnapshot emailSnapshot = await _firestore.collection('emails')
                .where('labels.${_currentUser!.uid}', arrayContains: currentFullName)
                .get();
            WriteBatch emailBatch = _firestore.batch();
            for (DocumentSnapshot doc in emailSnapshot.docs) {
              emailBatch.update(doc.reference, {
                  'labels.${_currentUser!.uid}': FieldValue.arrayRemove([currentFullName]),
              });
              emailBatch.update(doc.reference, {
                  'labels.${_currentUser!.uid}': FieldValue.arrayUnion([newFullName]),
              });
            }
            // Cập nhật cho các nhãn con nếu tên nhãn cha thay đổi
            if (parentPrefix.isEmpty && currentFullName != newFullName) {
                QuerySnapshot childrenSnapshot = await _userLabelsCollection
                    .where('name', isGreaterThanOrEqualTo: "$newFullName/") // Dùng newFullName để lấy tên con mới
                    .where('name', isLessThan: "$newFullName0")
                    .get();
                for (var childLabelDoc in childrenSnapshot.docs) {
                    String oldChildLabelFullName = childLabelDoc['name']!.toString().replaceFirst("$newFullName/", "$currentFullName/");
                    QuerySnapshot childEmailSnapshot = await _firestore.collection('emails')
                        .where('labels.${_currentUser!.uid}', arrayContains: oldChildLabelFullName)
                        .get();
                    for (DocumentSnapshot doc in childEmailSnapshot.docs) {
                        emailBatch.update(doc.reference, {'labels.${_currentUser!.uid}': FieldValue.arrayRemove([oldChildLabelFullName])});
                        emailBatch.update(doc.reference, {'labels.${_currentUser!.uid}': FieldValue.arrayUnion([childLabelDoc['name']])});
                    }
                }
            }
            await emailBatch.commit();
            print("Updated labels in emails (client-side attempt).");
        }
        */

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật nhãn.')));
      } catch (e) {
        print("Error editing label in Firestore: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi sửa nhãn: $e')));
      }
    }
  }

  Future<void> _deleteLabel(String labelId, String labelName) async {
    if (_currentUser == null || !mounted) return;

    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Xóa nhãn "$labelName"?'),
        content: const Text('Hành động này sẽ xóa nhãn này và tất cả các nhãn con của nó (nếu có). Các email sẽ không bị xóa, chỉ mất các nhãn này.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('HỦY')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('XÓA', style: TextStyle(color: Colors.red)),
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

        // TODO (RẤT QUAN TRỌNG & PHỨC TẠP): Cập nhật (xóa) các nhãn này khỏi tất cả các email
        // Sử dụng Cloud Function cho việc này là tốt nhất.
        // Client-side code (chỉ để minh họa, không khuyến khích cho nhiều email):
        /*
        if (_currentUser != null && labelsAffectedByDeletion.isNotEmpty) {
            QuerySnapshot emailSnapshot = await _firestore.collection('emails')
               .where('labels.${_currentUser!.uid}', arrayContainsAny: labelsAffectedByDeletion)
               .get();
            WriteBatch emailBatch = _firestore.batch();
            for (DocumentSnapshot doc in emailSnapshot.docs) {
              emailBatch.update(doc.reference, {'labels.${_currentUser!.uid}': FieldValue.arrayRemove(labelsAffectedByDeletion)});
            }
            await emailBatch.commit();
            print("Removed labels from emails (client-side attempt).");
        }
        */

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Quản lý Nhãn"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _currentUser == null
          ? const Center(child: Text("Vui lòng đăng nhập để quản lý nhãn."))
          : Column( // Bọc trong Column để thêm TextField ở trên
              children: [
                Padding( // TextField để thêm nhãn nhanh (tùy chọn, có thể chỉ dùng FAB)
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newLabelController,
                          focusNode: _newLabelFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Tạo nhãn mới nhanh...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (_) => _addNewLabel(null, false), // Thêm nhãn không lồng
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: "Thêm nhãn",
                        onPressed: () => _addNewLabel(null, false),
                        color: Theme.of(context).primaryColor,
                      )
                    ],
                  ),
                ),
                const Divider(height:1),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _labelsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text("Không có nhãn nào. Nhấn '+' ở dưới để tạo.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        );
                      }

                      final labels = snapshot.data!.docs;
                      return ListView.separated(
                        itemCount: labels.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                        itemBuilder: (context, index) {
                          final labelDoc = labels[index];
                          final labelData = labelDoc.data();
                          final labelFullName = labelData['name'] as String? ?? 'Unnamed Label';
                          List<String> parts = labelFullName.split('/');
                          String displayName = parts.last;
                          int depth = parts.length - 1;
                          String parentPrefix = depth > 0 ? labelFullName.substring(0, labelFullName.lastIndexOf('/') + 1) : "";

                          return ListTile(
                            contentPadding: EdgeInsets.only(left: 16.0 + (depth * 24.0), right: 8.0),
                            leading: Icon(
                              depth > 0 ? Icons.subdirectory_arrow_right : Icons.label_outline,
                              color: Colors.black54,
                              size: 20,
                            ),
                            title: Text(displayName, style: const TextStyle(color: Colors.black87)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 22),
                                  tooltip: "Sửa tên",
                                  onPressed: () => _editLabel(labelDoc.id, labelFullName, displayName, parentPrefix),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                  tooltip: "Xóa nhãn",
                                  onPressed: () => _deleteLabel(labelDoc.id, labelFullName),
                                ),
                              ],
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