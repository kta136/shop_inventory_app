// lib/screens/sales_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters & shortcuts
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting

import '../managers/inventory_manager.dart';
import '../managers/sales_manager.dart'; // Need SalesManager
import '../models/product.dart';
// Using the definition from SalesManager for consistency:
// typedef SaleInputItem = ({ String productId, int quantity, double unitPrice });

// --- Define Intent for Finalize Sale Hotkey ---
class FinalizeSaleIntent extends Intent {
  const FinalizeSaleIntent();
}
// --- End Intent Definition ---


class SalesEntryScreen extends StatefulWidget {
  const SalesEntryScreen({super.key});

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  // State variables
  DateTime _selectedSaleDate = DateTime.now();
  List<Product> _availableProducts = [];
  Product? _selectedProduct; // Holds the actual selected Product object via onSelected
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final List<({Product product, int quantity, double unitPrice})> _currentSaleItems = [];
  double _currentSaleTotal = 0.0;

  // Form key ONLY for the Qty/Price validation section
  final _addItemFormKey = GlobalKey<FormState>();

  // Controllers and Focus Nodes for Form Fields
  final TextEditingController _productAutocompleteController = TextEditingController(); // Manage Autocomplete text display externally if needed
  final FocusNode _productFocusNode = FocusNode(); // Manage Autocomplete focus externally
  final FocusNode _quantityFocusNode = FocusNode(); // Manage Qty focus
  final FocusNode _priceFocusNode = FocusNode(); // Manage Price focus

  bool _isLoadingProducts = true;
  bool _isSavingSale = false; // Loading indicator for finalize/save buttons
  bool _isAddingItem = false; // Flag to prevent rapid add triggers / state conflicts

