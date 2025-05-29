import 'package:flutter/material.dart';
import '../widgets/action_button.dart';

class EmailDetailScreen extends StatefulWidget {
  final Map<String, dynamic> email;
  const EmailDetailScreen({super.key, required this.email});

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  bool showDetails = false;
  bool isRead = false;
  bool isStarred = false;

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black54),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Move to Trash',
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(isRead ? Icons.mark_email_unread : Icons.mark_email_read),
            tooltip: isRead ? 'Mark as Unread' : 'Mark as Read',
            onPressed: () {
              setState(() {
                isRead = !isRead;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Assign Labels',
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(isStarred ? Icons.star : Icons.star_border),
            tooltip: isStarred ? 'Unstar' : 'Star',
            onPressed: () {
              setState(() {
                isStarred = !isStarred;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  backgroundImage: email["avatar"] != null ? AssetImage(email["avatar"]) : null,
                  child: email["avatar"] == null
                      ? Text(
                          (email["sender"] ?? "?")[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email["sender"] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            showDetails = !showDetails;
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Đến tôi",
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              showDetails ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showDetails) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("From: "+(email["sender"] ?? ""), style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("To: you@gmail.com", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("CC: ...", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("BCC: ...", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text("Date/Time: "+(email["time"] ?? ""), style: const TextStyle(fontSize: 15, color: Colors.black87)),
                  ],
                ),
              ),
            ],
            const Divider(height: 32),
            Text(
              email["subject"] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 8),
            Text(email["preview"] ?? "(No content)", style: const TextStyle(fontSize: 16, color: Colors.black87)),
            if (email["hasAttachment"] == true)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  children: const [
                    Icon(Icons.attachment, color: Colors.grey),
                    SizedBox(width: 8),
                    Text("Download Attachment", style: TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ActionButton(
                icon: Icons.reply,
                label: "Reply",
                onTap: () {},
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ActionButton(
                icon: Icons.forward,
                label: "Forward",
                onTap: () {},
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
