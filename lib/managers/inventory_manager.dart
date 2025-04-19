// lib/managers/inventory_manager.dart

import 'package:uuid/uuid.dart'; // For generating IDs

import '../models/product.dart';
import '../services/database_service.dart'; // Use the interface

class InventoryManager {
  final DatabaseService _dbService; // Dependency on the database service
  final _uuid = Uuid(); // UUID generator

  List<Product> _productsCache = []; // In-memory cache for products

  // Constructor requires a DatabaseService instance (Dependency Injection)
  InventoryManager(this._dbService);

  // --- Initialization ---
  // Needs to be called once, e.g., during app startup
  Future<void> loadInventory() async {
    _productsCache = await _dbService.getAllProductsFromDb();
    print("Inventory loaded with ${_productsCache.length} products.");
  }

  // --- Product Access ---
  List<Product> getAllProducts() {
    // Returns the current state of the cache
    return List.unmodifiable(_productsCache); // Return unmodifiable list
  }

  Future<Product?> getProductById(String productId) async {
    // Try cache first
    Product? cachedProduct = _productsCache.firstWhere(
      (p) => p.productId == productId,
      orElse:
          () => Product(
            productId: '',
            itemName: '',
            currentStock: -1,
            defaultUnitPrice: -1,
          ),
    ); // Dummy product for comparison

    // Check if the dummy product was returned
    if (cachedProduct.productId.isNotEmpty) {
      return cachedProduct;
    }

    // If not in cache, fetch from DB (might indicate cache is stale or product just added)
    // Note: This DB call might be redundant if loadInventory is guaranteed to run first
    print("Product $productId not found in cache, fetching from DB.");
    final productFromDb = await _dbService.getProductByIdFromDb(productId);
    if (productFromDb != null &&
        !_productsCache.any((p) => p.productId == productId)) {
      _productsCache.add(productFromDb); // Add to cache if newly found
    }
    return productFromDb;
  }

  Product? findProductByName(String name) {
    try {
      // Case-insensitive search might be useful, but requires normalization or different query
      return _productsCache.firstWhere(
        (p) => p.itemName.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      // firstWhere throws if no element is found
      print("Product with name '$name' not found in cache.");
      return null;
    }
  }

  // --- Product Modification ---
  Future<Product> addProduct({
    required String name,
    required int initialStock,
    required double defaultPrice,
  }) async {
    // Check if product with the same name already exists (optional, based on requirements)
    if (findProductByName(name) != null) {
      throw Exception('Product with name "$name" already exists.');
    }

    final newProduct = Product(
      productId: _uuid.v4(), // Generate unique ID
      itemName: name.trim(), // Trim whitespace
      currentStock: initialStock,
      defaultUnitPrice: defaultPrice,
    );

    await _dbService.saveProduct(newProduct); // Save to DB
    _productsCache.add(newProduct); // Add to cache
    print("Added product: ${newProduct.itemName}");
    return newProduct;
  }

  Future<void> updateProduct(Product updatedProduct) async {
    // Find the index of the product in the cache
    final index = _productsCache.indexWhere(
      (p) => p.productId == updatedProduct.productId,
    );

    if (index != -1) {
      await _dbService.saveProduct(updatedProduct); // Save changes to DB
      _productsCache[index] = updatedProduct; // Update cache
      print("Updated product: ${updatedProduct.itemName}");
    } else {
      print(
        "Error: Product with ID ${updatedProduct.productId} not found for update.",
      );
      throw Exception('Product not found for update.'); // Or handle differently
    }
  }

  Future<void> deleteProduct(String productId) async {
    // Optionally check if product is part of any SaleItem before deleting (using SalesManager?)
    // Our DB schema uses ON DELETE RESTRICT, so DB will prevent deletion if referenced.

    final index = _productsCache.indexWhere((p) => p.productId == productId);
    if (index != -1) {
      try {
        await _dbService.deleteProduct(productId); // Delete from DB
        _productsCache.removeAt(index); // Remove from cache
        print("Deleted product with ID: $productId");
      } catch (e) {
        // Catch potential exceptions (like foreign key constraint) from DB
        print("Error deleting product $productId: $e");
        // Re-throw or handle as appropriate for the UI
        throw Exception(
          "Could not delete product. It might be used in existing sales records.",
        );
      }
    } else {
      print("Error: Product with ID $productId not found for deletion.");
      throw Exception('Product not found for deletion.');
    }
  }

  // --- Stock Management ---
  Future<bool> decreaseStock(String productId, int quantitySold) async {
    if (quantitySold <= 0) {
      return false; // Cannot sell zero or negative quantity
    }

    final index = _productsCache.indexWhere((p) => p.productId == productId);
    if (index != -1) {
      final product = _productsCache[index];
      if (product.currentStock >= quantitySold) {
        final newStock = product.currentStock - quantitySold;
        await _dbService.updateStockInDb(
          productId,
          newStock,
        ); // Update DB first
        // Update the product object in the cache directly
        _productsCache[index].currentStock = newStock;
        print(
          "Decreased stock for ${product.itemName} by $quantitySold. New stock: $newStock",
        );
        return true; // Success
      } else {
        print(
          "Error: Insufficient stock for ${product.itemName}. Available: ${product.currentStock}, Required: $quantitySold",
        );
        return false; // Insufficient stock
      }
    } else {
      print("Error: Product with ID $productId not found for stock decrease.");
      return false; // Product not found
    }
  }

  Future<bool> increaseStock(String productId, int quantityAdded) async {
    if (quantityAdded <= 0) {
      return false; // Cannot add zero or negative quantity
    }

    final index = _productsCache.indexWhere((p) => p.productId == productId);
    if (index != -1) {
      final product = _productsCache[index];
      final newStock = product.currentStock + quantityAdded;
      await _dbService.updateStockInDb(productId, newStock); // Update DB first
      _productsCache[index].currentStock = newStock; // Update cache
      print(
        "Increased stock for ${product.itemName} by $quantityAdded. New stock: $newStock",
      );
      return true; // Success
    } else {
      print("Error: Product with ID $productId not found for stock increase.");
      return false; // Product not found
    }
  }
}
