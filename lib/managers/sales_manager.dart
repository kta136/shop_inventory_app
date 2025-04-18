// lib/managers/sales_manager.dart

import 'package:uuid/uuid.dart'; // For generating IDs

// Import necessary models and services
import '../models/product.dart';
import '../models/sale_item.dart';
import '../models/sale_record.dart';
import '../services/database_service.dart';
import 'inventory_manager.dart'; // Import InventoryManager

// Define a type alias for cleaner input structure for items to be sold
typedef SaleInputItem = ({String productId, int quantity, double unitPrice});

class SalesManager {
  final DatabaseService _dbService;
  final InventoryManager _inventoryManager; // Dependency on InventoryManager
  final _uuid = Uuid();

  // Constructor requires instances of DatabaseService and InventoryManager
  SalesManager(this._dbService, this._inventoryManager);

  // --- Create Sales Record ---
  /// Creates and saves a new sales record.
  ///
  /// Takes a list of items sold, validates stock, decreases stock via
  /// InventoryManager, calculates totals, and saves the record via DatabaseService.
  /// Throws exceptions if products are not found or stock is insufficient.
  Future<SaleRecord> createSaleRecord({
    required DateTime saleDate,
    required List<SaleInputItem> itemsToSell, // Use the defined type alias
    required String entryMethod, // "MANUAL" or "OCR"
  }) async {
    if (itemsToSell.isEmpty) {
      throw ArgumentError('Cannot create a sale with no items.');
    }

    final List<SaleItem> preparedSaleItems = [];
    double calculatedTotalAmount = 0;
    final List<Future<bool>> stockDecreaseFutures =
        []; // To track stock decreases

    final String recordId = _uuid.v4(); // Generate ID for the SaleRecord
    final DateTime processedTimestamp =
        DateTime.now(); // Timestamp for processing

    // --- Phase 1: Validate items and prepare SaleItem objects ---
    for (final itemInput in itemsToSell) {
      if (itemInput.quantity <= 0 || itemInput.unitPrice < 0) {
        throw ArgumentError(
          'Invalid quantity or price for product ID ${itemInput.productId}.',
        );
      }

      // Find the product using InventoryManager to get latest details
      final Product? product = await _inventoryManager.getProductById(
        itemInput.productId,
      );

      if (product == null) {
        throw Exception('Product not found with ID: ${itemInput.productId}');
      }

      // Create the SaleItem object for this line item
      final saleItem = SaleItem(
        saleItemId: _uuid.v4(), // Generate unique ID for the item
        saleRecordId: recordId, // Link to the parent sale record
        productId: product.productId,
        itemNameSnapshot: product.itemName, // Snapshot name at time of sale
        quantity: itemInput.quantity,
        unitPrice: itemInput.unitPrice,
        // lineTotal is calculated automatically in the constructor
      );

      preparedSaleItems.add(saleItem);
      calculatedTotalAmount += saleItem.lineTotal;
    }

    // --- Phase 2: Attempt to decrease stock for all items BEFORE saving sale ---
    // This makes it less likely to save a sale if stock runs out, but isn't
    // fully atomic across InventoryManager and SalesManager DB operations without
    // a more complex transaction strategy involving both managers/tables.
    List<String> failedStockProductNames = [];
    for (final item in preparedSaleItems) {
      bool stockDecreased = await _inventoryManager.decreaseStock(
        item.productId,
        item.quantity,
      );
      if (!stockDecreased) {
        // Try to find the product name for a better error message
        final product = await _inventoryManager.getProductById(item.productId);
        failedStockProductNames.add(product?.itemName ?? item.productId);
      }
    }

    // If any stock decrease failed, abort the sale creation
    if (failedStockProductNames.isNotEmpty) {
      // IMPORTANT: We should ideally roll back any stock decreases that *did* succeed
      // in this loop, but that adds complexity. For now, we just report the error.
      // A true transactional approach across managers is advanced.
      print(
        "Sale aborted due to insufficient stock for: ${failedStockProductNames.join(', ')}",
      );
      throw Exception(
        'Insufficient stock for: ${failedStockProductNames.join(', ')}',
      );
    }

    // --- Phase 3: Create the SaleRecord object ---
    final newSaleRecord = SaleRecord(
      recordId: recordId,
      saleDate: saleDate,
      processedTimestamp: processedTimestamp,
      itemsSold: preparedSaleItems,
      totalAmount: calculatedTotalAmount,
      entryMethod: entryMethod,
    );

    // --- Phase 4: Save the finalized SaleRecord (and its items) to the database ---
    try {
      await _dbService.saveSaleRecord(newSaleRecord);
      print("SaleRecord ${newSaleRecord.recordId} created successfully.");
      return newSaleRecord;
    } catch (e) {
      print(
        "Error saving SaleRecord ${newSaleRecord.recordId} to database: $e",
      );
      // If saving fails, we have a potential inconsistency: stock was decreased
      // but the sale wasn't recorded. This highlights the limitation of the
      // current non-atomic approach across managers.
      // Consider adding compensating logic here (e.g., try to increase stock back).
      throw Exception(
        'Failed to save sale record to database after attempting stock decrease.',
      );
    }
  }

  // --- Retrieve Sales History ---
  Future<List<SaleRecord>> getSalesHistory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Directly delegate to the database service
    return await _dbService.getSalesRecordsFromDb(startDate, endDate);
  }

  // --- Calculate Total Sales ---
  Future<double> calculateTotalSales(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final List<SaleRecord> records = await getSalesHistory(startDate, endDate);
    double total = 0;
    for (final record in records) {
      total += record.totalAmount;
    }
    return total;
  }

  // --- ADD DELETE SALE RECORD ---
  /// Deletes a specific sales record and its associated items.
  /// Note: This does NOT automatically adjust inventory stock back.
  Future<void> deleteSaleRecord(String recordId) async {
    try {
      await _dbService.deleteSaleRecord(recordId);
      // Consider if any other logic is needed here (e.g., logging)
      print("SalesManager deleted SaleRecord: $recordId");
    } catch (e) {
      print("SalesManager Error deleting SaleRecord $recordId: $e");
      // Re-throw the error to be handled by the UI
      throw Exception("Failed to delete sale record: ${e.toString()}");
    }
    // Potential Future Enhancement: Option to revert inventory changes.
    // This would require fetching the SaleItems *before* deletion and calling
    // inventoryManager.increaseStock for each item. This adds complexity.
  }
}
