/// 统一把接口/运行时异常转成可读文案。
String formatError(Object error) {
  final raw = error.toString();
  return raw
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^ApiException:\s*'), '')
      .trim();
}
