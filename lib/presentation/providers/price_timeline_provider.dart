import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/mappers/price_record_mapper.dart';
import '../../data/models/price_record_model.dart';

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final timelineRecordsProvider =
    StreamProvider.autoDispose<List<PriceRecordModel>>((ref) {
  ref.watch(authStateChangesProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    return const Stream<List<PriceRecordModel>>.empty();
  }
  final mapper = PriceRecordMapper();
  return Supabase.instance.client
      .from('price_records')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .map(
        (rows) => rows
            .whereType<Map>()
            .map((row) => mapper.fromMap(Map<String, dynamic>.from(row)))
            .toList(),
      );
});
