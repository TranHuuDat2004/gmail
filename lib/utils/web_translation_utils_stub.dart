// Stub implementation for web_translation_utils.dart
// This file is used when the app is not running on the web.

Future<String?> detectLanguage(String text, String apiKey) async {
  // This is a stub implementation and should not be called on non-web platforms.
  throw UnimplementedError('detectLanguage is only available on the web.');
}

Future<String?> translateText(String text, String targetLanguage, String sourceLanguage, String apiKey) async {
  // This is a stub implementation and should not be called on non-web platforms.
  throw UnimplementedError('translateText is only available on the web.');
}

// Hàm giả cho việc phát hiện ngôn ngữ trên các nền tảng không phải web.
Future<String> identifyLanguageJS(String text) async {
  print("Web identifyLanguageJS (stub) called on non-web platform. Text: $text");
  // Trả về mã ngôn ngữ không xác định hoặc ném lỗi tùy theo cách bạn muốn xử lý.
  return Future.value('und_stub'); // 'und' for undetermined
}

// Hàm giả cho việc dịch văn bản trên các nền tảng không phải web.
Future<String> translateTextJS(String text, String sourceLangBcp47, String targetLangBcp47) async {
  print("Web translateTextJS (stub) called on non-web platform. Text: $text, Source: $sourceLangBcp47, Target: $targetLangBcp47");
  // Trả về văn bản gốc hoặc thông báo lỗi.
  return Future.value('Tính năng dịch (stub) không khả dụng trên nền tảng này.');
}
