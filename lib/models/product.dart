class Product {
  Product({
    this.id,
    required this.name,
    this.categoryTag,
    this.imagePath,
  });

  final int? id;
  final String name;
  final String? categoryTag;
  final String? imagePath;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_tag': categoryTag,
      'image_path': imagePath,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      categoryTag: map['category_tag'] as String?,
      imagePath: map['image_path'] as String?,
    );
  }
}
