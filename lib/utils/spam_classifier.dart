import 'dart:convert';
import 'package:http/http.dart' as http;

class SpamClassifier {
  static const String _geminiApiKey = 'AIzaSyDcgUBrSj6_CZogqS3OXPfyCTf-z3gbqHc';
  static const String _geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';
  static Future<bool> classifyEmail({
    required String subject,
    required String body,
    String? from,
  }) async {
    try {
      if (subject.trim().isEmpty && body.trim().isEmpty) {
        return false; 
      }

      final emailContent = '''
Subject: ${subject.trim()}
From: ${from?.trim() ?? 'Unknown'}
Body: ${body.trim()}
''';

      final requestBody = {
        "contents": [
          {
            "parts": [              {
                "text": "Analyze this email and respond with only one word: 'spam' or 'ham'. Consider promotional content, suspicious links, fake offers, phishing attempts as spam. Regular personal/business emails as ham.\n\nEmail:\n$emailContent"
              }
            ]
          }
        ],        "generationConfig": {
          "temperature": 0.3,
          "maxOutputTokens": 10
        }
      };

      final response = await http.post(
        Uri.parse('$_geminiApiUrl?key=$_geminiApiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final candidates = responseData['candidates'] as List?;
        
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            final classification = text?.trim().toLowerCase();
            
            print('AI Classification result: $classification');
            return classification == 'spam';
          }
        }
      } else {
        print('⚠️ API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error classifying email: $e');
    }
    
    return false;
  }

  static Future<void> markEmailAsSpam({
    required String emailId,
    required String userId,
    required bool isSpam,
  }) async {
    try {
    } catch (e) {
      print('Error marking email as spam: $e');
    }
  }
}
