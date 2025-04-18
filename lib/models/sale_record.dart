// lib/models/sale_record.dart

import 'sale_item.dart'; // Import SaleItem

class SaleRecord {
  String recordId; // Primary Key, unique identifier
  DateTime saleDate; // Date the sale occurred
  DateTime processedTimestamp; // Timestamp when the record was saved
  List<SaleItem> itemsSold; // List of items included in this sale
  double totalAmount; // The grand total for this sale
  String entryMethod; // "MANUAL" or "OCR"

  SaleRecord({
    required this.recordId,
    required this.saleDate,
    required this.processedTimestamp,
    required this.itemsSold,
    required this.totalAmount,
    required this.entryMethod,
  });

  // Note: fromMap and toMap for SaleRecord would be more complex
  // as they need to handle the list of SaleItems (e.g., store items
  // in a separate table or as JSON within the record).
  // We'll refine this when implementing the DatabaseService.
}
