import 'dart:convert';
import 'package:http/http.dart' as http;

class ReplySuggestionService {
  static const String _geminiApiKey = 'AIzaSyDcgUBrSj6_CZogqS3OXPfyCTf-z3gbqHc';
  static const String _geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';
  static Future<List<String>> generateReplySuggestions(Map<String, dynamic> originalEmail) async {
    try {
      final subject = originalEmail['subject'] as String? ?? '';
      final body = originalEmail['bodyPlainText'] as String? ?? originalEmail['body'] as String? ?? '';
      final senderName = originalEmail['senderDisplayName'] as String? ?? originalEmail['senderEmail'] as String? ?? originalEmail['from'] as String? ?? 'người gửi';

      if (subject.trim().isEmpty && body.trim().isEmpty) {
        return _getFallbackSuggestions();
      }

      final emailContent = '''
Tiêu đề: $subject
Từ: $senderName
Nội dung: $body
''';

      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": "Dựa trên email sau, hãy tạo 3 câu trả lời ngắn gọn, lịch sự và phù hợp bằng tiếng Việt. Mỗi câu trả lời nên có độ dài từ 5-20 từ, phù hợp cho việc trả lời nhanh. Chỉ trả về 3 câu trả lời, mỗi câu một dòng, không có số thứ tự hay ký hiệu đặc biệt:\n\nEmail:\n$emailContent"
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 150
        }
      };

      final response = await http.post(
        Uri.parse('$_geminiApiUrl?key=$_geminiApiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final candidates = responseData['candidates'] as List?;
        
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null) {              final suggestions = text.split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty && !s.startsWith('*') && !s.contains(':') && !RegExp(r'^\d+\.').hasMatch(s))
                  .take(3)
                  .toList();
              
              if (suggestions.length >= 2) {
                return suggestions;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error generating reply suggestions: $e');
    }
    
    return _getFallbackSuggestions();
  }

  static List<String> _getFallbackSuggestions() {
    return [
      'Cảm ơn bạn đã gửi email.',
      'Tôi đã nhận được thông tin và sẽ phản hồi sớm.',
      'Cảm ơn bạn đã liên hệ.'
    ];
  }
}