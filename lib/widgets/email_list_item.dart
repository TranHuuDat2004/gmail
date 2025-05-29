import 'package:flutter/material.dart';

class EmailListItem extends StatefulWidget {
  final Map<String, dynamic> email;
  final bool isDetailedView;
  final bool isUnread;
  final VoidCallback onTap;
  final Function(bool) onStarPressed;

  const EmailListItem({
    super.key,
    required this.email,
    required this.isDetailedView,
    required this.isUnread,
    required this.onTap,
    required this.onStarPressed,
  });

  @override
  _EmailListItemState createState() => _EmailListItemState();
}

class _EmailListItemState extends State<EmailListItem> {
  late bool _isStarred;

  @override
  void initState() {
    super.initState();
    _isStarred = widget.email['starred'] ?? false;
  }

  @override
  void didUpdateWidget(EmailListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.email != oldWidget.email || widget.email['starred'] != oldWidget.email['starred']) {
      setState(() {
        _isStarred = widget.email['starred'] ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    final senderInitial = (email["sender"] ?? "?").isEmpty ? "?" : (email["sender"] ?? "?")[0].toUpperCase();
    final avatarPath = email["avatar"] as String?;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: widget.isUnread ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[200],
        backgroundImage: avatarPath != null && avatarPath.isNotEmpty ? AssetImage(avatarPath) : null,
        child: (avatarPath == null || avatarPath.isEmpty)
            ? Text(
                senderInitial,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.isUnread ? Theme.of(context).primaryColorDark : Colors.grey[700],
                ),
              )
            : null,
      ),
      title: Text(
        email["sender"] ?? 'Unknown Sender',
        style: TextStyle(
          fontWeight: widget.isUnread ? FontWeight.bold : FontWeight.normal,
          color: Colors.black87,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            email["subject"] ?? '(No Subject)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: widget.isUnread ? FontWeight.w500 : FontWeight.normal,
              color: widget.isUnread ? Colors.black.withOpacity(0.85) : Colors.black54,
            ),
          ),
          if (widget.isDetailedView && email["preview"] != null && (email["preview"] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                email["preview"],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min, 
        children: [
          Text(
            email["time"] ?? "",
            style: TextStyle(
              fontSize: 12,
              color: widget.isUnread ? Theme.of(context).primaryColor : Colors.grey[600],
              fontWeight: widget.isUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4), 
          SizedBox( 
            width: 24,
            height: 24,
            child: IconButton(
              icon: Icon(
                _isStarred ? Icons.star : Icons.star_border,
                color: _isStarred ? Colors.amber[600] : Colors.grey,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 18, 
              tooltip: _isStarred ? 'Unstar' : 'Star',
              onPressed: () {
                widget.onStarPressed(!_isStarred); 
              },
            ),
          ),
        ],
      ),
      onTap: widget.onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
      tileColor: widget.isUnread ? Theme.of(context).primaryColor.withOpacity(0.03) : null, 
    );
  }
}
