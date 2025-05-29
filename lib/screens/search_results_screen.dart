import 'package:flutter/material.dart';
import 'email_detail_screen.dart';
import '../widgets/email_list_item.dart'; 

class SearchResultsScreen extends StatelessWidget {
  final String query;
  final List<Map<String, dynamic>> results;
  const SearchResultsScreen({super.key, required this.query, required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.0,
        leading: IconButton( 
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Results for "$query"', style: const TextStyle(color: Colors.black87, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.black54),
      ),
      body: results.isEmpty
          ? Center(
              child: Text(
                'No results found for "$query"',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            )
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final email = results[index];
                bool isUnread = email['read'] == false;

                return EmailListItem(
                  email: email,
                  isDetailedView: true, 
                  isUnread: isUnread,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EmailDetailScreen(email: email)),
                    );
                  },
                  onStarPressed: (bool newStarState) {
                    // This is a placeholder. In a real app, you'd update your data source.
                    print("Email ${email['id']} starred: $newStarState from search results");
                  },
                );
              },
            ),
    );
  }
}
