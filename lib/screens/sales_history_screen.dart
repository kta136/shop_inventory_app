// lib/screens/sales_history_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting dates and currency
import 'package:provider/provider.dart';

import '../managers/sales_manager.dart'; // Import SalesManager
import '../models/sale_record.dart';
// Import SaleItem for details dialog


class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  // State variables
  DateTimeRange? _selectedDateRange; // Nullable initially
  List<SaleRecord> _salesRecords = [];
  double _totalSales = 0.0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize with a default date range (e.g., this month) and fetch data
    _setDefaultDateRangeAndFetch();
  }

  // Sets a default range (e.g., current month) and triggers initial fetch
  void _setDefaultDateRangeAndFetch() {
    final now = DateTime.now();
    // Default to the start of the current month until today
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    // Use WidgetsBinding to ensure context is available if needed later
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Check if mounted before setState
        setState(() {
          _selectedDateRange = DateTimeRange(start: startOfMonth, end: endOfToday);
        });
        // Fetch data for the default range
        _fetchSalesData();
      }
    });
  }


  // Function to show Date Range Picker
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      // Use current range as initial if available, otherwise default
      initialDateRange: _selectedDateRange ?? DateTimeRange(
         start: DateTime.now().subtract(const Duration(days: 7)), // Default to last 7 days if null
         end: DateTime.now(),
      ),
      firstDate: DateTime(2020), // Adjust as needed
      lastDate: DateTime.now().add(const Duration(days: 1)), // Allow up to tomorrow
      helpText: 'Select Sales Date Range', // Customize dialog text
      saveText: 'Apply',
    );

    if (picked != null && picked != _selectedDateRange) {
      // Ensure end date includes the whole day for querying
       final adjustedEnd = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
       final adjustedRange = DateTimeRange(start: picked.start, end: adjustedEnd);

      if (mounted) { // Check if mounted before setState
         setState(() {
           _selectedDateRange = adjustedRange;
         });
         // Fetch data for the newly selected range
         _fetchSalesData();
      }
    }
  }

  // Function to fetch sales data based on the selected range
  Future<void> _fetchSalesData() async {
    if (_selectedDateRange == null || !mounted) {
       setState(() {
         _errorMessage = "Please select a date range.";
         _salesRecords = [];
         _totalSales = 0.0;
       });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    try {
      final salesManager = Provider.of<SalesManager>(context, listen: false);
      // Fetch both records and total sales concurrently using Future.wait
      final results = await Future.wait([
        salesManager.getSalesHistory(_selectedDateRange!.start, _selectedDateRange!.end),
        salesManager.calculateTotalSales(_selectedDateRange!.start, _selectedDateRange!.end),
      ]);

      if (!mounted) return; // Check mounted again after await

      setState(() {
        // Type casting needed as Future.wait returns List<Object>
        _salesRecords = results[0] as List<SaleRecord>;
        _totalSales = results[1] as double;
      });

    } catch (e) {
      print("Error fetching sales history: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load sales history: ${e.toString()}";
          _salesRecords = [];
          _totalSales = 0.0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Delete Sale Record Logic ---
  Future<void> _deleteSaleRecord(SaleRecord record) async {
    if (!mounted) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the sale record from ${DateFormat.yMMMd().format(record.saleDate)}?\n\nThis action cannot be undone and inventory will NOT be automatically restocked.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), // Return false
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.of(ctx).pop(true), // Return true
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    // If confirmed, proceed with deletion
    if (confirm == true && mounted) {
      setState(() { _isLoading = true; }); // Show loading indicator while deleting

      try {
        final salesManager = Provider.of<SalesManager>(context, listen: false);
        await salesManager.deleteSaleRecord(record.recordId);

        // Refresh data after successful deletion
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale record deleted successfully.'), backgroundColor: Colors.green),
          );
          // Refetch data to update list and total (which implicitly sets isLoading = false)
          await _fetchSalesData();
        }
      } catch (e) {
        print("Error deleting sale record: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting sale: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
          );
          // Hide loading indicator if error occurs during delete itself
          setState(() { _isLoading = false; });
        }
      }
      // Note: _isLoading will be set to false by the _fetchSalesData call if deletion was successful
    }
  }
  // --- END Delete Sale Record Logic ---


  // --- Show Sale Details Dialog ---
   void _showSaleDetailsDialog(SaleRecord record) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              title: Text('Sale Details (${DateFormat.yMMMd().format(record.saleDate)})'),
              // Make content scrollable if many items
              content: SizedBox(
                  width: double.maxFinite, // Use available width
                  // Constrain height to prevent overly tall dialogs
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: ListView.builder(
                      shrinkWrap: true, // Allow shrinking within SizedBox
                      itemCount: record.itemsSold.length,
                      itemBuilder: (itemCtx, itemIndex) {
                         final item = record.itemsSold[itemIndex];
                         return ListTile(
                             dense: true, // Make items compact
                             title: Text(item.itemNameSnapshot),
                             // Updated currency format
                             subtitle: Text('${item.quantity} x ${NumberFormat.currency(symbol: '₹ ', locale: 'en_IN').format(item.unitPrice)}'),
                             // Updated currency format
                             trailing: Text(NumberFormat.currency(symbol: '₹ ', locale: 'en_IN').format(item.lineTotal)),
                         );
                      },
                  ),
              ),
              actions: [ TextButton(child: Text('Close'), onPressed: () => Navigator.of(ctx).pop()) ],
          ),
      );
   }

  @override
  Widget build(BuildContext context) {
    // Optional: Add Actions/Shortcuts wrapper here if needed
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
           IconButton( // Refresh button
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Data',
              onPressed: _isLoading ? null : _fetchSalesData, // Disable while loading
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Date Range Selection and Total Display Row ---
            _buildHeaderRow(context),
            const SizedBox(height: 16.0),
            const Divider(thickness: 1),

            // --- Loading / Error / Content Area ---
            Expanded(child: _buildContentArea()),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  // Builds the top row with Date Range button and Total Sales
  Widget _buildHeaderRow(BuildContext context) {
    final DateFormat formatter = DateFormat.yMd(); // Short date format
    final String rangeText = _selectedDateRange == null
        ? 'Select Range'
        : '${formatter.format(_selectedDateRange!.start)} - ${formatter.format(_selectedDateRange!.end)}';

    return Card( // Wrap header for better visual structure
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
         padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
         child: Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
              // Date Range Button
              TextButton.icon(
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
                label: Text(rangeText, style: Theme.of(context).textTheme.titleSmall),
                onPressed: () => _selectDateRange(context),
                style: TextButton.styleFrom(
                   foregroundColor: Theme.of(context).colorScheme.primary,
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              const SizedBox(width: 16), // Spacer
              // Total Sales Display
              Column(
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                    Text('Total Sales:', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                       // Updated currency format
                       NumberFormat.currency(symbol: '₹ ', locale: 'en_IN').format(_totalSales),
                       style: Theme.of(context).textTheme.titleMedium?.copyWith(
                         fontWeight: FontWeight.bold,
                         color: Theme.of(context).colorScheme.primary,
                       ),
                    ),
                 ],
              ),
           ],
         ),
      ),
    );
  }

  // Builds the main content area based on state (Loading, Error, List, Empty)
  Widget _buildContentArea() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      // Display error message with a retry button
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
               const SizedBox(height: 16),
               Text(
                 _errorMessage!,
                 style: TextStyle(color: Theme.of(context).colorScheme.error),
                 textAlign: TextAlign.center,
               ),
                const SizedBox(height: 16),
               ElevatedButton.icon(
                   onPressed: _fetchSalesData, // Retry button
                   icon: const Icon(Icons.refresh),
                   label: const Text("Retry")
                )
            ],
          ),
        ),
      );
    }
    if (_salesRecords.isEmpty) {
      // Display message if no sales records found
      return const Center(
        child: Text(
          'No sales records found for the selected date range.',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Display the list of sales records
    return ListView.builder(
      itemCount: _salesRecords.length,
      itemBuilder: (context, index) {
        final record = _salesRecords[index];
        // Display each record in a Card
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: CircleAvatar(
                // Show index number (descending for recent first if list is sorted that way)
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                // Show index number (descending for recent first if list is sorted that way)
                child: Text('${_salesRecords.length - index}'),
            ),
            title: Text('Sale on ${DateFormat.yMMMd().format(record.saleDate)}'), // Formatted date
            subtitle: Text('${record.itemsSold.length} Item(s) | Entry: ${record.entryMethod}'),
            trailing: Row( // Use Row for Total Amount and Actions Menu
               mainAxisSize: MainAxisSize.min,
               children: [
                  // Total Amount for the sale
                  Text(
                     // Updated currency format
                     NumberFormat.currency(symbol: '₹ ', locale: 'en_IN').format(record.totalAmount),
                     style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8), // Spacing
                  // More Actions Menu (View/Delete)
                  PopupMenuButton<String>(
                     icon: const Icon(Icons.more_vert),
                     tooltip: 'More actions',
                     onSelected: (String result) {
                        // Handle menu item selection
                        switch (result) {
                           case 'view':
                              _showSaleDetailsDialog(record); // Show items dialog
                              break;
                           case 'delete':
                              _deleteSaleRecord(record); // Call delete function
                              break;
                         }
                      },
                     itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        // View Items option
                        const PopupMenuItem<String>(
                           value: 'view',
                           child: ListTile(leading: Icon(Icons.visibility_outlined), title: Text('View Items')),
                        ),
                        const PopupMenuDivider(), // Visual separator
                        // Delete Record option
                        PopupMenuItem<String>(
                           value: 'delete',
                           child: ListTile(
                              leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
                              title: Text('Delete Record', style: TextStyle(color: Theme.of(context).colorScheme.error))
                           ),
                        ),
                      ],
                  ),
               ],
            ),
            // Allow tapping the tile itself to view details quickly
            onTap: () => _showSaleDetailsDialog(record),
          ),
        );
      },
    );
  }

} // End of _SalesHistoryScreenState
