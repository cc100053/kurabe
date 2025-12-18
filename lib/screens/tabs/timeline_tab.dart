import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../data/mappers/price_record_mapper.dart';
import '../../data/models/price_record_model.dart';
import '../../main.dart';
import '../../widgets/community_product_tile.dart';

class TimelineTab extends StatefulWidget {
  const TimelineTab({super.key});

  @override
  State<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<TimelineTab> {
  final PriceRecordMapper _mapper = PriceRecordMapper();
  Stream<List<PriceRecordModel>>? _stream;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  Stream<List<PriceRecordModel>>? _buildStream() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return null;
    return Supabase.instance.client
        .from('price_records')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .whereType<Map>()
            .map((row) => _mapper.fromMap(Map<String, dynamic>.from(row)))
            .toList());
  }

  Future<void> _onRefresh() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    setState(() {
      _stream = _buildStream();
    });
    if (currentUserId == null) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return;
    }
    await Supabase.instance.client
        .from('price_records')
        .select('id')
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false)
        .limit(1);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;

    return Scaffold(
      backgroundColor: KurabeColors.background,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Premium Header
            SliverAppBar(
              expandedHeight: 140,
              floating: true,
              snap: true,
              backgroundColor: KurabeColors.background,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting row with emoji
                        Row(
                          children: [
                            Text(
                              _getGreetingEmoji(),
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getGreeting(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: KurabeColors.textSecondary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Date with badge styling
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: KurabeColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            DateFormat('yyyy年M月d日（E）', 'ja_JP')
                                .format(DateTime.now()),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: KurabeColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            if (stream == null)
              SliverFillRemaining(
                child: _buildEmptyState(
                  icon: PhosphorIcons.signIn(PhosphorIconsStyle.duotone),
                  title: 'ログインしてください',
                  subtitle: 'タイムラインを見るにはログインが必要です',
                ),
            )
            else
              StreamBuilder<List<PriceRecordModel>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: _buildEmptyState(
                        icon: PhosphorIcons.warningCircle(
                            PhosphorIconsStyle.duotone),
                        title: 'エラーが発生しました',
                        subtitle: '${snapshot.error}',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: KurabeColors.primary,
                        ),
                      ),
                    );
                  }
                  final records = snapshot.data!;
                  if (records.isEmpty) {
                    return SliverFillRemaining(
                      child: _buildEmptyState(
                        icon: PhosphorIcons.scan(PhosphorIconsStyle.duotone),
                        title: 'まだ記録がありません',
                        subtitle: 'スキャンボタンで\n価格をスキャンしてみましょう',
                        showAction: true,
                      ),
                    );
                  }

                  final grouped = _groupRecordsByDate(records);

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = grouped[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDateHeader(context, group.dateLabel),
                              ...group.records.map(
                                (record) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: CommunityProductTile(record: record),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: grouped.length,
                    ),
                  );
                },
              ),

            // Bottom padding for FAB
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'こんばんは';
    if (hour < 12) return 'おはようございます';
    if (hour < 18) return 'こんにちは';
    return 'こんばんは';
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 5) return '🌙';
    if (hour < 12) return '☀️';
    if (hour < 18) return '🌤️';
    return '🌙';
  }

  Widget _buildDateHeader(BuildContext context, String dateLabel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  KurabeColors.primary.withAlpha(26),
                  KurabeColors.primaryLight.withAlpha(13),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill),
                  size: 16,
                  color: KurabeColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: KurabeColors.primary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showAction = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: KurabeColors.primary.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: KurabeColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: KurabeColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: KurabeColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (showAction) ...[
              const SizedBox(height: 32),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: KurabeColors.primary.withAlpha(13),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: KurabeColors.primary.withAlpha(26),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIcons.arrowDown(PhosphorIconsStyle.bold),
                      size: 18,
                      color: KurabeColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '下のボタンをタップ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: KurabeColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_DateGroup> _groupRecordsByDate(List<PriceRecordModel> records) {
    final groups = <String, List<PriceRecordModel>>{};
    for (final record in records) {
      final date = record.createdAt?.toLocal();
      if (date == null) continue;
      final key = _getDateLabel(date);
      groups.putIfAbsent(key, () => []).add(record);
    }
    return groups.entries.map((e) => _DateGroup(e.key, e.value)).toList();
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);
    final weekday = _weekdayLabel(date);

    if (target == today) return '今日($weekday)';
    if (target == yesterday) return '昨日($weekday)';
    return '${DateFormat('M月d日').format(date)}($weekday)';
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['月', '火', '水', '木', '金', '土', '日'];
    final index = date.weekday - 1;
    if (index < 0 || index >= labels.length) return '';
    return labels[index];
  }
}

class _DateGroup {
  final String dateLabel;
  final List<PriceRecordModel> records;
  _DateGroup(this.dateLabel, this.records);
}
