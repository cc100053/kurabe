class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.title,
    required this.isDone,
    required this.createdAt,
  });

  final int id;
  final String title;
  final bool isDone;
  final DateTime createdAt;

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      id: json['id'] as int,
      title: (json['title'] as String).trim(),
      isDone: json['is_done'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  ShoppingListItem copyWith({
    int? id,
    String? title,
    bool? isDone,
    DateTime? createdAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
