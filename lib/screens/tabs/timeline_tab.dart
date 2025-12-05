import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/shopping_card.dart';

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
      appBar: AppBar(title: const Text('タイムライン')),
      body: stream == null
          ? const Center(child: Text('タイムラインを見るにはログインしてください'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final msg = snapshot.error.toString();
                  if (msg.contains('user_id')) {
                    return const Center(
                      child: Text(
                        'user_id 列が見つかりません。Supabase の price_records に user_id を追加してください。',
                      ),
                    );
                  }
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final records = snapshot.data!;
                if (records.isEmpty) {
                  return const Center(child: Text('まだ記録がありません'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return ShoppingCard(record: record);
                  },
                );
              },
            ),
    );
  }
}
