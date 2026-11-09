const maxCheckinImageBytes = 5 * 1024 * 1024;

String? checkinProofError({required String text, required bool hasImage}) {
  if (text.trim().isEmpty && !hasImage) {
    return '请写点感受，或拍一张完成瞬间';
  }
  if (text.trim().length > 500) {
    return '打卡内容不能超过 500 字';
  }
  return null;
}

String? checkinImageSizeError(int byteLength) {
  if (byteLength > maxCheckinImageBytes) {
    return '图片不能超过 5MB';
  }
  return null;
}
