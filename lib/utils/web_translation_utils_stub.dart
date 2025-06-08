Future<String?> detectLanguage(String text, String apiKey) async {
  throw UnimplementedError('detectLanguage is only available on the web.');
}

Future<String?> translateText(String text, String targetLanguage, String sourceLanguage, String apiKey) async {
  throw UnimplementedError('translateText is only available on the web.');
}

Future<String> identifyLanguageJS(String text) async {
  print("Web identifyLanguageJS (stub) called on non-web platform. Text: $text");
  return Future.value('und_stub'); 
}

Future<String> translateTextJS(String text, String sourceLangBcp47, String targetLangBcp47) async {
  print("Web translateTextJS (stub) called on non-web platform. Text: $text, Source: $sourceLangBcp47, Target: $targetLangBcp47");
  return Future.value('Tính năng dịch (stub) không khả dụng trên nền tảng này.');
}
