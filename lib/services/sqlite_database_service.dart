// lib/services/sqlite_database_service.dart

import 'dart:async'; // For Future
import 'dart:io'; // For Platform checks if needed later

import 'package:path/path.dart'; // Correction: Import directly
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart'; // Import Uuid

import '../models/product.dart';
import '../models/sale_item.dart';
import '../models/sale_record.dart';
import 'database_service.dart'; // Import the interface

class SQLiteDatabaseService implements DatabaseService {
  // Singleton pattern to ensure only one DB instance
  // static final SQLiteDatabaseService _instance = SQLiteDatabaseService._internal();
  // factory SQLiteDatabaseService() => _instance;
  // SQLiteDatabaseService._internal();
  // Note: Singletons can make testing harder. Consider dependency injection later.

  Database? _database; // Make the database instance nullable
  final String _dbName = 'shop_inventory.db';
  final _uuid = Uuid(); // Instance of Uuid generator

  // Table names
  final String _productTable = 'products';
  final String _saleRecordTable = 'sale_records';
  final String _saleItemTable = 'sale_items';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // --- Database Initialization ---
  @override
  Future<void> initDatabase() async {
    // The getter `database` handles initialization
    await database;
    print("Database Initialized");
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), _dbName);
    print("Database path: $path"); // Good for debugging

    return await openDatabase(
      path,
      version: 1, // Increment version on schema changes
      onCreate: _onCreate,
      // onUpgrade: _onUpgrade, // Define later if schema evolves
    );
  }

  // --- Create Tables ---
  Future<void> _onCreate(Database db, int version) async {
    // Use batch for multiple operations
    var batch = db.batch();

    // Products Table
    batch.execute('''
      CREATE TABLE $_productTable (
        productId TEXT PRIMARY KEY,
        itemName TEXT NOT NULL UNIQUE,
        currentStock INTEGER NOT NULL DEFAULT 0,
        defaultUnitPrice REAL NOT NULL DEFAULT 0.0
      )
    ''');
    print("Created $_productTable table");

    // Sale Records Table
    batch.execute('''
      CREATE TABLE $_saleRecordTable (
        recordId TEXT PRIMARY KEY,
        saleDate TEXT NOT NULL,
        processedTimestamp TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        entryMethod TEXT NOT NULL
      )
    ''');
    print("Created $_saleRecordTable table");

    // Sale Items Table (Links SaleRecord and Product)
    batch.execute('''
      CREATE TABLE $_saleItemTable (
        saleItemId TEXT PRIMARY KEY,
        saleRecordId TEXT NOT NULL,
        productId TEXT NOT NULL,
        itemNameSnapshot TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unitPrice REAL NOT NULL,
        lineTotal REAL NOT NULL,
        FOREIGN KEY (saleRecordId) REFERENCES $_saleRecordTable(recordId) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES $_productTable(productId) ON DELETE RESTRICT
      )
    ''');
    print("Created $_saleItemTable table");

    // Add indexes for frequently queried columns (optional but good practice)
    batch.execute('CREATE INDEX idx_sale_date ON $_saleRecordTable(saleDate)');
    batch.execute(
      'CREATE INDEX idx_sale_item_record ON $_saleItemTable(saleRecordId)',
    );
    batch.execute(
      'CREATE INDEX idx_sale_item_product ON $_saleItemTable(productId)',
    );

    await batch.commit(noResult: true); // Commit all creation statements
    print("Database schema created.");
  }

  // --- Product Operations ---
  @override
  Future<void> saveProduct(Product product) async {
    final db = await database;
    // Automatically handles insert or update based on PRIMARY KEY conflict
    await db.insert(
      _productTable,
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteProduct(String productId) async {
    final db = await database;
    await db.delete(
      _productTable,
      where: 'productId = ?',
      whereArgs: [productId],
    );
  }

  @override
  Future<List<Product>> getAllProductsFromDb() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _productTable,
      orderBy: 'itemName',
    );
    return List.generate(maps.length, (i) {
      return Product.fromMap(maps[i]);
    });
  }

  @override
  Future<Product?> getProductByIdFromDb(String productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _productTable,
      where: 'productId = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<void> updateStockInDb(String productId, int newStockLevel) async {
    final db = await database;
    await db.update(
      _productTable,
      {'currentStock': newStockLevel}, // Map with only the column to update
      where: 'productId = ?',
      whereArgs: [productId],
    );
  }

  // --- SaleRecord Operations ---
  @override
  Future<void> saveSaleRecord(SaleRecord record) async {
    final db = await database;
    // Use a transaction to ensure atomicity (all or nothing)
    await db.transaction((txn) async {
      // 1. Insert the SaleRecord itself
      var recordMap = {
        'recordId': record.recordId,
        // Store dates as ISO8601 strings (TEXT) for better compatibility
        'saleDate': record.saleDate.toIso8601String(),
        'processedTimestamp': record.processedTimestamp.toIso8601String(),
        'totalAmount': record.totalAmount,
        'entryMethod': record.entryMethod,
      };
      await txn.insert(
        _saleRecordTable,
        recordMap,
        conflictAlgorithm: ConflictAlgorithm.replace, // In case we resave
      );

      // 2. Insert each SaleItem linked to this SaleRecord
      for (var item in record.itemsSold) {
        // Ensure each SaleItem has a unique ID (if not already set)
        // It's better practice to assign IDs *before* calling saveSaleRecord
        // String saleItemId = item.saleItemId ?? _uuid.v4();

        await txn.insert(
          _saleItemTable,
          item.toMap(), // Use the SaleItem's toMap method
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    print(
      "Saved SaleRecord ${record.recordId} and ${record.itemsSold.length} items.",
    );
  }

  @override
  Future<void> deleteSaleRecord(String recordId) async {
    final db = await database;
    // Use a transaction for safety, though cascade should handle items
    await db.transaction((txn) async {
      // Deleting the SaleRecord will automatically delete associated SaleItems
      // due to the 'ON DELETE CASCADE' foreign key constraint.
      await txn.delete(
        _saleRecordTable,
        where: 'recordId = ?',
        whereArgs: [recordId],
      );
    });
    print("Deleted SaleRecord $recordId and associated items.");
  }

  @override
  Future<List<SaleRecord>> getSalesRecordsFromDb(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    // Format dates for SQL comparison (assuming dates stored as ISO8601 strings)
    // Ensure endDate includes the whole day if needed, e.g., by adding 23:59:59
    String startStr = startDate.toIso8601String();
    // Adjust endDate to include the entire day
    DateTime endOfDay = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );
    String endStr = endOfDay.toIso8601String();

    final List<Map<String, dynamic>> recordMaps = await db.query(
      _saleRecordTable,
      where: 'saleDate >= ? AND saleDate <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'saleDate DESC', // Or ASC as needed
    );

    List<SaleRecord> records = [];
    for (var recordMap in recordMaps) {
      // For each record, fetch its associated items
      final List<Map<String, dynamic>> itemMaps = await db.query(
        _saleItemTable,
        where: 'saleRecordId = ?',
        whereArgs: [recordMap['recordId'] as String],
      );

      List<SaleItem> items =
          itemMaps.map((itemMap) => SaleItem.fromMap(itemMap)).toList();

      records.add(
        SaleRecord(
          recordId: recordMap['recordId'] as String,
          // Parse dates back from ISO8601 string
          saleDate: DateTime.parse(recordMap['saleDate'] as String),
          processedTimestamp: DateTime.parse(
            recordMap['processedTimestamp'] as String,
          ),
          totalAmount: recordMap['totalAmount'] as double,
          entryMethod: recordMap['entryMethod'] as String,
          itemsSold: items, // Assign the fetched items
        ),
      );
    }
    return records;
  }

  // --- Close Database ---
  @override
  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null; // Reset the instance variable
      print("Database closed.");
    }
  }
}
