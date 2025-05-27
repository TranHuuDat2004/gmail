import 'package:flutter/material.dart';

class SearchOverlayScreen extends StatefulWidget {
  const SearchOverlayScreen({Key? key}) : super(key: key);

  @override
  _SearchOverlayScreenState createState() => _SearchOverlayScreenState();
}

class _SearchOverlayScreenState extends State<SearchOverlayScreen> {
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: searchController,
          autofocus: true,
          cursorColor: Colors.black,
          decoration: const InputDecoration(
            hintText: 'Tìm trong thư',
            border: InputBorder.none,
          ),
          style: const TextStyle(color: Colors.black87),
          onChanged: (value) {
            // TODO: implement search filtering
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Kết quả tìm kiếm sẽ hiển thị ở đây',
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}