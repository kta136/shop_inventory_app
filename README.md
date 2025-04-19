Project Documentation: Shop Sales & Inventory Manager

Version: 0.2
Date: 2023-10-27 (Updated)

Table of Contents:

Introduction

Goals & Scope

Target Platform & User

Development Phases

High-Level Architecture

Core Modules & Classes (Implemented in v0.2)

Data Models (Implemented in v0.2)

Key Workflows (Implemented/Partially Implemented in v0.2)

User Interface (Implemented in v0.2)

Next Steps / Things To Do (Post v0.2)

Phase 2: OCR Integration Plan (Future)

Technology Stack (Used in v0.2)

Setup & Running

Future Considerations (Long Term)

Documentation Maintenance

1. Introduction

The Shop Sales & Inventory Manager is a cross-platform application designed to help a small shop owner manage daily sales records and maintain product inventory levels digitally. Version 0.2 establishes the core functionality for manual inventory management and sales entry, including the necessary backend logic, data persistence, and user interfaces for these tasks on native desktop platforms.

2. Goals & Scope

Primary Goal: Accurately record sales transactions and update inventory stock levels accordingly.

Secondary Goal: Provide simple views for sales history and current inventory status.

Scope (v0.2 - Phase 1 Implemented):

Core data models (Product, SaleItem, SaleRecord).

SQLite database persistence (sqflite, sqflite_common_ffi for desktop).

InventoryManager for product CRUD and stock operations.

SalesManager logic for creating sales (manual entry), deleting sales, and retrieving history/totals.

Dependency injection setup using Provider.

Main application navigation using BottomNavigationBar (MainScreen).

Functional UI (InventoryScreen) for viewing, adding, editing (via AddEditProductScreen), and deleting inventory items, including pull-to-refresh.

Functional UI (SalesEntryScreen) for manually recording sales: date selection, searchable product selection (Autocomplete), quantity/price input, temporary item list management, finalizing sales (triggers SalesManager), user feedback, and screen clearing.

Functional UI (SalesHistoryScreen) for viewing sales history: date range selection, list display, total display, view item details dialog, record deletion with confirmation.

Keyboard shortcuts (Hotkeys) for primary actions (tab switching, new product, save product, finalize sale).

Scope (Future - Phase 1 Completion):

UI/UX Refinements (e.g., Autocomplete hover highlighting).

Implementation of complex features like stock reversal on sale deletion.

Comprehensive error handling review.

Scope (Future - Phase 2): OCR integration for automated sales entry from images.

3. Target Platform & User

Platform (v0.2 Validated): Windows Desktop.

Platform (Code Compatible): Android, iOS (via Flutter and sqflite standard implementation). Linux, macOS Desktop (via Flutter and sqflite_common_ffi).

Platform (Excluded): Web (due to sqflite limitations).

User: Single primary user (shop owner/manager).

4. Development Phases

Phase 1 (Completed - v0.2 + History UI + Currency): Implemented the core application logic with manual data entry. Built the foundation for inventory management, sales recording, data persistence, and the user interface for these tasks, including Inventory, Sales Entry, and Sales History screens. Currency updated to INR. The remaining tasks for Phase 1 are refinements like Autocomplete hover and stock reversal.

Phase 2 (Future Implementation): Add functionality to upload JPEG images, process via OCR, allow user confirmation, and record sales automatically.

5. High-Level Architecture

The application follows a layered architecture pattern:

User Interface (UI): Built with Flutter. Handles user interaction, displays data, gathers input. Managed via MainScreen with BottomNavigationBar. Includes InventoryScreen, AddEditProductScreen, SalesEntryScreen, and SalesHistoryScreen.

Business Logic Layer: Contains core application logic. Dependencies are injected/managed via Provider.

InventoryManager: Manages product data (CRUD, stock). Implemented.

SalesManager: Manages sales records (create, delete, retrieve). Implemented.

(Phase 2) ImageProcessor, SalesDataParser: (Not Implemented).

Data Persistence Layer: Abstracts database interactions.

DatabaseService: Interface defining persistence contract. Implemented.

SQLiteDatabaseService: Concrete implementation using sqflite / sqflite_common_ffi. Handles SQL operations, table creation, transactions. Implemented.

