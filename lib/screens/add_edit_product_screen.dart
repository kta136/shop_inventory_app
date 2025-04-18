// lib/screens/add_edit_product_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- Import
import 'package:provider/provider.dart';
// import 'package:uuid/uuid.dart'; // Not needed directly here anymore

import '../managers/inventory_manager.dart';
import '../models/product.dart';

// --- Define Intent for Save ---
class SaveIntent extends Intent {
  const SaveIntent();
}
// --- End Intent Definition ---

class AddEditProductScreen extends StatefulWidget {
  // ... (constructor remains the same) ...
  final Product? productToEdit;
  const AddEditProductScreen({super.key, this.productToEdit});
  bool get isEditMode => productToEdit != null;

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  // ... (keep existing state variables _formKey, controllers, _isLoading) ...
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _stockController;
  late TextEditingController _priceController;
  bool _isLoading = false;

  // --- Action for Save ---
  late final Map<Type, Action<Intent>> _saveActions = <Type, Action<Intent>>{
    SaveIntent: CallbackAction<SaveIntent>(
      onInvoke: (SaveIntent intent) { // <-- This function needs to return something
          // Call _saveProduct only if not already loading
          if (!_isLoading) {
            _saveProduct();
          }
          // MISSING RETURN STATEMENT HERE if !_isLoading is false
          // or even after _saveProduct() is called (though async)
       },
    ),
  };
  // --- End Action Definition ---

  // --- Shortcut for Save ---
  final Map<LogicalKeySet, Intent> _saveShortcuts = <LogicalKeySet, Intent>{
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveIntent(), // Ctrl+S
  };
  // --- End Shortcut Definition ---

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.productToEdit?.itemName ?? '');
    _stockController = TextEditingController(text: widget.productToEdit?.currentStock.toString() ?? '0');
    _priceController = TextEditingController(text: widget.productToEdit?.defaultUnitPrice.toStringAsFixed(2) ?? '0.00');
  }

   @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ... (_saveProduct remains mostly the same) ...
  Future<void> _saveProduct() async {
    // Add short delay to allow focus changes if needed, though likely okay
    // await Future.delayed(Duration(milliseconds: 50));
    if (!_formKey.currentState!.validate()) { // Use ! validate as formKey is not null
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Please correct the errors in the form.'), backgroundColor: Colors.orange)
      );
      return; // Stop if form is invalid
    }
     if (!mounted) return; // Check if widget is still mounted

    setState(() { _isLoading = true; });
    final inventoryManager = Provider.of<InventoryManager>(context, listen: false);
    // ... (rest of the parsing and saving logic remains the same) ...
    final String name = _nameController.text.trim();
    final int? stock = int.tryParse(_stockController.text);
    final double? price = double.tryParse(_priceController.text);

    if (stock == null || price == null) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid stock or price format.'), backgroundColor: Colors.red));
       if (mounted) setState(() { _isLoading = false; });
       return;
    }

    try {
        if (widget.isEditMode) {
          final updatedProduct = Product(
            productId: widget.productToEdit!.productId, itemName: name, currentStock: stock, defaultUnitPrice: price,
          );
          await inventoryManager.updateProduct(updatedProduct);
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${updatedProduct.itemName}" updated.')));
        } else {
          await inventoryManager.addProduct(name: name, initialStock: stock, defaultPrice: price);
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$name" added.')));
        }
        if(mounted) Navigator.of(context).pop(true);
      } catch (e) {
          print("Error saving product: $e");
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving product: ${e.toString()}'), backgroundColor: Colors.red));
      } finally {
         if(mounted) setState(() { _isLoading = false; });
      }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the Scaffold
    return Actions(
      actions: _saveActions,
      child: Shortcuts(
        shortcuts: _saveShortcuts,
        // Wrap content in FocusScope if needed, but often okay if fields handle focus
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.isEditMode ? 'Edit Product' : 'Add New Product'),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                 tooltip: 'Save Product (Ctrl+S)', // Add hint to tooltip
                onPressed: _isLoading ? null : _saveProduct,
              ),
            ],
          ),
          // Add FocusScope if text field focus prevents shortcut detection
          // Though usually Actions/Shortcuts higher up work well
          body: FocusScope( // Recommended for forms
             autofocus: true,
             child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      // ... (rest of the Form content remains the same) ...
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: <Widget>[
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Product Name', hintText: 'Enter the name of the product', border: OutlineInputBorder()),
                              textInputAction: TextInputAction.next,
                              validator: (value) { /* ... */ return null; },
                            ),
                            const SizedBox(height: 16.0),
                            TextFormField(
                              controller: _stockController,
                              decoration: const InputDecoration(labelText: 'Stock Quantity', hintText: 'Enter the initial stock level', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                              textInputAction: TextInputAction.next,
                              validator: (value) { /* ... */ return null; },
                            ),
                            const SizedBox(height: 16.0),
                             TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(labelText: 'Default Unit Price', hintText: 'Enter the price per unit (e.g., 10.99)', border: OutlineInputBorder(), prefixText: '\$'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                              textInputAction: TextInputAction.done,
                              validator: (value) { /* ... */ return null; },
                             ),
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