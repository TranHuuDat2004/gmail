// lib/edit_profile_screen.dart
import 'dart:io'; // Để làm việc với File khi chọn ảnh
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Thêm package này vào pubspec.yaml

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final ImageProvider? currentAvatar;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    this.currentAvatar,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  ImageProvider? _newAvatarImage;
  File? _pickedImageFile; // Để lưu file ảnh đã chọn

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _newAvatarImage = widget.currentAvatar;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Chất lượng ảnh (0-100)
        maxWidth: 800, // Giới hạn chiều rộng để tránh ảnh quá lớn
      );

      if (pickedFile != null) {
        setState(() {
          _pickedImageFile = File(pickedFile.path);
          _newAvatarImage = FileImage(_pickedImageFile!);
        });
      }
    } catch (e) {
      // Xử lý lỗi (ví dụ: không có quyền truy cập thư viện ảnh)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh: $e')),
      );
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Chụp ảnh mới'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa Hồ sơ'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: () {
              // Xử lý lưu thay đổi
              // Trong ứng dụng thực tế, bạn sẽ gọi API ở đây
              String newName = _nameController.text;
              // Trả về dữ liệu đã thay đổi cho màn hình trước
              Navigator.pop(context, {
                'name': newName,
                'avatarFile': _pickedImageFile, // Trả về File để màn hình trước xử lý thành ImageProvider
              });
            },
            child: const Text('LƯU', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _showImageSourceActionSheet(context),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _newAvatarImage,
                    child: _newAvatarImage == null
                        ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  )
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _showImageSourceActionSheet(context),
              child: const Text('Thay đổi ảnh đại diện'),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Tên hiển thị',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Bạn có thể thêm các trường khác ở đây (SĐT, Email, v.v.)
          ],
        ),
      ),
    );
  }
}