SQLite Database: Local file (shop_inventory.db).

Dependency Flow: UI Widgets -> access Managers (via Provider) -> Managers -> use DatabaseService -> DatabaseService -> interacts with SQLite DB.

6. Core Modules & Classes (Implemented in v0.2)

InventoryManager (lib/managers/inventory_manager.dart)

Purpose: Central point for managing product catalog and stock levels. Uses an in-memory cache (_productsCache) synchronized with the database for performance.

Dependencies: DatabaseService. Injected via constructor.

Key Functions: loadInventory(), addProduct(), updateProduct(), deleteProduct(), getProductById(), findProductByName(), getAllProducts() (returns List.unmodifiable), decreaseStock(), increaseStock().

Details: Generates UUIDs for new products. Requires loadInventory() call on app startup. Performs client-side checks (e.g., duplicate name on add, sufficient stock on decrease). Handles database constraint errors on delete (e.g., if product is in a sale).

SalesManager (lib/managers/sales_manager.dart)

Purpose: Handles creation, retrieval, deletion, and aggregation of sales records. Interacts with InventoryManager for stock validation and updates during sale creation.

Dependencies: DatabaseService, InventoryManager. Injected via constructor.

Key Functions: createSaleRecord(), getSalesHistory(), calculateTotalSales(), deleteSaleRecord().

Details: createSaleRecord uses SaleInputItem record type, validates input, checks product existence, attempts InventoryManager.decreaseStock for all items before saving the sale record to the database (this sequence has atomicity limitations between stock update and sale save). deleteSaleRecord calls DatabaseService to remove the record (associated items deleted via DB cascade). Note: deleteSaleRecord currently does not revert inventory stock changes automatically; this is marked as a complex future enhancement.

DatabaseService (lib/services/database_service.dart)

Purpose: Abstract interface (abstract class) defining the contract for data persistence operations, decoupling business logic from SQLite specifics.

Methods: initDatabase, saveProduct, deleteProduct, getAllProductsFromDb, getProductByIdFromDb, updateStockInDb, saveSaleRecord, getSalesRecordsFromDb, deleteSaleRecord, closeDatabase.

SQLiteDatabaseService (lib/services/sqlite_database_service.dart)

Purpose: Concrete implementation of DatabaseService for SQLite.

Details: Uses sqflite and sqflite_common_ffi. Handles DB initialization (_initDB), table creation (_onCreate with specific schemas, primary/foreign keys, indexes, and ON DELETE constraints). Implements all CRUD methods using SQL commands (INSERT, UPDATE, DELETE, QUERY). Uses db.transaction for saveSaleRecord and deleteSaleRecord for atomicity within the database operations themselves. Stores DateTime as ISO8601 strings. Requires FFI initialization in main.dart for desktop execution.

7. Data Models (Implemented in v0.2)

Product (lib/models/product.dart)

Attributes: productId (String, PK), itemName (String), currentStock (int), defaultUnitPrice (double).

Includes toMap, fromMap helpers.

SaleItem (lib/models/sale_item.dart)

Attributes: saleItemId (String, PK), saleRecordId (String, FK->SaleRecord), productId (String, FK->Product), itemNameSnapshot (String - captures name at time of sale), quantity (int), unitPrice (double), lineTotal (double - calculated).

Includes toMap, fromMap helpers.

SaleRecord (lib/models/sale_record.dart)

Attributes: recordId (String, PK), saleDate (DateTime), processedTimestamp (DateTime), itemsSold (List<SaleItem>), totalAmount (double), entryMethod (String - e.g., "MANUAL").

Persistence handles the itemsSold list via the separate sale_items table linked by saleRecordId.

8. Key Workflows (Implemented/Partially Implemented in v0.2)

App Initialization: main.dart ensures Flutter bindings, initializes SQFlite FFI (if desktop), creates and initializes DatabaseService, InventoryManager, SalesManager, calls loadInventory(), sets up MultiProvider with manager instances, and runs MyApp starting with MainScreen. Includes basic critical error handling. (Implemented).

Inventory Viewing: User selects "Inventory" tab on MainScreen. InventoryScreen fetches data via InventoryManager, displays sorted list in Cards with stock/price, supports pull-to-refresh. (Implemented).

