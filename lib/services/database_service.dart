// lib/services/database_service.dart

import '../models/product.dart'; // Import necessary models
import '../models/sale_record.dart';

// Interface defining the contract for data persistence operations
abstract class DatabaseService {
  // Initialize the database connection and schema
  Future<void> initDatabase();

  // Product operations
  Future<void> saveProduct(Product product); // Handles both insert and update
  Future<void> deleteProduct(String productId);
  Future<List<Product>> getAllProductsFromDb();
  Future<Product?> getProductByIdFromDb(String productId);
  Future<void> updateStockInDb(String productId, int newStockLevel);

  // SaleRecord operations
  // Saves the record and its associated items (should be transactional)
  Future<void> saveSaleRecord(SaleRecord record);
  // Retrieves records within the date range, including their items
  Future<List<SaleRecord>> getSalesRecordsFromDb(
    DateTime startDate,
    DateTime endDate,
  );

  // Clean up resources
  Future<void> closeDatabase();
}
