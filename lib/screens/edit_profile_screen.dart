// lib/edit_profile_screen.dart
import 'dart:io'; // Để làm việc với File khi chọn ảnh
import 'dart:typed_data'; // THÊM: Để làm việc với Uint8List cho web
import 'package:flutter/foundation.dart'; // THÊM: Để kiểm tra kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Thêm package này vào pubspec.yaml

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

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    // _newAvatarImage = widget.currentAvatar; // Không cần gán ở đây nữa
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Chất lượng ảnh (0-100)
        maxWidth: 800, // Giới hạn chiều rộng để tránh ảnh quá lớn
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _pickedImageBytes = bytes;
            _pickedImageFile = null; // Đảm bảo file được clear nếu trước đó là mobile
          });
        } else {
          setState(() {
            _pickedImageFile = File(pickedFile.path);
            _pickedImageBytes = null; // Đảm bảo bytes được clear nếu trước đó là web
          });
        }
      }
    } catch (e) {
      // Xử lý lỗi (ví dụ: không có quyền truy cập thư viện ảnh)
      if (mounted) { // Thêm kiểm tra mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e')),
        );
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white, // THAY ĐỔI: Đặt nền cho modal bottom sheet thành trắng
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
      backgroundColor: Colors.white, // THAY ĐỔI: Nền trắng
      appBar: AppBar(
        title: const Text('Chỉnh sửa Hồ sơ', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white, // THAY ĐỔI: Nền AppBar trắng
        foregroundColor: Colors.black87, // Màu chữ và icon trên AppBar
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black54), // Màu icon back
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0), // Thêm padding để nút không quá sát cạnh
            child: ElevatedButton(
              onPressed: () {
                String newName = _nameController.text;
                Navigator.pop(context, {
                  'name': newName,
                  // THAY ĐỔI: Truyền bytes nếu là web, file nếu là mobile
                  'avatarFile': kIsWeb ? null : _pickedImageFile,
                  'avatarBytes': kIsWeb ? _pickedImageBytes : null,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700], // Nền xanh
                foregroundColor: Colors.white, // Chữ trắng
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
            const SizedBox(height: 20), // Thêm khoảng cách từ AppBar
            GestureDetector(
              onTap: () => _showImageSourceActionSheet(context),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: (_pickedImageFile == null && _pickedImageBytes == null && widget.currentAvatar == null && widget.currentInitial != null && widget.currentInitial!.isNotEmpty)
                        ? Colors.blue[700] // Blue background for initial
                        : Colors.grey[200], // Default grey for icon or if image is present
                    backgroundImage: _pickedImageBytes != null
                        ? MemoryImage(_pickedImageBytes!) // Ưu tiên hiển thị ảnh bytes đã chọn (web)
                        : _pickedImageFile != null
                            ? FileImage(_pickedImageFile!) // Sau đó là ảnh file đã chọn (mobile)
                            : widget.currentAvatar, // Hiển thị avatar hiện tại nếu không có ảnh mới
                    child: (_pickedImageFile == null && _pickedImageBytes == null && widget.currentAvatar == null)
                        ? (widget.currentInitial != null && widget.currentInitial!.isNotEmpty)
                            ? Text(
                                widget.currentInitial!,
                                style: TextStyle(
                                  fontSize: 50, // Kích thước chữ cho initial
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white, // White text color for initial
                                ),
                              )
                            : Icon(Icons.person, size: 70, color: Colors.grey[400]) // Icon mặc định
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue[700], // Màu nền icon camera
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  )
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _showImageSourceActionSheet(context),
              child: Text(
                'Thay đổi ảnh đại diện',
                style: TextStyle(color: Colors.blue[700], fontSize: 14), // Style cho text button
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Tên hiển thị',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}