Add Inventory Product: User taps "+" icon (or Ctrl+N) on InventoryScreen. Navigates to AddEditProductScreen (Add mode). User fills form (with validation/formatting). Taps Save icon (or Ctrl+S). _saveProduct calls InventoryManager.addProduct. On success, navigates back, InventoryScreen refreshes. (Implemented).

Edit Inventory Product: User taps list item or uses menu on InventoryScreen. Navigates to AddEditProductScreen (Edit mode) with data pre-filled. User modifies form. Taps Save icon (or Ctrl+S). _saveProduct calls InventoryManager.updateProduct. On success, navigates back, InventoryScreen refreshes. (Implemented).

Delete Inventory Product: User uses menu on InventoryScreen. Confirmation dialog shown. If confirmed, calls InventoryManager.deleteProduct. Handles potential foreign key constraint errors from DB. InventoryScreen refreshes on success. (Implemented).

Manual Sales Entry: User selects "Record Sale" tab on MainScreen. SalesEntryScreen loads available products for Autocomplete. User selects date, searches/selects product, enters quantity/price. User clicks "+" button to add item to temporary list (_currentSaleItems). List updates, total updates, form clears. User can remove items from list. (Implemented).

Finalize Manual Sale: User clicks "Finalize Sale" button (AppBar or bottom row) or presses Ctrl+Enter on SalesEntryScreen. _finalizeSale validates list isn't empty, converts items to SaleInputItem format, calls SalesManager.createSaleRecord. SalesManager validates stock/decreases stock via InventoryManager, saves record via DatabaseService. Screen shows success/error feedback and clears on success. (Implemented).

Sales History Viewing: User selects "History" tab. SalesHistoryScreen loads, allows date range selection, fetches data via SalesManager, displays sorted list in Cards with total, date, item count, entry method. Supports pull-to-refresh. (Implemented).

Delete Sales Record: Triggered from SalesHistoryScreen via menu. Shows confirmation (warning about no stock reversal). Calls SalesManager.deleteSaleRecord. Refreshes history list. (Implemented).

9. User Interface (Implemented in v0.2)

main.dart: Core setup: WidgetsFlutterBinding, FFI init, manager initialization, MultiProvider, MaterialApp (theme, home route). Includes ErrorAppWidget.

MainScreen (lib/screens/main_screen.dart): Stateful widget acting as the main app shell.

Hosts Scaffold with BottomNavigationBar for Inventory, Record Sale, History tabs.

Uses IndexedStack to preserve state of the child screens when switching tabs.

Manages the selected tab index (_selectedIndex).

Implements Ctrl+1/2/3 hotkeys for tab switching via Actions/Shortcuts.

InventoryScreen (lib/screens/inventory_screen.dart): Stateful widget displaying inventory.

Fetches products via InventoryManager on load.

Displays products in a sorted ListView.builder with Cards showing name, price, stock.

Includes RefreshIndicator (pull-to-refresh).

AppBar action (+ icon) navigates to AddEditProductScreen.

ListTile onTap navigates to AddEditProductScreen (edit mode).

PopupMenuButton on each item for Edit/Delete actions (with confirmation dialog for delete).

Handles loading/error states.

Implements Ctrl+N hotkey via Actions/Shortcuts.

AddEditProductScreen (lib/screens/add_edit_product_screen.dart): Stateful widget for adding/editing products.

Receives optional Product for edit mode.

Uses Form with TextFormFields for name, stock, price. Includes validation and InputFormatters.

Pre-fills data in edit mode.

Handles save logic (_saveProduct) calling InventoryManager.

Navigates back (pop(true)) on successful save.

Shows loading state and user feedback (SnackBars).

Implements Ctrl+S hotkey via Actions/Shortcuts.

SalesEntryScreen (lib/screens/sales_entry_screen.dart): Stateful widget for recording sales.

Allows DateTime selection via showDatePicker.

Uses Autocomplete widget for searchable product selection, loading options from InventoryManager. Handles selection (onSelected), display (displayStringForOption), option list building (optionsViewBuilder), and text input (fieldViewBuilder). Includes clear button. Sets initial focus.

Includes a Form section (_addItemFormKey) for Quantity and Price TextFormFields with validation and focus nodes.

Button (+) to add validated items to the _currentSaleItems list.

