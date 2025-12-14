import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';
import '../../models/shopping_list_item.dart';
import '../../services/shopping_list_service.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final ShoppingListService _service = ShoppingListService();
  final TextEditingController _controller = TextEditingController();

  List<ShoppingListItem> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _service.fetchItems();
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '読み込みに失敗しました。';
        _isLoading = false;
      });
    }
  }

  Future<void> _addItem() async {
    if (_isSaving) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showSnack('内容を入力してください');
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final newItem = await _service.addItem(text);
      setState(() {
        _items = [..._items, newItem];
        _controller.clear();
        _isSaving = false;
      });
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _showSnack('追加に失敗しました');
    }
  }

  Future<void> _toggleItem(ShoppingListItem item) async {
    final updated = item.copyWith(isDone: !item.isDone);
    setState(() {
      _items = _items.map((i) => i.id == updated.id ? updated : i).toList();
    });

    try {
      await _service.toggleDone(item);
    } catch (e) {
      // Revert on failure
      setState(() {
        _items = _items.map((i) => i.id == item.id ? item : i).toList();
      });
      _showSnack('更新に失敗しました');
    }
  }

  Future<void> _deleteItem(ShoppingListItem item) async {
    final original = List<ShoppingListItem>.from(_items);
    setState(() {
      _items = _items.where((i) => i.id != item.id).toList();
    });
    try {
      await _service.deleteItem(item.id);
    } catch (e) {
      setState(() {
        _items = original;
      });
      _showSnack('削除に失敗しました');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: KurabeColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(user),
              const SizedBox(height: 16),
              _buildInputCard(),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadItems,
                  child: _buildContent(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(User? user) {
    final name = user?.userMetadata?['name'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '買い物リスト',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: KurabeColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name != null ? '$name さんの買い出し予定' : '今日の買い出しをまとめましょう',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: KurabeColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KurabeColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      KurabeColors.primary,
                      KurabeColors.primaryLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: KurabeColors.primary.withAlpha(64),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  PhosphorIcons.checkSquare(PhosphorIconsStyle.bold),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '買うものを追加',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: KurabeColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addItem(),
                  decoration: InputDecoration(
                    hintText: '例）牛乳、パン、卵',
                    hintStyle: TextStyle(
                      color: KurabeColors.textTertiary,
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: KurabeColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: KurabeColors.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: KurabeColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: KurabeColors.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _addItem,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: KurabeColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          '追加',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(
            color: KurabeColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          _buildEmptyState(),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: KurabeColors.error.withAlpha(26),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              PhosphorIcons.trash(PhosphorIconsStyle.bold),
              color: KurabeColors.error,
            ),
          ),
          onDismissed: (_) => _deleteItem(item),
          child: _buildItemTile(item),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: _items.length,
      padding: const EdgeInsets.only(bottom: 120, top: 4),
    );
  }

  Widget _buildItemTile(ShoppingListItem item) {
    final dateLabel = DateFormat('M月d日').format(item.createdAt);
    return Container(
      decoration: BoxDecoration(
        color: KurabeColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isDone
              ? KurabeColors.primary.withAlpha(60)
              : KurabeColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleItem(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCheckCircle(item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: item.isDone
                            ? KurabeColors.textSecondary
                            : KurabeColors.textPrimary,
                        decoration:
                            item.isDone ? TextDecoration.lineThrough : null,
                        decorationColor: KurabeColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill),
                          size: 14,
                          color: KurabeColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: KurabeColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => _deleteItem(item),
                icon: Icon(
                  PhosphorIcons.trash(PhosphorIconsStyle.bold),
                  color: KurabeColors.textTertiary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckCircle(ShoppingListItem item) {
    return Container(
      height: 28,
      width: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: item.isDone
            ? const LinearGradient(
                colors: [
                  KurabeColors.primary,
                  KurabeColors.primaryLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: item.isDone ? null : KurabeColors.background,
        border: item.isDone
            ? null
            : Border.all(
                color: KurabeColors.border,
              ),
      ),
      child: Icon(
        item.isDone
            ? PhosphorIcons.check(PhosphorIconsStyle.bold)
            : PhosphorIcons.circle(PhosphorIconsStyle.regular),
        color: item.isDone ? Colors.white : KurabeColors.textTertiary,
        size: 16,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          height: 78,
          width: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: KurabeColors.primary.withAlpha(20),
          ),
          child: Icon(
            PhosphorIcons.shoppingCart(PhosphorIconsStyle.bold),
            color: KurabeColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'まだリストが空です',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: KurabeColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '買うものを追加して、今日の買い出しを管理しましょう。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: KurabeColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
