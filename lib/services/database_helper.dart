import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/price_record.dart';
import '../models/product.dart';
import '../models/shop.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kurabe.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category_tag TEXT,
            image_path TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE shops(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            latitude REAL,
            longitude REAL
          );
        ''');

        await db.execute('''
          CREATE TABLE price_records(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            shop_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            input_price REAL NOT NULL,
            is_tax_included INTEGER NOT NULL,
            tax_rate REAL NOT NULL,
            final_price REAL NOT NULL,
            FOREIGN KEY(product_id) REFERENCES products(id),
            FOREIGN KEY(shop_id) REFERENCES shops(id)
          );
        ''');
      },
    );
  }

  Future<Product?> getProductByName(String name) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'LOWER(name) = ?',
      whereArgs: [name.toLowerCase()],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return db.insert('products', product.toMap());
  }

  Future<int> insertShop(Shop shop) async {
    final db = await database;
    return db.insert('shops', shop.toMap());
  }

  Future<Shop?> getShopByName(String name) async {
    final db = await database;
    final result = await db.query(
      'shops',
      where: 'LOWER(name) = ?',
      whereArgs: [name.toLowerCase()],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Shop.fromMap(result.first);
  }

  Future<Shop?> getShopById(int id) async {
    final db = await database;
    final result = await db.query('shops', where: 'id = ?', whereArgs: [id], limit: 1);
    if (result.isEmpty) return null;
    return Shop.fromMap(result.first);
  }

  Future<int> insertPriceRecord(PriceRecord record) async {
    final db = await database;
    return db.insert('price_records', record.toMap());
  }

  Future<List<Map<String, dynamic>>> fetchRecentRecords({String? query}) async {
    final db = await database;
    final whereClause = query != null && query.isNotEmpty ? 'WHERE p.name LIKE ?' : '';
    final whereArgs = query != null && query.isNotEmpty ? ['%$query%'] : null;

    final result = await db.rawQuery('''
      SELECT pr.*, p.name as product_name, p.category_tag, p.image_path, s.name as shop_name
      FROM price_records pr
      JOIN products p ON pr.product_id = p.id
      JOIN shops s ON pr.shop_id = s.id
      $whereClause
      ORDER BY pr.date DESC
      LIMIT 50
    ''', whereArgs);

    return result;
  }

  Future<List<PriceRecord>> fetchHistoryForProduct(int productId) async {
    final db = await database;
    final result = await db.query(
      'price_records',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'date DESC',
    );
    return result.map(PriceRecord.fromMap).toList();
  }
}