Displays _currentSaleItems in a ListView.builder with Cards, showing item details, line total, and a remove button.

Displays running _currentSaleTotal, formatted as currency.

Provides two "Finalize Sale" buttons (AppBar action, bottom row ElevatedButton) calling _finalizeSale.

_finalizeSale calls SalesManager, handles loading state, shows feedback, clears screen on success.

Implements Ctrl+Enter hotkey via Actions/Shortcuts.

SalesHistoryScreen (lib/screens/sales_history_screen.dart): Stateful widget displaying sales history.

Allows date range selection via showDateRangePicker.

Fetches records and totals via SalesManager based on selected range.

Displays records in a ListView.builder with Cards showing date, item count, total, entry method.

Includes RefreshIndicator (though less common here, could be used).

Provides PopupMenuButton on each item for "View Items" (shows dialog) and "Delete Record" (with confirmation).

Handles loading/error/empty states.

Initializes with a default date range (e.g., current month).

10. Next Steps / Things To Do (Post v0.2 - Phase 1 Refinements)

(Complex) Implement Stock Reversal on Sale Deletion:

Modify SalesManager.deleteSaleRecord.

Fetch SaleItems for the record before deleting it.

Call InventoryManager.increaseStock for each item.

Implement robust transaction/compensating logic to handle potential failures during stock increase or sale deletion. Update user confirmation dialog warning based on implementation success.

Refine Error Handling & User Feedback:

Review all try-catch blocks and ScaffoldMessenger messages for clarity and user-friendliness.

Improve handling of critical initialization errors in main.dart.

(Optional) Add Basic Tests:

Unit tests for InventoryManager & SalesManager logic (mocking DatabaseService).

Widget tests for AddEditProductScreen form validation or simpler components.

11. Phase 2: OCR Integration Plan (Future)

(Remains the same - Outlines OCR goal, new components, integration strategy)

12. Technology Stack (Used in v0.2)

Language: Dart (Version: [Insert Dart Version from 'flutter --version'])

Framework: Flutter (Version: [Insert Flutter Version from 'flutter --version'])

State Management / DI: provider (Version: ^6.0.5 or latest used)

Data Persistence: sqflite (Version: ^2.3.0 or latest used)

Desktop DB Support: sqflite_common_ffi (Version: ^2.3.0 or latest used)

Utilities:

path (Version: ^1.8.3 or latest used) - For DB path

uuid (Version: ^4.2.1 or latest used) - For unique IDs

intl (Version: ^0.18.1 or latest used) - For Date/Number formatting

13. Setup & Running

Ensure Flutter SDK (matching version above or compatible) is installed.

For Windows Desktop target: Install Visual Studio (2022+) with "Desktop development with C++" workload. Enable Developer Mode in Windows Settings.

Obtain project source code.

Open project in a compatible IDE (VS Code recommended).

Run flutter pub get in the terminal within the project directory.

In the IDE, select target device: "Windows (desktop)" (or other compatible native platform). Do NOT select "Web".

Run the application (e.g., F5 in VS Code or flutter run -d windows).

14. Future Considerations (Long Term)

(Remains the same - Lists potential distant future enhancements like reporting, backup, barcode scanning, multi-user, etc.)

15. Documentation Maintenance

(Remains the same - Emphasizes keeping docs updated alongside code changes)

This v0.2 document provides a very detailed snapshot of the project, including what's done, how it's implemented architecturally, and what the immediate next steps are. Remember to fill in the specific Flutter/Dart versions when you generate this for real.

14. Future Considerations

Phase 1 Completion: UI for Sales Entry and Sales History viewing.

Phase 2: OCR Integration.

More sophisticated reporting (profit, trends).

Data backup/restore/sync.

Barcode scanning.

Enhanced error handling and user feedback.

Refined UI/UX.

Testing (Unit, Widget, Integration).

15. Documentation Maintenance

This document should be updated concurrently with development, especially when:

Data models are changed.

Function signatures in core managers/services are modified.

Key workflows or UI screens are added/altered.

Decisions about future implementation details are made.

This document (v0.1) reflects the current state where the core backend logic for inventory and sales is established, and the UI for managing inventory is functional. The next steps involve building the UI for sales entry and history.
