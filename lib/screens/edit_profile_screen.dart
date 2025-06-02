// lib/edit_profile_screen.dart
import 'dart:io'; // Để làm việc với File khi chọn ảnh
import 'dart:typed_data'; // THÊM: Để làm việc với Uint8List cho web
import 'package:file_picker/file_picker.dart'; // THAY ĐỔI: Sử dụng file_picker
import 'package:flutter/foundation.dart'; // THÊM: Để kiểm tra kIsWeb
import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart'; // XÓA: Không cần image_picker nữa

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final ImageProvider? currentAvatar;
  final String? currentInitial; // THÊM: Để hiển thị ký tự đầu nếu không có avatar

  const EditProfileScreen({
    super.key,
    required this.currentName,
    this.currentAvatar,
    this.currentInitial, // THÊM
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  File? _pickedImageFile; // Để lưu file ảnh đã chọn cho mobile
  Uint8List? _pickedImageBytes; // THÊM: Để lưu bytes ảnh đã chọn cho web

  // final ImagePicker _picker = ImagePicker(); // XÓA: Không cần _picker của image_picker

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    // _newAvatarImage = widget.currentAvatar; // Không cần gán ở đây nữa
  }

  Future<void> _pickImage() async { // THAY ĐỔI: Không cần ImageSource nữa
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false, // Chỉ cho phép chọn 1 ảnh
      );

      if (result != null && result.files.isNotEmpty) {
        if (kIsWeb) {
          // Trên web, lấy bytes của file
          final bytes = result.files.first.bytes;
          if (bytes != null) {
            setState(() {
              _pickedImageBytes = bytes;
              _pickedImageFile = null; // Đảm bảo file được clear
            });
          }
        } else {
          // Trên mobile, lấy đường dẫn file
          final path = result.files.first.path;
          if (path != null) {
            setState(() {
              _pickedImageFile = File(path);
              _pickedImageBytes = null; // Đảm bảo bytes được clear
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context); // Get theme for SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn ảnh: $e'),
            backgroundColor: theme.colorScheme.error, // Use theme error color
          ),
        );
      }
    }
  }

  // void _showImageSourceActionSheet(BuildContext context) { // XÓA: Phương thức này không còn cần thiết với file_picker
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.white,
  //     builder: (BuildContext bc) {
  //       return SafeArea(
  //         child: Wrap(
  //           children: <Widget>[
  //             ListTile(
  //               leading: const Icon(Icons.photo_library),
  //               title: const Text('Chọn từ thư viện'),
  //               onTap: () {
  //                 _pickImage(ImageSource.gallery);
  //                 Navigator.of(context).pop();
  //               },
  //             ),
  //             ListTile(
  //               leading: const Icon(Icons.photo_camera),
  //               title: const Text('Chụp ảnh mới'),
  //               onTap: () {
  //                 _pickImage(ImageSource.camera);
  //                 Navigator.of(context).pop();
  //               },
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

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
        foregroundColor: appBarTextColor, // For title and potentially other elements if not overridden
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
                      border: Border.all(color: Colors.white, width: 2), // White border remains for contrast
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
              style: TextStyle(color: isDarkMode ? Colors.grey[200] : Colors.black87), // Text input color
              decoration: InputDecoration(
                labelText: 'Tên hiển thị',
                labelStyle: TextStyle(color: textFieldLabelColor),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: textFieldBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5), // Use theme primary for focused border
                ),
                prefixIcon: Icon(Icons.person_outline, color: textFieldIconColor),
                // Ensure hint text is also themed if you add one
                // hintStyle: TextStyle(color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}