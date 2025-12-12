import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shopping_list_item.dart';

class ShoppingListService {
  ShoppingListService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  bool get isGuest => _client.auth.currentUser?.isAnonymous ?? true;
  String? get _userId => _client.auth.currentUser?.id;
  String? get _anonId => _client.auth.currentUser?.isAnonymous == true
      ? _client.auth.currentUser?.id
      : null;

  /// For guests, we store items locally in Supabase under a per-device pseudo user id
  /// (auth uid when anonymous). That allows syncing across sessions on the same device
  /// and seamless migration when they later sign in.

  Future<List<ShoppingListItem>> fetchItems() async {
    final userId = _userId ?? _anonId;
    if (userId == null) return [];

    final List<dynamic> rows = await _client
        .from('shopping_list_items')
        .select()
        .eq('user_id', userId)
        .order('is_done', ascending: true)
        .order('created_at', ascending: true);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ShoppingListItem.fromJson)
        .toList();
  }

  Future<ShoppingListItem> addItem(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('title cannot be empty');
    }
    final userId = _userId ?? _anonId;
    if (userId == null) {
      throw StateError('no user');
    }

    final data = await _client.from('shopping_list_items').insert({
      'title': trimmed,
      'is_done': false,
      'user_id': userId,
    }).select().maybeSingle();

    if (data == null) throw StateError('insert failed');
    return ShoppingListItem.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<void> toggleDone(ShoppingListItem item) async {
    await _client
        .from('shopping_list_items')
        .update({'is_done': !item.isDone})
        .eq('id', item.id);
  }

  Future<void> deleteItem(int id) async {
    await _client.from('shopping_list_items').delete().eq('id', id);
  }
}
