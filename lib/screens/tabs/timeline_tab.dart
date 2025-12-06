import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../widgets/community_product_tile.dart';

class TimelineTab extends StatelessWidget {
  const TimelineTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final stream = currentUserId == null
        ? null
        : Supabase.instance.client
            .from('price_records')
            .stream(primaryKey: ['id'])
            .eq('user_id', currentUserId)
            .order('created_at', ascending: false);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('タイムライン'),
            floating: true,
            snap: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          DateFormat('yyyy年M月d日', 'ja_JP').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (stream == null)
            const SliverFillRemaining(
              child: Center(child: Text('タイムラインを見るにはログインしてください')),
            )
          else
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(child: Text('エラー: ${snapshot.error}')),
                  );
                }
                if (!snapshot.hasData) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final records = snapshot.data!;
                if (records.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('まだ記録がありません')),
                  );
                }

                final grouped = _groupRecordsByDate(records);

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final group = grouped[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDateHeader(group.dateLabel),
                          ...group.records.map((record) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: CommunityProductTile(record: record),
                              )),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                    childCount: grouped.length,
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'おはようございます';
    if (hour < 18) return 'こんにちは';
    return 'こんばんは';
  }

  Widget _buildDateHeader(String dateLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF00AA90),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dateLabel,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  List<_DateGroup> _groupRecordsByDate(List<Map<String, dynamic>> records) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      final dateStr = record['created_at'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr).toLocal();
      final key = _getDateLabel(date);
      groups.putIfAbsent(key, () => []).add(record);
    }
    return groups.entries
        .map((e) => _DateGroup(e.key, e.value))
        .toList();
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return '今日';
    if (target == yesterday) return '昨日';
    return DateFormat('M/d').format(date);
  }
}

class _DateGroup {
  final String dateLabel;
  final List<Map<String, dynamic>> records;
  _DateGroup(this.dateLabel, this.records);
}
