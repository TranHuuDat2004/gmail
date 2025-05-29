import 'package:flutter/material.dart';

class ComposeEmailScreen extends StatefulWidget {
  const ComposeEmailScreen({super.key});
  @override
  State<ComposeEmailScreen> createState() => _ComposeEmailScreenState();
}

class _ComposeEmailScreenState extends State<ComposeEmailScreen> {
  final TextEditingController toController = TextEditingController();
  final TextEditingController ccController = TextEditingController();
  final TextEditingController bccController = TextEditingController();
  final TextEditingController fromController = TextEditingController(text: "user@example.com");
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();

  bool showCcBcc = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.0, 
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () { Navigator.pop(context); },
        ),
        title: const Text("Compose", style: TextStyle(color: Colors.black87, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.attach_file_outlined, color: Colors.black54), onPressed: () {}),
          IconButton(icon: const Icon(Icons.send_outlined, color: Colors.blueAccent), onPressed: () { Navigator.pop(context);}),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.black54), onPressed: () {}),
        ],
      ),
      body: ListView( 
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        children: [
          _buildRecipientField(
            label: "To",
            controller: toController,
            onToggleCcBcc: () {
              setState(() {
                showCcBcc = !showCcBcc;
              });
            }
          ),
          if (showCcBcc) ...[
            _buildRecipientField(label: "Cc", controller: ccController),
            _buildRecipientField(label: "Bcc", controller: bccController),
          ],
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          _buildFromField(controller: fromController),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          TextField(
            controller: subjectController,
            cursorColor: Colors.black,
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            decoration: const InputDecoration(
              hintText: "Subject", 
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.black54),
              contentPadding: EdgeInsets.symmetric(vertical: 16.0), 
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          TextField(
            controller: bodyController,
            cursorColor: Colors.black,
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            decoration: const InputDecoration(
              hintText: "Compose email",
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.black54),
              contentPadding: EdgeInsets.symmetric(vertical: 16.0),
            ),
            maxLines: null, 
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientField({required String label, required TextEditingController controller, VoidCallback? onToggleCcBcc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 40, 
          child: Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[700])),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            cursorColor: Colors.black,
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16.0), 
            ),
          ),
        ),
        if (label == "To") 
          IconButton(
            icon: Icon(showCcBcc ? Icons.expand_less : Icons.expand_more, color: Colors.black54),
            onPressed: onToggleCcBcc,
            splashRadius: 20,
          )
        else
          const SizedBox(width: 48), 
      ],
    );
  }

  Widget _buildFromField({required TextEditingController controller}) {
     return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 40, 
          child: Text("From", style: TextStyle(fontSize: 15, color: Colors.grey[700])),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            readOnly: true, 
            cursorColor: Colors.black,
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16.0),
            ),
          ),
        ),
      ],
    );
  }
}
