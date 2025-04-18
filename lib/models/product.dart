// lib/models/product.dart

class Product {
  String productId; // Primary Key, unique identifier (e.g., UUID)
  String itemName; // Canonical name, should be unique
  int currentStock; // Current quantity on hand
  double defaultUnitPrice; // Optional default price

  Product({
    required this.productId,
    required this.itemName,
    required this.currentStock,
    required this.defaultUnitPrice,
  });

  // Basic factory constructor for creating from a map (useful for DB interaction)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      productId: map['productId'] as String,
      itemName: map['itemName'] as String,
      currentStock: map['currentStock'] as int,
      defaultUnitPrice: map['defaultUnitPrice'] as double,
    );
  }

  // Basic method to convert to a map (useful for DB interaction)
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'itemName': itemName,
      'currentStock': currentStock,
      'defaultUnitPrice': defaultUnitPrice,
    };
  }
}
