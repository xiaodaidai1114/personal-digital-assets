/// 普通资产字段的安全边界。
///
/// 完整密码、API Key、完整卡号只能进入加密封缄；普通字段只允许
/// 短前缀、后四位等不构成完整凭证的标识信息。
abstract final class AssetFieldPolicy {
  static String? sensitivePlainTextError(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }

    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 12) {
      return '完整卡号不能保存在普通字段，请写入敏感内容';
    }

    if (RegExp(
      r'\b(?:sk|pk|api|access|secret|token)[-_][A-Za-z0-9][A-Za-z0-9\-_]{8,}\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return '完整 Key 不能保存在普通字段，请写入敏感内容';
    }

    if (RegExp(
      r'\b(?:password|passwd|pwd)\b\s*[:=]?\s*[^\s,，;；]{8,}',
      caseSensitive: false,
    ).hasMatch(text)) {
      return '密码不能保存在普通字段，请写入敏感内容';
    }

    if (_looksLikeStandaloneSecret(text)) {
      return '疑似完整敏感内容，请写入封缄字段';
    }
    return null;
  }

  static String? plainFieldError(String key, String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    if (key == 'cardNumber' && !RegExp(r'^\d{4}$').hasMatch(text)) {
      return '银行卡普通字段只能保存 4 位数字后四位';
    }
    return sensitivePlainTextError(text);
  }

  static bool _looksLikeStandaloneSecret(String text) {
    if (text.length < 24 || text.contains(' ') || text.contains('/')) {
      return false;
    }
    final hasLower = RegExp(r'[a-z]').hasMatch(text);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(text);
    final hasDigit = RegExp(r'\d').hasMatch(text);
    final hasSymbol = RegExp(r'[-_]').hasMatch(text);
    return [
          hasLower,
          hasUpper,
          hasDigit,
          hasSymbol,
        ].where((flag) => flag).length >=
        3;
  }
}
