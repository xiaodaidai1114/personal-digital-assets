/// 智能截断（DESIGN.md）：高度同质化的资产用中段折叠，
/// 保留首尾特征以保证列表扫视精准度，替代纯尾部省略。
String smartTruncate(String text, {int max = 28}) {
  if (max < 5 || text.length <= max) {
    return text;
  }
  // 首段占 6 成（域名前缀、产品名更靠前），尾段占 4 成（TLD、序号）
  final head = (max * .6).round() - 1;
  final tail = max - head - 1;
  return '${text.substring(0, head)}…${text.substring(text.length - tail)}';
}
