import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/asset_repository.dart';
import '../data/reminders/bill_calendar.dart';
import '../domain/asset.dart';
import '../theme/app_theme.dart';
import '../vault/vault_controller.dart';
import 'asset_detail_screen.dart';
import 'widgets/asset_type_badge.dart';

/// 账单日历：月视图账单分布 + 选中日明细 + 未来 30 天续期提醒。
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.controller,
    required this.repository,
    this.onDataChanged,
  });

  final VaultController controller;
  final AssetRepository repository;
  final VoidCallback? onDataChanged;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Asset> _assets = [];
  bool _loading = true;
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _reload();
  }

  Future<void> _reload() async {
    try {
      final assets = await widget.repository.listAssets();
      if (!mounted) {
        return;
      }
      setState(() {
        _assets = assets;
        _loading = false;
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  List<Asset> get _bills =>
      _assets.where((asset) => asset.type == AssetType.bill).toList();

  List<ReminderItem> get _upcoming =>
      const ReminderPlanner().plan(_assets, DateTime.now());

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final monthBills = BillCalendar.monthMap(
      _bills,
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final selectedBills = _selectedDay == null
        ? const <Asset>[]
        : monthBills[_selectedDay!] ?? const <Asset>[];
    return Scaffold(
      appBar: AppBar(title: const Text('哨所')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text('未来 30 天', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_upcoming.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('保险库状态良好'),
              ),
            )
          else
            for (final item in _upcoming)
              _ReminderTile(
                key: ValueKey(item.id),
                item: item,
                onTap: () {
                  final asset = _assets.where(
                    (a) => a.id == item.id.split('@').first,
                  );
                  if (asset.isNotEmpty) {
                    _openDetail(asset.first);
                  }
                },
              ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _shiftMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          transitionBuilder: (child, animation) =>
                              SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(.08, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                          child: Text(
                            DateFormat('yyyy 年 M 月').format(_focusedMonth),
                            key: ValueKey(_focusedMonth),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _shiftMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MonthGrid(
                    focusedMonth: _focusedMonth,
                    billsByDay: monthBills,
                    selectedDay: _selectedDay,
                    onSelect: (day) => setState(
                      () => _selectedDay = _selectedDay == day ? null : day,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedDay != null) ...[
            Text(
              DateFormat('M 月 d 日账单').format(_selectedDay!),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (selectedBills.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('这一天没有账单'),
                ),
              )
            else
              for (final bill in selectedBills)
                _BillTile(
                  key: ValueKey(bill.id),
                  bill: bill,
                  onTap: () => _openDetail(bill),
                ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Future<void> _openDetail(Asset asset) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(
          controller: widget.controller,
          repository: widget.repository,
          assetId: asset.id,
        ),
      ),
    );
    await _reload();
    widget.onDataChanged?.call();
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.focusedMonth,
    required this.billsByDay,
    required this.selectedDay,
    required this.onSelect,
  });

  final DateTime focusedMonth;
  final Map<DateTime, List<Asset>> billsByDay;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month);
    // 周一为一周起点：0=周一。
    final leadingBlanks = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    ).day;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final cells = <Widget>[
      for (var i = 0; i < 7; i++)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '一二三四五六日'[i],
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.dayTextSecondary),
            ),
          ),
        ),
    ];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(focusedMonth.year, focusedMonth.month, day);
      final bills = billsByDay[date];
      final isToday = date == todayDay;
      final isSelected = date == selectedDay;
      cells.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.all(2),
            height: 52,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.paper2 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppColors.ink
                    : isToday
                    ? AppColors.mark
                    : AppColors.dayOutline,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                    color: isToday ? AppColors.mark : AppColors.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (bills != null && bills.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < bills.length && i < 3; i++)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({super.key, required this.bill, required this.onTap});

  final Asset bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.zero,
    child: Card(
      child: ListTile(
        leading: AssetTypeBadge(type: bill.type, size: 28),
        title: Text(bill.title),
        subtitle: Text(
          billDateOf(bill)?.toIso8601String().split('T').first ?? '',
        ),
        trailing: Text(
          bill.fields['amount']?.toString() ?? '',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        onTap: onTap,
      ),
    ),
  );
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({super.key, required this.item, required this.onTap});

  final ReminderItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final daysLeft = item.dueDate
        .difference(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        )
        .inDays;
    final isBill = item.kind == 'bill';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: AssetTypeBadge(
            type: isBill ? AssetType.bill : AssetType.subscription,
            size: 28,
          ),
          title: Text(item.title),
          subtitle: Text(
            '${DateFormat('M月d日').format(item.dueDate)} · ${isBill ? '账单' : '续期'}',
          ),
          trailing: Text(
            daysLeft == 0 ? '今天' : '$daysLeft 天后',
            style: TextStyle(
              color: daysLeft <= 3 ? AppColors.danger : AppColors.ink2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