  // --- Action & Shortcut Maps ---
  late final Map<Type, Action<Intent>> _salesEntryActions = <Type, Action<Intent>>{
    FinalizeSaleIntent: CallbackAction<FinalizeSaleIntent>(
      onInvoke: (FinalizeSaleIntent intent) {
        if (!_isSavingSale) _finalizeSale();
        return null;
      },
    ),
  };
  final Map<LogicalKeySet, Intent> _salesEntryShortcuts = <LogicalKeySet, Intent>{
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter): const FinalizeSaleIntent(),
  };
  // --- End Action/Shortcut Maps ---

  @override
  void initState() {
    super.initState();
    // Fetch products and then set initial focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAvailableProducts().then((_) {
        if (mounted) _productFocusNode.requestFocus(); // Use direct request on our node
      });
    });
    // Listener to handle manual clearing of autocomplete field
    _productAutocompleteController.addListener(() {
      // This listener ensures state is cleared if text controller is emptied externally/programmatically
      if (_productAutocompleteController.text.isEmpty && _selectedProduct != null) {
        if (mounted) {
          setState(() {
            _selectedProduct = null;
            _unitPriceController.clear();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    // Dispose all controllers and focus nodes
    _quantityController.dispose();
    _unitPriceController.dispose();
    _productAutocompleteController.dispose();
    _productFocusNode.dispose();
    _quantityFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  // Fetch products for the Autocomplete options
  Future<void> _fetchAvailableProducts() async {
    if (!mounted) return;
    setState(() { _isLoadingProducts = true; });
    try {
      final inventoryManager = Provider.of<InventoryManager>(context, listen: false);
      List<Product> fetchedProducts = inventoryManager.getAllProducts();
      List<Product> modifiableProducts = List.from(fetchedProducts); // Create mutable copy
      modifiableProducts.sort((a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()));
      _availableProducts = modifiableProducts; // Assign sorted mutable list
    } catch (e, s) {
      print("Error fetching products for sale entry: $e");
      print("Stack trace: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error loading products: $e'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
      _availableProducts = []; // Ensure list is empty on error
    } finally {
      if (mounted) {
        setState(() { _isLoadingProducts = false; });
      }
    }
  }

  // Show Date Picker to select the sale date
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedSaleDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        );
    if (picked != null && picked != _selectedSaleDate && mounted) {
      setState(() {
        _selectedSaleDate = picked;
      });
    }
  }

  // --- Add Item Logic - Attempt 2: Unfocus then Refocus ---
  void _addItemToSale() {
    // Prevent rapid re-entry while processing add/focus
    if (!mounted || _isAddingItem) return;

    // 1. Ensure a product object is selected
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a valid product from the suggestions list.'),
          backgroundColor: Colors.orange));
      _productFocusNode.requestFocus();
      return;
    }
    // 2. Validate the Quantity and Price fields
    if (_addItemFormKey.currentState?.validate() ?? false) {
      // --- Set processing flag ---
      setState(() { _isAddingItem = true; });

      final int quantity = int.parse(_quantityController.text);
      final double unitPrice = double.parse(_unitPriceController.text);
      final productToAdd = _selectedProduct!;

      // 3. Add item and clear form within setState
      setState(() {
        _currentSaleItems.add((
          product: productToAdd,
          quantity: quantity,
          unitPrice: unitPrice,
        ));
        _calculateTotal();
        _clearAddItemForm();
      });

      // 4. Unfocus, wait briefly, then request focus back AFTER the build frame completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print("Attempting to unfocus and refocus product field after add.");
          // 1. Unfocus whatever currently has focus
          FocusScope.of(context).unfocus();
          // 2. Introduce a minimal delay to allow unfocus to register
          Future.delayed(const Duration(milliseconds: 30), () { // Reduced delay slightly
             if (mounted) {
                // 3. Request focus for the target node
                print("  Delayed: Requesting focus for product field.");
                _productFocusNode.requestFocus();
                // 4. Reset the flag (moved inside delay after focus request)
                //    Use setState here if any UI elements depend on _isAddingItem finishing visually
                //    If only used for button disable state, direct assignment is okay.
                //    Using setState for safety in case of future UI dependencies.
                 setState(() { _isAddingItem = false; });
             } else {
                _isAddingItem = false;
             }
          });
        } else {
           // If widget unmounted before callback, ensure flag is reset
           _isAddingItem = false;
        }
      });

    } else {
      // Validation failed on Qty/Price
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please correct quantity/price errors.'),
          backgroundColor: Colors.orange));
      // Reset flag immediately if validation fails
       _isAddingItem = false; // No need for setState if validation fails before state changes
    }
  }
  // --- END Add Item Logic - Attempt 2 ---


  // --- Remove Item from Sale Logic ---
  void _removeItemFromSale(int index) {
    if (index < 0 || index >= _currentSaleItems.length || !mounted) return;
    setState(() {
      _currentSaleItems.removeAt(index);
      _calculateTotal(); // Update total amount
    });
  }

  // --- Finalize Sale Logic ---
  Future<void> _finalizeSale() async {
    // Prevent saving if already saving or adding an item (edge case)
    if (!mounted || _isSavingSale || _isAddingItem) return;

    if (_currentSaleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cannot record an empty sale. Add items first.'),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() { _isSavingSale = true; }); // Show loading indicator

    final salesManager = Provider.of<SalesManager>(context, listen: false);
    final List<SaleInputItem> itemsToSell = _currentSaleItems.map((item) {
      return ( // Convert to SaleInputItem record type
        productId: item.product.productId,
        quantity: item.quantity,
        unitPrice: item.unitPrice
      );
    }).toList();

    try {
      await salesManager.createSaleRecord(
          saleDate: _selectedSaleDate,
          itemsToSell: itemsToSell,
          entryMethod: "MANUAL"
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale recorded successfully!'), backgroundColor: Colors.green)
        );
        _clearSale(); // Reset screen state
      }
    } on Exception catch (e) {
      print("Error finalizing sale: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error recording sale: ${e.toString().replaceFirst("Exception: ", "")}'),
                backgroundColor: Theme.of(context).colorScheme.error)
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isSavingSale = false; }); // Hide loading indicator
      }
    }
  }

  // Recalculates the total amount for the items currently in the sale list
  void _calculateTotal() {
    double total = 0;
    for (final item in _currentSaleItems) {
      total += item.quantity * item.unitPrice;
    }
    // Assume called within setState, so just update variable
    _currentSaleTotal = total;
  }

  // Clears the input fields in the "Add Item" form section
  void _clearAddItemForm() {
    // Needs setState if called independently
    _selectedProduct = null; // Clear selected product state
    _productAutocompleteController.clear(); // Clear the external text controller
    _quantityController.text = '1'; // Reset quantity
    _unitPriceController.clear();   // Clear price
    _addItemFormKey.currentState?.reset(); // Reset Qty/Price validation state
     // Note: The internal controller of Autocomplete fieldViewBuilder is cleared via its suffixIcon logic if user clicks it
  }

  // Clears the entire state of the current sale entry screen
  void _clearSale() {
    // This must be called within setState or trigger one
    setState(() {
      _selectedSaleDate = DateTime.now();
      _currentSaleItems.clear();
      _currentSaleTotal = 0.0;
      _clearAddItemForm(); // Includes resetting _selectedProduct and controllers
    });
  }


  @override
  Widget build(BuildContext context) {
    // Wrap the Scaffold with Actions/Shortcuts/FocusScope for hotkeys
    return Actions(
      actions: _salesEntryActions,
      child: Shortcuts(
        shortcuts: _salesEntryShortcuts,
        child: FocusScope(
          autofocus: true, // Request focus for this scope
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Record New Sale'),
              actions: [
                // AppBar finalize button with Tooltip
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Tooltip(
                     message: 'Finalize Sale (Ctrl+Enter)',
                     child: TextButton.icon(
                       icon: _isSavingSale
                           ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                           : const Icon(Icons.check_circle_outline),
                       label: const Text("Finalize Sale"),
                       // Disable while saving OR adding an item
                       onPressed: (_isSavingSale || _isAddingItem) ? null : _finalizeSale,
                       style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onPrimary),
                     ),
                  ),
                )
              ],
            ),
            body: _isLoadingProducts
                ? const Center(child: CircularProgressIndicator()) // Show loading for products
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Date Selection Row ---
                        _buildDateSelector(context),
                        const SizedBox(height: 16),

                        // --- Add Item Card (includes Autocomplete and Qty/Price Form) ---
                        _buildAddItemCard(context),
                        const SizedBox(height: 16),

                        // --- Current Sale Items List Section ---
                        Text('Items in Current Sale:', style: Theme.of(context).textTheme.titleMedium),
                        const Divider(thickness: 1),
                        Expanded(child: _buildCurrentSaleItemsList()), // List takes remaining space

                        // --- Total Amount and Save Button Row ---
                        const Divider(thickness: 1),
                        _buildTotalAndSaveRow(context), // Use the helper widget here
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  // Builds the row for selecting the sale date
  Widget _buildDateSelector(BuildContext context) {
     return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
           Text('Sale Date: ', style: Theme.of(context).textTheme.titleMedium),
           const SizedBox(width: 8),
           TextButton(
             style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
             onPressed: () => _selectDate(context),
             child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(DateFormat.yMMMd().format(_selectedSaleDate),
                     style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 5),
                    Icon(Icons.calendar_month, size: 18, color: Theme.of(context).colorScheme.primary),
                ],
              ),
           ),
        ],
     );
  }

  // Builds the Card containing the Autocomplete and the Qty/Price Form section
  Widget _buildAddItemCard(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Product Autocomplete ---
            Autocomplete<Product>(
              // Use fieldViewBuilder for the text input field
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Use the focusNode provided by the builder for internal focus mgmt
                return TextFormField(
                  controller: controller, // Use builder's controller
                  focusNode: focusNode,   // Use builder's focus node HERE
                  decoration: InputDecoration(
                    labelText: 'Search & Select Product',
                    hintText: _availableProducts.isEmpty ? 'No products loaded' : 'Start typing product name...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear Selection',
                            onPressed: () {
                              if (mounted) {
                                // Use setState to clear external and internal state
                                setState(() {
                                  controller.clear(); // Clear Autocomplete's internal text
                                  _productAutocompleteController.clear(); // Clear our mirrored controller
                                  _selectedProduct = null; // Clear state variable
                                  _unitPriceController.clear(); // Clear dependent price
                                  focusNode.requestFocus(); // Refocus the (now empty) field using builder's node
                                });
                              }
                            },
                          )
                        : null,
                  ),
                  onFieldSubmitted: (_) => onFieldSubmitted(), // Let Autocomplete handle submit
                  // Removed validator - Handled in _addItemToSale
                );
              },
              // Generate options based on text input
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.trim().isEmpty) {
                  return const Iterable<Product>.empty();
                }
                final searchTerm = textEditingValue.text.toLowerCase();
                return _availableProducts.where((Product option) {
                  return option.itemName.toLowerCase().contains(searchTerm);
                });
              },
              // Build the view for the dropdown options list
              optionsViewBuilder: (context, onSelected, options) {
                if (options.isEmpty) return const SizedBox.shrink();
                return LayoutBuilder( // Use LayoutBuilder
                  builder: (context, constraints) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 250),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final Product option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: ListTile(
                                  dense: true,
                                  title: Text(option.itemName),
                                  subtitle: Text('Stock: ${option.currentStock} | Price: ₹${option.defaultUnitPrice.toStringAsFixed(2)}'), // INR
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }
                );
              },
              // When an option is selected from the list
              onSelected: (Product selection) {
                if (mounted) {
                  setState(() {
                    _selectedProduct = selection;
                    _productAutocompleteController.text = selection.itemName; // Sync our display controller
                    _unitPriceController.text = selection.defaultUnitPrice.toStringAsFixed(2);
                    _quantityController.text = '1';
                    _addItemFormKey.currentState?.reset();
                  });
                  _quantityFocusNode.requestFocus(); // Use direct request on our node
                }
              },
              // Tells Autocomplete what string to display for a selected Product object
              displayStringForOption: (Product option) => option.itemName,
              // Assign our controller to potentially set initial text if needed
              initialValue: TextEditingValue(text: _productAutocompleteController.text),
            ),
            const SizedBox(height: 12),

            // --- Qty/Price Form Section ---
            Form(
              key: _addItemFormKey, // Key validates only this section
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity Field
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      focusNode: _quantityFocusNode, // Assign focus node
                      decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      onFieldSubmitted: (_) => _priceFocusNode.requestFocus(), // Move focus on Enter
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Req.';
                        final number = int.tryParse(value);
                        if (number == null) return 'Invalid';
                        if (number <= 0) return '> 0';
                        if (_selectedProduct != null && number > _selectedProduct!.currentStock) {
                          return 'Max: ${_selectedProduct!.currentStock}';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Price Field
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _unitPriceController,
                      focusNode: _priceFocusNode, // Assign focus node
                      decoration: const InputDecoration(labelText: 'Unit Price', border: OutlineInputBorder(), prefixText: '₹ '), // INR
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      onFieldSubmitted: (_) => _addItemToSale(), // Trigger add item on Enter
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Req.';
                        final number = double.tryParse(value);
                        if (number == null) return 'Invalid';
                        if (number < 0) return '>= 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Add Item Button
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0), // Align button
                    child: Tooltip(
                      message: 'Add Item to Sale',
                      child: ElevatedButton(
                         // Disable button while processing add
                        onPressed: _isAddingItem ? null : _addItemToSale,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                        child: _isAddingItem
                           ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) // Show loading on button too
                           : const Icon(Icons.add),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // Builds the list view displaying items currently added to the sale
  Widget _buildCurrentSaleItemsList() {
    if (_currentSaleItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text('Add products using the form above.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: _currentSaleItems.length,
      itemBuilder: (context, index) {
        final item = _currentSaleItems[index];
        final lineTotal = item.quantity * item.unitPrice;
        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            title: Text(item.product.itemName, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('${item.quantity} x ${NumberFormat.currency(symbol: '₹ ', locale: 'en_IN').format(item.unitPrice)}'), // INR Update with locale
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(NumberFormat.currency(symbol: '₹ ', locale: 'en_IN').format(lineTotal), style: const TextStyle(fontWeight: FontWeight.bold)), // INR Update with locale
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                  onPressed: () => _removeItemFromSale(index), // Calls remove item logic
                  tooltip: 'Remove Item',
                  splashRadius: 20,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Builds the row containing the Total amount and the explicit Save button
  Widget _buildTotalAndSaveRow(BuildContext context) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8.0),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out elements
         children: [
           // Explicit Save Button
           ElevatedButton.icon(
             icon: _isSavingSale
                 ? const SizedBox(height:18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) // Loading indicator
                 : const Icon(Icons.save_alt), // Save icon
             label: const Text('Save Sale'),
             // Disable while saving OR adding item
             onPressed: (_isSavingSale || _isAddingItem) ? null : _finalizeSale,
             style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: Theme.of(context).colorScheme.secondary, // Use secondary color
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
             ),
           ),

           // Total Display
           Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text('Total: ', style: Theme.of(context).textTheme.titleLarge),
               Text(
                 NumberFormat.currency(symbol: '₹ ', locale: 'en_IN').format(_currentSaleTotal), // INR Update with locale
                 style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
               ),
             ],
           ),
         ],
       ),
     );
   }

} // End of _SalesEntryScreenState class