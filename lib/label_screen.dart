import 'package:flutter/material.dart';

class LabelManagementScreen extends StatefulWidget {
  final List<String> currentLabels;
  final Function(List<String> updatedLabels) onLabelsUpdated;

  const LabelManagementScreen({
    Key? key,
    required this.currentLabels,
    required this.onLabelsUpdated,
  }) : super(key: key);

  @override
  _LabelManagementScreenState createState() => _LabelManagementScreenState();
}

class _LabelManagementScreenState extends State<LabelManagementScreen> {
  late List<String> _labels;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Create a mutable copy and sort for consistent parent label availability
    _labels = List<String>.from(widget.currentLabels)..sort();
  }

  void _notifyParentAboutUpdate() {
    // Ensure labels are sorted before notifying, especially after adds/edits
    _labels.sort();
    widget.onLabelsUpdated(List<String>.from(_labels)); // Pass a copy back
  }

  void _showAddOrEditLabelDialog({int? editIndex}) {
    final bool isEditing = editIndex != null;
    String originalFullLabelName = isEditing ? _labels[editIndex!] : "";
    String editablePart = originalFullLabelName;
    String parentPrefix = "";

    if (isEditing && originalFullLabelName.contains('/')) {
      int lastSlashIndex = originalFullLabelName.lastIndexOf('/');
      parentPrefix = originalFullLabelName.substring(0, lastSlashIndex + 1);
      editablePart = originalFullLabelName.substring(lastSlashIndex + 1);
    }
    _textController.text = editablePart;

    // For "Add" dialog's "Nest under" feature
    bool nestUnderParent = false;
    String? selectedParentLabel;
    List<String> availableParentLabels = List<String>.from(_labels)
        .where((label) => !isEditing || label != originalFullLabelName)
        .toList();
    if (availableParentLabels.isEmpty && !isEditing) {
      // If no labels exist yet, can't nest.
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            // backgroundColor: Colors.white; // <--- REMOVE THIS LINE FROM HERE
            return AlertDialog(
              backgroundColor: Colors.white, // <--- ADD THIS LINE HERE
              title: Text(isEditing ? "Sửa tên nhãn" : "New label"),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isEditing)
                      const Text("Please enter a new label name:"),
                    if (isEditing && parentPrefix.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          "Sửa tên cho nhãn con trong: \"${parentPrefix.substring(0, parentPrefix.length -1)}\"",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                    if (!isEditing) const SizedBox(height: 8),
                    TextField(
                      controller: _textController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: isEditing ? "Tên nhãn con mới" : null,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                        ),
                      ),
                    ),
                    if (!isEditing) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 24, height: 24,
                            child: Checkbox(
                              value: nestUnderParent,
                              onChanged: availableParentLabels.isNotEmpty ? (bool? value) {
                                setDialogState(() {
                                  nestUnderParent = value ?? false;
                                  if (!nestUnderParent) {
                                    selectedParentLabel = null;
                                  }
                                });
                              } : null,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text("Nest label under:"),
                        ],
                      ),
                      const SizedBox(height: 8),
                      IgnorePointer(
                        ignoring: !nestUnderParent || availableParentLabels.isEmpty,
                        child: Opacity(
                          opacity: nestUnderParent && availableParentLabels.isNotEmpty ? 1.0 : 0.5,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              filled: !nestUnderParent || availableParentLabels.isEmpty,
                              fillColor: Colors.grey[200],
                            ),
                            value: selectedParentLabel,
                            hint: const Text("Select parent label"),
                            items: availableParentLabels.map((String label) {
                              return DropdownMenuItem<String>(
                                value: label,
                                child: Text(label),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setDialogState(() {
                                selectedParentLabel = newValue;
                              });
                            },
                            isExpanded: true,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text("Cancel", style: TextStyle(color: Theme.of(context).primaryColor)),
                ),
                ElevatedButton(
                   style: ElevatedButton.styleFrom(
                    backgroundColor: isEditing ? Theme.of(context).primaryColor : Colors.grey[200],
                    foregroundColor: isEditing ? Colors.white : Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onPressed: () {
                    final String newEditableNamePart = _textController.text.trim();

                    if (newEditableNamePart.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text("Tên nhãn không được để trống.")),
                      );
                      return;
                    }
                    if (newEditableNamePart.contains('/')) {
                       ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text("Tên nhãn không được chứa ký tự '/'.")),
                      );
                      return;
                    }

                    String finalNewLabelName;
                    if (isEditing) {
                      finalNewLabelName = parentPrefix + newEditableNamePart;
                    } else {
                      if (nestUnderParent && selectedParentLabel != null && selectedParentLabel!.isNotEmpty) {
                        finalNewLabelName = "$selectedParentLabel/$newEditableNamePart";
                      } else {
                        finalNewLabelName = newEditableNamePart;
                      }
                    }

                    if (_labels.contains(finalNewLabelName) && finalNewLabelName != originalFullLabelName) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('Nhãn "$finalNewLabelName" đã tồn tại.')),
                      );
                      return;
                    }
                    if (!isEditing && finalNewLabelName.split('/').length > 5) {
                         ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('Nhãn được lồng quá sâu.')),
                        );
                        return;
                    }

                    setState(() {
                      if (isEditing) {
                        if (originalFullLabelName != finalNewLabelName && !originalFullLabelName.contains('/')) {
                           List<String> labelsToUpdate = [];
                           for (int i = 0; i < _labels.length; i++) {
                               if (_labels[i] == originalFullLabelName) {
                                   _labels[i] = finalNewLabelName;
                               } else if (_labels[i].startsWith("$originalFullLabelName/")) {
                                   _labels[i] = _labels[i].replaceFirst("$originalFullLabelName/", "$finalNewLabelName/");
                               }
                           }
                        } else {
                           _labels[editIndex!] = finalNewLabelName;
                        }
                      } else {
                        _labels.add(finalNewLabelName);
                      }
                       _labels.sort();
                    });
                    _notifyParentAboutUpdate();
                    Navigator.pop(dialogContext);
                  },
                  child: Text(isEditing ? "Lưu" : "Create"),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => _textController.clear());
  }

  void _deleteLabel(int index) {
    final String labelToDelete = _labels[index];
    final String displayName = labelToDelete.split('/').last;
    final bool isParent = _labels.any((label) => label.startsWith("$labelToDelete/") && label != labelToDelete);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Xóa nhãn"),
          content: Text(
            "Bạn có chắc chắn muốn xóa nhãn \"$displayName\"?" +
            (isParent ? "\nThao tác này cũng sẽ xóa tất cả các nhãn con." : "")
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _labels.removeWhere((label) => label == labelToDelete || label.startsWith("$labelToDelete/"));
                });
                _notifyParentAboutUpdate();
                Navigator.pop(context);
              },
              child: const Text("Xóa", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Labels"), // Changed from "Quản lý Nhãn"
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _labels.isEmpty
          ? const Center(
              child: Text(
                "Không có nhãn nào.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.separated(
              itemCount: _labels.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
              itemBuilder: (context, index) {
                final labelFullName = _labels[index];
                List<String> parts = labelFullName.split('/');
                String displayName = parts.last;
                int depth = parts.length - 1;

                return ListTile(
                  contentPadding: EdgeInsets.only(left: 16.0 + (depth * 20.0), right: 8.0),
                  leading: Icon(
                    depth > 0 ? Icons.subdirectory_arrow_right : Icons.label_outline,
                    color: Colors.black54,
                    size: 20 + (depth * 2.0),
                  ),
                  title: Text(displayName, style: const TextStyle(color: Colors.black87)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.black54),
                        tooltip: "Sửa tên",
                        onPressed: () => _showAddOrEditLabelDialog(editIndex: index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: "Xóa nhãn",
                        onPressed: () => _deleteLabel(index),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditLabelDialog(),
        icon: const Icon(Icons.add),
        label: const Text("New label"),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
    );
  }
}