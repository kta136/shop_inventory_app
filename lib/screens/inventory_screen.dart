// lib/screens/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../managers/inventory_manager.dart';
import '../models/product.dart';
import 'add_edit_product_screen.dart'; // We will create this next

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Fetch products after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProducts();
    });
  }

Future<void> _fetchProducts({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final inventoryManager = Provider.of<InventoryManager>(context, listen: false);
      // 1. Get the unmodifiable list from the manager
      List<Product> fetchedProducts = inventoryManager.getAllProducts();

      // 2. Create a NEW MODIFIABLE list from it
      List<Product> modifiableProducts = List.from(fetchedProducts);

      // 3. Sort the NEW list
      modifiableProducts.sort((a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()));

      // 4. Assign the sorted, modifiable list to the state variable
      _products = modifiableProducts;

    } catch (e, s) { // Also good to log stack trace here
      print("Error fetching products: $e");
      print("Stack trace: $s");
      _errorMessage = "Error loading products.";
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToAddProduct() async {
    final result = await Navigator.push<bool>( // Expect a boolean result (true if saved)
      context,
      MaterialPageRoute(builder: (context) => const AddEditProductScreen()),
    );
    // If the AddEdit screen indicated a save happened, refresh the list
    if (result == true && mounted) {
      _fetchProducts(showLoading: false); // Refresh without full loading indicator
    }
  }

  void _navigateToEditProduct(Product product) async {
     final result = await Navigator.push<bool>(
       context,
       MaterialPageRoute(builder: (context) => AddEditProductScreen(productToEdit: product)), // Pass product
     );
     if (result == true && mounted) {
       _fetchProducts(showLoading: false);
     }
   }

   Future<void> _deleteProduct(Product product) async {
      final inventoryManager = Provider.of<InventoryManager>(context, listen: false);
      // Confirmation Dialog
      final confirm = await showDialog<bool>(
         context: context,
         builder: (BuildContext ctx) {
           return AlertDialog(
             title: const Text('Confirm Deletion'),
             content: Text('Are you sure you want to delete "${product.itemName}"? This cannot be undone.'),
             actions: <Widget>[
               TextButton(
                 onPressed: () => Navigator.of(ctx).pop(false), // Return false
                 child: const Text('Cancel'),
               ),
               TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                 onPressed: () => Navigator.of(ctx).pop(true), // Return true
                 child: const Text('Delete'),
               ),
             ],
           );
         },
       );

      if (confirm == true && mounted) {
         try {
            await inventoryManager.deleteProduct(product.productId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('"${product.itemName}" deleted.'))
            );
            _fetchProducts(showLoading: false); // Refresh list
         } catch (e) {
            print("Error deleting product: $e");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting product: ${e.toString()}'), backgroundColor: Colors.red)
            );
         }
      }
   }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add New Product',
            onPressed: _navigateToAddProduct,
          ),
        ],
      ),
      body: _buildBody(),
      // Remove the old FAB used for testing
      // floatingActionButton: FloatingActionButton( ... ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('Error: $_errorMessage', style: TextStyle(color: Colors.red)),
      ));
    }
    if (_products.isEmpty) {
      return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No products found.'),
            SizedBox(height: 10),
            ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Add First Product'),
                onPressed: _navigateToAddProduct,
            )
          ],
      ));
    }

    // Display the list
    return RefreshIndicator( // Add pull-to-refresh
      onRefresh: () => _fetchProducts(showLoading: false),
      child: ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return Card( // Use Card for better visual separation
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ListTile(
              title: Text(product.itemName, style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Price: \$${product.defaultUnitPrice.toStringAsFixed(2)}'), // Example: show price
              trailing: Row( // Use Row for multiple elements in trailing
                 mainAxisSize: MainAxisSize.min, // Important for Row in ListTile
                 children: [
                    Text('Stock: ${product.currentStock}', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 5),
                    // Add PopupMenuButton for actions like Edit/Delete
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert),
                      onSelected: (String result) {
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
                         const PopupMenuItem<String>(
                           value: 'edit',
                           child: ListTile(leading: Icon(Icons.edit), title: Text('Edit')),
                         ),
                         const PopupMenuItem<String>(
                           value: 'delete',
                           child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red))),
                         ),
                      ],
                   ),
                 ],
              ),
              onTap: () => _navigateToEditProduct(product), // Allow tapping list item to edit
            ),
          );
        },
      ),
    );
  }
}