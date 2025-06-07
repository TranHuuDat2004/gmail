import 'dart:convert';
import 'package:http/http.dart' as http;

// QUAN TRỌNG: API KEY CỦA BẠN.
// NHƯ ĐÃ CẢNH BÁO, KHÔNG BAO GIỜ ĐỂ API KEY TRONG MÃ NGUỒN CLIENT CHO PRODUCTION.
// HÃY SỬ DỤNG BACKEND PROXY.
const String _googleApiKey = 'AIzaSyDvZzoiSCdO7cc1GI7RhLVS6oEuAIHWP24';

const String _translateApiBaseUrl = 'https://translation.googleapis.com/language/translate/v2';

// Hàm gọi Google Cloud API để phát hiện ngôn ngữ
Future<String> identifyLanguageJS(String text) async {
  if (_googleApiKey == 'YOUR_GOOGLE_CLOUD_API_KEY' || _googleApiKey.isEmpty || _googleApiKey == 'AIzaSyDvZzoiSCdO7cc1GI7RhLVS6oEuAIHWP24') { // Added your key for safety check during dev
     if (_googleApiKey.startsWith('AIza')) {
     } else {
        print('Lỗi: Khóa API Google Cloud chưa được thiết lập đúng cách trong web_translation_utils_web.dart.');
        return Future.value('und_api_key_issue');
     }
  }

  final Uri requestUri = Uri.parse('$_translateApiBaseUrl/detect?key=$_googleApiKey');

  try {
    final response = await http.post(
      requestUri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'q': text}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['data'] != null &&
          data['data']['detections'] != null &&
          data['data']['detections'].isNotEmpty &&
          data['data']['detections'][0].isNotEmpty) {
        // API trả về một list các detections, mỗi detection là một list.
        // Ví dụ: [[{"language": "en", "confidence": 0.9, "isReliable": false}]]
        // Chúng ta lấy language từ phần tử đầu tiên của detection đầu tiên.
        return data['data']['detections'][0][0]['language']?.toString() ?? 'und_parse_error';
      }
      print('Lỗi phân tích phản hồi phát hiện ngôn ngữ (web): $data');
      return 'und_parse_error';
    } else {
      print('Lỗi API phát hiện ngôn ngữ (web): ${response.statusCode}\nBody: ${response.body}');
      return 'und_api_error_${response.statusCode}';
    }
  } catch (e) {
    print('Ngoại lệ khi phát hiện ngôn ngữ (web): $e');
    return 'und_exception';
  }
}

// Hàm gọi Google Cloud API để dịch văn bản
Future<String> translateTextJS(String text, String sourceLangBcp47, String targetLangBcp47) async {
  if (_googleApiKey == 'YOUR_GOOGLE_CLOUD_API_KEY' || _googleApiKey.isEmpty || _googleApiKey == 'AIzaSyDvZzoiSCdO7cc1GI7RhLVS6oEuAIHWP24') { // Added your key for safety check
     if (_googleApiKey.startsWith('AIza')) {
     } else {
        print('Lỗi: Khóa API Google Cloud chưa được thiết lập đúng cách trong web_translation_utils_web.dart.');
        return Future.value('Dịch thuật yêu cầu Khóa API được cấu hình đúng.');
     }
  }

  final Uri requestUri = Uri.parse('$_translateApiBaseUrl?key=$_googleApiKey');

  try {
    final response = await http.post(
      requestUri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'q': text,
        'source': sourceLangBcp47 == 'und' ? '' : sourceLangBcp47, // API có thể tự phát hiện nếu source trống
        'target': targetLangBcp47,
        'format': 'text', // Chỉ định định dạng là text
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['data'] != null &&
          data['data']['translations'] != null &&
          data['data']['translations'].isNotEmpty) {
        return data['data']['translations'][0]['translatedText']?.toString() ?? 'Lỗi phân tích bản dịch (web)';
      }
      print('Lỗi phân tích phản hồi dịch thuật (web): $data');
      return 'Lỗi phân tích bản dịch (web)';
    } else {
      print('Lỗi API dịch thuật (web): ${response.statusCode}\nBody: ${response.body}');
      return 'Lỗi API dịch thuật (web): ${response.statusCode}';
    }
  } catch (e) {
    print('Ngoại lệ khi dịch văn bản (web): $e');
    return 'Ngoại lệ dịch thuật (web)';
  }
}
