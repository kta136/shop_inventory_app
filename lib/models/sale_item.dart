// lib/models/sale_item.dart

class SaleItem {
  String saleItemId; // Primary Key, unique identifier
  String saleRecordId; // Foreign Key referencing SaleRecord
  String productId; // Foreign Key referencing Product
  String itemNameSnapshot; // Name of the product at the time of sale
  int quantity; // Quantity sold in this transaction
  double unitPrice; // Actual price per unit for this sale
  double lineTotal; // Calculated: quantity * unitPrice

  SaleItem({
    required this.saleItemId,
    required this.saleRecordId,
    required this.productId,
    required this.itemNameSnapshot,
    required this.quantity,
    required this.unitPrice,
  }) : lineTotal = quantity * unitPrice; // Calculate lineTotal on creation

  // Add fromMap and toMap if needed for direct DB storage,
  // though often SaleItems are handled as part of SaleRecord
  Map<String, dynamic> toMap() {
    return {
      'saleItemId': saleItemId,
      'saleRecordId': saleRecordId,
      'productId': productId,
      'itemNameSnapshot': itemNameSnapshot,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal, // Usually calculated, but might store
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      saleItemId: map['saleItemId'] as String,
      saleRecordId: map['saleRecordId'] as String,
      productId: map['productId'] as String,
      itemNameSnapshot: map['itemNameSnapshot'] as String,
      quantity: map['quantity'] as int,
      unitPrice: map['unitPrice'] as double,
      // lineTotal will be recalculated by constructor
    );
  }
}
