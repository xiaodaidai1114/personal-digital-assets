import 'package:intl/intl.dart';

/// 资产普通字段的中文展示名。详情页不允许把字段英文名直接交给用户。
const Map<String, String> assetFieldLabels = {
  'plan': '套餐',
  'cycle': '周期',
  'amount': '金额',
  'nextRenewalDate': '下次续费',
  'prefix': 'Key 前缀',
  'environment': '环境',
  'expiryDate': '到期时间',
  'username': '用户名',
  'url': '网址',
  'address': '邮箱地址',
  'recoveryEmail': '恢复邮箱',
  'model': '型号',
  'os': '系统',
  'serialNumber': '序列号',
  'warrantyExpiry': '保修到期',
  'date': '日期',
  'paid': '已支付',
  'bank': '银行',
  'cardNumber': '卡号后四位',
};

abstract final class AssetFieldFormat {
  static String label(String key) => assetFieldLabels[key] ?? key;

  /// 把存储值转成稳定、可扫读的中文文本；保留未知数据的原值。
  static String value(String key, Object? raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) {
      return '—';
    }
    final parsedDate = DateTime.tryParse(text);
    if (parsedDate != null && _isDateKey(key)) {
      return DateFormat('yyyy年M月d日').format(parsedDate);
    }
    final normalized = text.toLowerCase();
    if (key == 'cycle') {
      const labels = {
        'monthly': '每月',
        'everymonth': '每月',
        'quarterly': '每季度',
        'yearly': '每年',
        'annually': '每年',
        'weekly': '每周',
        'daily': '每天',
      };
      return labels[normalized] ?? text;
    }
    if (key == 'paid') {
      if (normalized == 'true' || normalized == 'yes' || text == '是') {
        return '已支付';
      }
      if (normalized == 'false' || normalized == 'no' || text == '否') {
        return '未支付';
      }
    }
    if (key == 'cardNumber') {
      return '•••• $text';
    }
    if (key == 'amount') {
      return _formatAmount(text);
    }
    return text;
  }

  static String _formatAmount(String text) {
    final match = RegExp(
      r'^\s*([¥￥]|US\$|\$|CNY|RMB|USD)?\s*([0-9][0-9,]*(?:\.\d+)?)\s*(CNY|RMB|USD)?\s*$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return text;
    }
    final number = double.tryParse(match.group(2)!.replaceAll(',', ''));
    if (number == null) {
      return text;
    }
    final currency = (match.group(1) ?? match.group(3) ?? '').toUpperCase();
    final formatted = NumberFormat('#,##0.00').format(number);
    return switch (currency) {
      '¥' || '￥' || 'CNY' || 'RMB' => '¥$formatted',
      'USD' => 'USD $formatted',
      'US\$' || '\$' => '\$$formatted',
      _ => formatted,
    };
  }

  static bool _isDateKey(String key) =>
      {'nextRenewalDate', 'expiryDate', 'warrantyExpiry', 'date'}.contains(key);
}
