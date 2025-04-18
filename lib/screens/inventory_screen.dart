// lib/screens/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Shortcuts/Actions
import 'package:provider/provider.dart';

import '../managers/inventory_manager.dart';
import '../models/product.dart';
import 'add_edit_product_screen.dart'; // Screen for adding/editing

// --- Define Intent for New Product ---
// An Intent is just a marker class representing an intention to do something.
class NewProductIntent extends Intent {
  const NewProductIntent();
}
// --- End Intent Definition ---


class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  // --- Action Map for Inventory Screen ---
  // Maps Intent types to the actual Action that performs the work.
  late final Map<Type, Action<Intent>> _inventoryActions = <Type, Action<Intent>>{
    // When a NewProductIntent is received, execute a CallbackAction
    // which simply calls our existing _navigateToAddProduct method.
    NewProductIntent: CallbackAction<NewProductIntent>(
      onInvoke: (NewProductIntent intent) => _navigateToAddProduct(),
    ),
  };
  // --- End Action Definition ---

  // --- Shortcut Map for Inventory Screen ---
  // Maps specific key combinations (LogicalKeySet) to Intents.
  final Map<LogicalKeySet, Intent> _inventoryShortcuts = <LogicalKeySet, Intent>{
    // Map Ctrl + N to the NewProductIntent.
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const NewProductIntent(),
  };
  // --- End Shortcut Definition ---


  @override
  void initState() {
    super.initState();
    // Fetch products after the first frame is built to ensure context is ready for Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProducts();
    });
  }

  // Fetches products from the manager and updates the state
  Future<void> _fetchProducts({bool showLoading = true}) async {
    if (!mounted) return; // Check if the widget is still in the tree
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final inventoryManager = Provider.of<InventoryManager>(context, listen: false);
      List<Product> fetchedProducts = inventoryManager.getAllProducts();
      // Create a new modifiable list for sorting
      List<Product> modifiableProducts = List.from(fetchedProducts);
      // Sort the modifiable list alphabetically by item name (case-insensitive)
      modifiableProducts.sort((a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()));
      _products = modifiableProducts; // Assign the sorted list to the state
    } catch (e, s) {
      print("Error fetching products: $e");
      print("Stack trace: $s");
      _errorMessage = "Error loading products.";
    } finally {
      // Ensure setState is called only if the widget is still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Navigates to the AddEditProductScreen for adding a new product
  void _navigateToAddProduct() async {
    if (!mounted) return;
    final result = await Navigator.push<bool>( // Expect a boolean result (true if saved)
      context,
      MaterialPageRoute(builder: (context) => const AddEditProductScreen()),
    );
    // If the AddEdit screen indicated a save happened, refresh the list
    if (result == true && mounted) {
      _fetchProducts(showLoading: false); // Refresh without full loading indicator
    }
  }

  // Navigates to the AddEditProductScreen for editing an existing product
  void _navigateToEditProduct(Product product) async {
     if (!mounted) return;
     final result = await Navigator.push<bool>(
       context,
       MaterialPageRoute(builder: (context) => AddEditProductScreen(productToEdit: product)), // Pass product
     );
     if (result == true && mounted) {
       _fetchProducts(showLoading: false); // Refresh list if changes were saved
     }
   }

   // Handles deleting a product after confirmation
   Future<void> _deleteProduct(Product product) async {
      if (!mounted) return;
      final inventoryManager = Provider.of<InventoryManager>(context, listen: false);

      // Show confirmation dialog before deleting
      final confirm = await showDialog<bool>(
         context: context,
         builder: (BuildContext ctx) {
           return AlertDialog(
             title: const Text('Confirm Deletion'),
             content: Text('Are you sure you want to delete "${product.itemName}"? This action cannot be undone.'),
             actions: <Widget>[
               TextButton(
                 onPressed: () => Navigator.of(ctx).pop(false), // Return false if cancelled
                 child: const Text('Cancel'),
               ),
               TextButton(
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), // Use theme error color
                 onPressed: () => Navigator.of(ctx).pop(true), // Return true if confirmed
                 child: const Text('Delete'),
               ),
             ],
           );
         },
       );

      // Proceed with deletion only if confirmed
      if (confirm == true && mounted) {
         try {
            await inventoryManager.deleteProduct(product.productId);
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('"${product.itemName}" deleted successfully.'))
            );
            _fetchProducts(showLoading: false); // Refresh list after deletion
         } catch (e) {
            // Show error message if deletion fails (e.g., due to foreign key constraint)
            print("Error deleting product: $e");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting product: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error)
            );
         }
      }
   }


  @override
  Widget build(BuildContext context) {
    // Wrap the Scaffold with Actions, Shortcuts, and FocusScope
    // Actions: Makes the defined actions available in this part of the widget tree.
    // Shortcuts: Maps key combinations to the intents defined above.
    // FocusScope: Helps ensure that the shortcuts are captured even if a specific
    //             element like the ListView or a TextField has focus.
    return Actions(
      actions: _inventoryActions, // Provide the actions map
      child: Shortcuts(
        shortcuts: _inventoryShortcuts, // Provide the shortcuts map
        child: FocusScope( // Ensure shortcuts work regardless of focus
          autofocus: true, // Automatically focus this scope when built
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Inventory Management'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                   tooltip: 'Add New Product (Ctrl+N)', // Add shortcut hint to tooltip
                  onPressed: _navigateToAddProduct, // Still allow button press
                ),
              ],
            ),
            body: _buildBody(), // Use helper method for the body content
          ),
        ),
      ),
    );
  }

  // Helper method to build the body based on the current state
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      // Display error message if fetching failed
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('$_errorMessage', style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ));
    }
    if (_products.isEmpty) {
      // Display a message and an "Add" button if inventory is empty
      return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No products found in inventory.'),
            const SizedBox(height: 10),
            ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add First Product'),
                onPressed: _navigateToAddProduct, // Button still works
            )
          ],
      ));
    }

    // Display the list of products using RefreshIndicator for pull-to-refresh
    return RefreshIndicator(
      onRefresh: () => _fetchProducts(showLoading: false), // Refresh action
      child: ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          // Use Card for better visual structure of list items
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ListTile(
              title: Text(product.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Price: \$${product.defaultUnitPrice.toStringAsFixed(2)}'),
              trailing: Row( // Use Row for stock and actions menu
                 mainAxisSize: MainAxisSize.min, // Constrain row width
                 children: [
                    // Display current stock
                    Text('Stock: ${product.currentStock}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8), // Spacing
                    // More Actions menu (Edit/Delete)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'More actions',
                      onSelected: (String result) {
                        // Handle menu item selection
                        switch (result) {
                           case 'edit':
                              _navigateToEditProduct(product);
                              break;
                           case 'delete':
                              _deleteProduct(product);
                              break;
                         }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                         // Edit option
                         const PopupMenuItem<String>(
                           value: 'edit',
                           child: ListTile(leading: Icon(Icons.edit), title: Text('Edit')),
                         ),
                         // Delete option
                         PopupMenuItem<String>(
                           value: 'delete',
                           child: ListTile(
                              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                              title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error))
                           ),
                         ),
                      ],
                   ),
                 ],
              ),
              onTap: () => _navigateToEditProduct(product), // Tapping the tile also edits
            ),
          );
        },
      ),
    );
  }
}