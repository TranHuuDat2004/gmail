
import 'dart:io'; 
import 'dart:typed_data'; 
import 'package:file_picker/file_picker.dart'; 
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';


class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final ImageProvider? currentAvatar;
  final String? currentInitial; 

  const EditProfileScreen({
    super.key,
    required this.currentName,
    this.currentAvatar,
    this.currentInitial, 
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  File? _pickedImageFile; 
  Uint8List? _pickedImageBytes; 

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  Future<void> _pickImage() async { 
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false, 
      );

      if (result != null && result.files.isNotEmpty) {
        if (kIsWeb) {
          final bytes = result.files.first.bytes;
          if (bytes != null) {
            setState(() {
              _pickedImageBytes = bytes;
              _pickedImageFile = null; 
            });
          }
        } else {
          final path = result.files.first.path;
          if (path != null) {
            setState(() {
              _pickedImageFile = File(path);
              _pickedImageBytes = null; 
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn ảnh: $e'),
            backgroundColor: theme.colorScheme.error, 
          ),
        );
      }
    }
  }
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define colors based on theme
    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final appBarBackgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final appBarTextColor = isDarkMode ? Colors.grey[300] : Colors.black87;
    final appBarIconColor = isDarkMode ? Colors.grey[400] : Colors.black54;
    final saveButtonBackgroundColor = isDarkMode ? Colors.blue[600] : Colors.blue[700];
    final saveButtonForegroundColor = isDarkMode ? Colors.white : Colors.white;
    final avatarInitialBackgroundColor = isDarkMode ? Colors.blue[700] : Colors.blue[700];
    final avatarInitialTextColor = Colors.white;
    final avatarDefaultBackgroundColor = isDarkMode ? Colors.grey[700] : Colors.grey[200];
    final avatarDefaultIconColor = isDarkMode ? Colors.grey[400] : Colors.grey[400];
    final cameraIconBackgroundColor = isDarkMode ? Colors.blue[600] : Colors.blue[700];
    final cameraIconColor = Colors.white;
    final changePhotoButtonColor = isDarkMode ? Colors.blue[300] : Colors.blue[700];
    final textFieldLabelColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];
    final textFieldBorderColor = isDarkMode ? Colors.grey[600]! : Colors.grey[400]!;
    final textFieldIconColor = isDarkMode ? Colors.grey[500] : Colors.grey[600];

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor, 
      appBar: AppBar(
        title: Text('Chỉnh sửa Hồ sơ', style: TextStyle(color: appBarTextColor)),
        backgroundColor: appBarBackgroundColor, 
        foregroundColor: appBarTextColor, 
        elevation: isDarkMode ? 0 : 1,
        iconTheme: IconThemeData(color: appBarIconColor), 
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0),
            child: ElevatedButton(
              onPressed: () {
                String newName = _nameController.text;
                Navigator.pop(context, {
                  'name': newName,
                  'avatarFile': kIsWeb ? null : _pickedImageFile,
                  'avatarBytes': kIsWeb ? _pickedImageBytes : null,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: saveButtonBackgroundColor, 
                foregroundColor: saveButtonForegroundColor, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                'Lưu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: (_pickedImageFile == null && _pickedImageBytes == null && widget.currentAvatar == null && widget.currentInitial != null && widget.currentInitial!.isNotEmpty)
                        ? avatarInitialBackgroundColor 
                        : avatarDefaultBackgroundColor, 
                    backgroundImage: _pickedImageBytes != null
                        ? MemoryImage(_pickedImageBytes!)
                        : _pickedImageFile != null
                            ? FileImage(_pickedImageFile!)
                            : widget.currentAvatar,
                    child: (_pickedImageFile == null && _pickedImageBytes == null && widget.currentAvatar == null)
                        ? (widget.currentInitial != null && widget.currentInitial!.isNotEmpty)
                            ? Text(
                                widget.currentInitial!,
                                style: TextStyle(
                                  fontSize: 50,
                                  fontWeight: FontWeight.bold,
                                  color: avatarInitialTextColor, 
                                ),
                              )
                            : Icon(Icons.person, size: 70, color: avatarDefaultIconColor) 
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cameraIconBackgroundColor, 
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2), 
                    ),
                    child: Icon(Icons.camera_alt, color: cameraIconColor, size: 20), 
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _pickImage,
              child: Text(
                'Thay đổi ảnh đại diện',
                style: TextStyle(color: changePhotoButtonColor, fontSize: 14), 
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              style: TextStyle(color: isDarkMode ? Colors.grey[200] : Colors.black87), 
              decoration: InputDecoration(
                labelText: 'Tên hiển thị',
                labelStyle: TextStyle(color: textFieldLabelColor),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: textFieldBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5), 
                ),
                prefixIcon: Icon(Icons.person_outline, color: textFieldIconColor),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}