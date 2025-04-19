// lib/screens/add_edit_product_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters & shortcuts
import 'package:provider/provider.dart';
// import 'package:uuid/uuid.dart'; // Not needed directly here

import '../managers/inventory_manager.dart';
import '../models/product.dart';

// --- Define Intent for Save Hotkey ---
class SaveIntent extends Intent {
  const SaveIntent();
}
// --- End Intent Definition ---

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

  // Focus Nodes for field navigation
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _stockFocusNode = FocusNode();
  final FocusNode _priceFocusNode = FocusNode();

  bool _isLoading = false; // To show loading indicator on save

  // --- Action Map for Save Hotkey ---
  late final Map<Type, Action<Intent>> _saveActions = <Type, Action<Intent>>{
    SaveIntent: CallbackAction<SaveIntent>(
      onInvoke: (SaveIntent intent) {
        // Call _saveProduct only if not already loading
        if (!_isLoading) {
          _saveProduct();
        }
        return null; // Required return for CallbackAction
      },
    ),
  };
  // --- End Action Definition ---

  // --- Shortcut Map for Save Hotkey ---
  final Map<LogicalKeySet, Intent> _saveShortcuts = <LogicalKeySet, Intent>{
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveIntent(), // Ctrl+S
  };
  // --- End Shortcut Definition ---

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing product data if in edit mode
    _nameController = TextEditingController(text: widget.productToEdit?.itemName ?? '');
    _stockController = TextEditingController(text: widget.productToEdit?.currentStock.toString() ?? '0');
    _priceController = TextEditingController(text: widget.productToEdit?.defaultUnitPrice.toStringAsFixed(2) ?? '0.00');
    // Set initial focus
     WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) _nameFocusNode.requestFocus();
     });
  }

  @override
  void dispose() {
    // Dispose controllers and focus nodes when the widget is removed
    _nameController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    _nameFocusNode.dispose();
    _stockFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  // Logic to handle saving (either adding new or updating existing)
  Future<void> _saveProduct() async {
    if (!mounted) return; // Check if widget is still mounted

    // 1. Validate the form
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct the errors in the form.'), backgroundColor: Colors.orange)
      );
      return; // Stop if form is invalid
    }

    // 2. Show loading indicator
    setState(() { _isLoading = true; });

    final inventoryManager = Provider.of<InventoryManager>(context, listen: false);
    final String name = _nameController.text.trim();
    // Use tryParse for safety, though validator should catch format errors
    final int? stock = int.tryParse(_stockController.text);
    final double? price = double.tryParse(_priceController.text);

    // Should not happen if validation is correct, but an extra check
    if (stock == null || price == null) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid stock or price format detected.'), backgroundColor: Colors.red)
       );
       if (mounted) setState(() { _isLoading = false; });
       return;
    }

    try {
      String successMessage;
      if (widget.isEditMode) {
        // --- Update Existing Product ---
        final updatedProduct = Product(
          productId: widget.productToEdit!.productId, // Use existing ID
          itemName: name,
          currentStock: stock,
          defaultUnitPrice: price,
        );
        await inventoryManager.updateProduct(updatedProduct);
        successMessage = '"${updatedProduct.itemName}" updated.';

      } else {
        // --- Add New Product ---
        await inventoryManager.addProduct(
          name: name,
          initialStock: stock,
          defaultPrice: price,
        );
        successMessage = '"$name" added successfully.';
      }

      // If save is successful, show message and pop the screen returning 'true'
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMessage), backgroundColor: Colors.green)
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }

    } catch (e) {
      // Handle errors (e.g., duplicate name, database error)
      print("Error saving product: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving product: ${e.toString()}'), backgroundColor: Colors.red)
        );
      }
    } finally {
      // Hide loading indicator regardless of outcome
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Wrap the Scaffold with Actions, Shortcuts, and FocusScope
    return Actions(
      actions: _saveActions,
      child: Shortcuts(
        shortcuts: _saveShortcuts,
        child: FocusScope( // Can help ensure shortcuts are caught
           autofocus: true,
           child: Scaffold(
             appBar: AppBar(
               title: Text(widget.isEditMode ? 'Edit Product' : 'Add New Product'),
               actions: [
                 // Save button in AppBar with Tooltip
                 Tooltip(
                   message: 'Save Product (Ctrl+S)',
                   child: IconButton(
                     icon: const Icon(Icons.save),
                     onPressed: _isLoading ? null : _saveProduct, // Disable button while loading
                   ),
                 ),
               ],
             ),
             body: _isLoading
                 ? const Center(child: CircularProgressIndicator()) // Show loading overlay
                 : SingleChildScrollView( // Allows scrolling on smaller screens
                     padding: const EdgeInsets.all(16.0),
                     child: Form(
                       key: _formKey, // Assign form key
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch buttons later
                         children: <Widget>[
                           // --- Product Name Field ---
                           TextFormField(
                             controller: _nameController,
                             focusNode: _nameFocusNode, // Assign focus node
                             decoration: const InputDecoration(
                               labelText: 'Product Name',
                               hintText: 'Enter the name of the product',
                               border: OutlineInputBorder(),
                               prefixIcon: Icon(Icons.label_outline)
                             ),
                             textCapitalization: TextCapitalization.words, // Capitalize words
                             textInputAction: TextInputAction.next, // Move focus to next field
                             onFieldSubmitted: (_) => _stockFocusNode.requestFocus(), // Use direct request
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
                             focusNode: _stockFocusNode, // Assign focus node
                             decoration: const InputDecoration(
                               labelText: 'Stock Quantity',
                               hintText: 'Enter the initial stock level',
                               border: OutlineInputBorder(),
                               prefixIcon: Icon(Icons.inventory_2_outlined)
                             ),
                             keyboardType: TextInputType.number,
                             inputFormatters: <TextInputFormatter>[
                               FilteringTextInputFormatter.digitsOnly // Allow only numbers
                             ],
                             textInputAction: TextInputAction.next, // Move to price
                             onFieldSubmitted: (_) => _priceFocusNode.requestFocus(), // Use direct request
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
                             focusNode: _priceFocusNode, // Assign focus node
                             decoration: const InputDecoration(
                               labelText: 'Default Unit Price',
                               hintText: 'Enter the price per unit (e.g., 10.99)',
                               border: OutlineInputBorder(),
                               prefixText: '₹ ', // Use INR symbol
                               prefixIcon: Icon(Icons.currency_rupee)
                             ),
                             keyboardType: const TextInputType.numberWithOptions(decimal: true),
                             inputFormatters: <TextInputFormatter>[
                               // Allow numbers and a single decimal point up to 2 places
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                             ],
                             textInputAction: TextInputAction.done, // Finish input on this field
                             onFieldSubmitted: (_) => _saveProduct(), // Trigger save on submit
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

                           // --- Explicit Save Button (alternative to AppBar action) ---
                           // ElevatedButton.icon(
                           //   icon: Icon(Icons.save),
                           //   label: Text(widget.isEditMode ? 'Update Product' : 'Add Product'),
                           //   onPressed: _isLoading ? null : _saveProduct,
                           //   style: ElevatedButton.styleFrom(
                           //      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                           //      minimumSize: Size(double.infinity, 50) // Stretch button
                           //   ),
                           // ),
                         ],
                       ),
                     ),
                   ),
           ),
         ),
      ),
   );
 }
}