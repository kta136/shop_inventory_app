// lib/screens/add_edit_product_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart'; // Although ID is generated in manager, useful for checking edit mode

import '../managers/inventory_manager.dart';
import '../models/product.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? productToEdit; // Make product optional for Add mode

  const AddEditProductScreen({super.key, this.productToEdit});

  // Helper to check if we are in edit mode
  bool get isEditMode => productToEdit != null;

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>(); // Key for the Form widget
  late TextEditingController _nameController;
  late TextEditingController _stockController;
  late TextEditingController _priceController;

  bool _isLoading = false; // To show loading indicator on save

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing product data if in edit mode
    _nameController = TextEditingController(text: widget.productToEdit?.itemName ?? '');
    _stockController = TextEditingController(text: widget.productToEdit?.currentStock.toString() ?? '0');
    _priceController = TextEditingController(text: widget.productToEdit?.defaultUnitPrice.toStringAsFixed(2) ?? '0.00');
  }

  @override
  void dispose() {
    // Dispose controllers when the widget is removed from the tree
    _nameController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    // 1. Validate the form
    if (_formKey.currentState?.validate() ?? false) {
      setState(() { _isLoading = true; }); // Show loading indicator

      final inventoryManager = Provider.of<InventoryManager>(context, listen: false);
      final String name = _nameController.text.trim();
      final int? stock = int.tryParse(_stockController.text);
      final double? price = double.tryParse(_priceController.text);

      // Extra check although validator should catch nulls
      if (stock == null || price == null) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid stock or price format.'), backgroundColor: Colors.red)
         );
          setState(() { _isLoading = false; });
         return;
      }

      try {
        if (widget.isEditMode) {
          // --- Update Existing Product ---
          final updatedProduct = Product(
            productId: widget.productToEdit!.productId, // Use existing ID
            itemName: name,
            currentStock: stock,
            defaultUnitPrice: price,
          );
          await inventoryManager.updateProduct(updatedProduct);
          if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${updatedProduct.itemName}" updated.'))
             );
          }
        } else {
          // --- Add New Product ---
          await inventoryManager.addProduct(
            name: name,
            initialStock: stock,
            defaultPrice: price,
          );
           if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"$name" added.'))
             );
          }
        }

        // If save is successful, pop the screen and return 'true'
         if(mounted){
             Navigator.of(context).pop(true); // Return true to indicate success
         }

      } catch (e) {
         // Handle errors (e.g., duplicate name, database error)
          print("Error saving product: $e");
          if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error saving product: ${e.toString()}'), backgroundColor: Colors.red)
             );
          }
      } finally {
         if(mounted) {
            setState(() { _isLoading = false; }); // Hide loading indicator
         }
      }
    } else {
      // Form is not valid
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Please correct the errors in the form.'), backgroundColor: Colors.orange)
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Product' : 'Add New Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Product',
            onPressed: _isLoading ? null : _saveProduct, // Disable button while loading
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView( // Allows scrolling on smaller screens
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // --- Product Name Field ---
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        hintText: 'Enter the name of the product',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next, // Move focus to next field
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a product name.';
                        }
                        return null; // Return null if valid
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // --- Stock Field ---
                    TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(
                        labelText: 'Stock Quantity',
                        hintText: 'Enter the initial stock level',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly // Allow only numbers
                      ],
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the stock quantity.';
                        }
                        final number = int.tryParse(value);
                        if (number == null) {
                          return 'Please enter a valid number.';
                        }
                        if (number < 0) {
                          return 'Stock cannot be negative.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // --- Price Field ---
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Default Unit Price',
                        hintText: 'Enter the price per unit (e.g., 10.99)',
                        border: OutlineInputBorder(),
                        prefixText: '\$', // Optional: Add currency symbol
                      ),
                       keyboardType: const TextInputType.numberWithOptions(decimal: true),
                       inputFormatters: <TextInputFormatter>[
                          // Allow numbers and a single decimal point
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                       ],
                       textInputAction: TextInputAction.done, // Finish input on this field
                       validator: (value) {
                         if (value == null || value.isEmpty) {
                           return 'Please enter the price.';
                         }
                         final number = double.tryParse(value);
                         if (number == null) {
                           return 'Please enter a valid price format (e.g., 10.99).';
                         }
                          if (number < 0) {
                           return 'Price cannot be negative.';
                         }
                         return null;
                       },
                    ),
                    const SizedBox(height: 24.0),

                    // --- Save Button (Alternative placement) ---
                    // Center(
                    //   child: ElevatedButton.icon(
                    //     icon: Icon(Icons.save),
                    //     label: Text(widget.isEditMode ? 'Update Product' : 'Add Product'),
                    //     onPressed: _isLoading ? null : _saveProduct,
                    //     style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
    );
  }
}