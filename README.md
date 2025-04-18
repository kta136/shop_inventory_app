    Project Documentation: Shop Sales & Inventory Manager

Version: 0.1
Date: 2023-10-27 (Updated)

Table of Contents:

Introduction

Goals & Scope

Target Platform & User

Development Phases

High-Level Architecture

Core Modules & Classes (Implemented in v0.1)

Data Models (Implemented in v0.1)

Key Workflows (Implemented/Partially Implemented in v0.1)

User Interface (Implemented in v0.1)

Phase 2: OCR Integration Plan (Future)

Technology Stack (Used in v0.1)

Setup & Running

Future Considerations

Documentation Maintenance

1. Introduction

The Shop Sales & Inventory Manager is a cross-platform application designed to help a small shop owner manage daily sales records and maintain product inventory levels. It aims to replace or supplement manual tracking methods, providing a digital record and basic reporting capabilities. Version 0.1 focuses on establishing the core inventory management functionality.

2. Goals & Scope

Primary Goal: Accurately record sales transactions and update inventory stock levels accordingly.

Secondary Goal: Provide simple views for sales history and current inventory status.

Scope (v0.1 - Phase 1):

Implement core data models.

Implement database persistence using SQLite for native platforms (Windows, Android, iOS).

Implement InventoryManager for product CRUD and stock operations.

Implement SalesManager logic for creating sales and retrieving history.

Implement basic UI for viewing, adding, editing, and deleting inventory items.

Setup dependency injection using Provider.

Scope (Future - Phase 1 Continued):

Implement UI for manual sales entry.

Implement UI for viewing sales history.

Scope (Future - Phase 2): Integrate Optical Character Recognition (OCR) to automate sales data entry from uploaded handwritten JPEG images.

3. Target Platform & User

Platform (v0.1 Focus): Windows Desktop (validated), Android/iOS (code compatible via Flutter/SQLite). Web is explicitly excluded due to SQLite limitations.

User: Single primary user (shop owner/manager).

4. Development Phases

Phase 1 (v0.1 In Progress): Implement the core application logic with manual data entry. Build the foundation for inventory management, sales recording, data persistence, and the user interface for these tasks. v0.1 completes the inventory management backend and UI.

Phase 2 (Future Implementation): Add functionality to upload JPEG images of handwritten sales notes, process them using an OCR solution, allow user confirmation/correction of extracted data, and record the sale automatically.

5. High-Level Architecture

The application follows a layered architecture pattern:

User Interface (UI): Handles user interaction, data display, and input gathering. Built using Flutter. (Implemented: Inventory screens).

Business Logic Layer: Contains the core application logic. Dependencies managed via Provider.

InventoryManager: Manages product data and stock levels. (Implemented).

SalesManager: Orchestrates the creation and retrieval of sales records. (Implemented).

(Phase 2) ImageProcessor, SalesDataParser: Handle OCR processing. (Not Implemented).

Data Persistence Layer:

DatabaseService: Abstract interface for persistence. (Implemented).

SQLiteDatabaseService: Concrete implementation using sqflite and sqflite_common_ffi for desktop compatibility. (Implemented).

SQLite Database: Local storage file (shop_inventory.db).

6. Core Modules & Classes (Implemented in v0.1)

InventoryManager (lib/managers/inventory_manager.dart)

Purpose: Manages product catalog and stock levels via an in-memory cache synchronized with the database.

Dependencies: DatabaseService.

Key Functions: loadInventory, addProduct, updateProduct, deleteProduct, getProductById, findProductByName, getAllProducts (returns unmodifiable list), decreaseStock, increaseStock.

Notes: Handles UUID generation for new products. Requires loadInventory call on startup. Implemented basic duplicate name check on add. Includes error handling for database constraints during deletion.

SalesManager (lib/managers/sales_manager.dart)

Purpose: Handles the creation and retrieval of sales records, interacts with InventoryManager for stock validation/updates.

Dependencies: DatabaseService, InventoryManager.

Key Functions: createSaleRecord (validates stock, decreases via InventoryManager, saves via DatabaseService), getSalesHistory, calculateTotalSales.

Notes: Uses SaleInputItem type alias for input. createSaleRecord attempts stock decrease before saving but atomicity across managers has limitations.

DatabaseService (lib/services/database_service.dart)

Purpose: Abstract interface defining the contract for data persistence operations.

Key Functions: initDatabase, saveProduct, deleteProduct, getAllProductsFromDb, getProductByIdFromDb, updateStockInDb, saveSaleRecord, getSalesRecordsFromDb, closeDatabase.

SQLiteDatabaseService (lib/services/sqlite_database_service.dart)

Purpose: Concrete implementation of DatabaseService using sqflite (and sqflite_common_ffi for desktop).

Key Functions: Implements all functions from DatabaseService. Handles database initialization, table creation (_onCreate), CRUD operations using SQL commands, and transactional saving for SaleRecord and its SaleItems.

Notes: Stores dates as ISO8601 strings. Uses Foreign Keys with ON DELETE CASCADE (SaleItems) and ON DELETE RESTRICT (Products). Requires FFI initialization in main.dart for desktop.

7. Data Models (Implemented in v0.1)

Product (lib/models/product.dart)

Attributes: productId (String, PK), itemName (String), currentStock (int), defaultUnitPrice (double).

Methods: Includes toMap, fromMap for database interaction.

SaleItem (lib/models/sale_item.dart)

Attributes: saleItemId (String, PK), saleRecordId (String, FK), productId (String, FK), itemNameSnapshot (String), quantity (int), unitPrice (double), lineTotal (double, calculated).

Methods: Includes toMap, fromMap. lineTotal calculated in constructor.

SaleRecord (lib/models/sale_record.dart)

Attributes: recordId (String, PK), saleDate (DateTime), processedTimestamp (DateTime), itemsSold (List<SaleItem>), totalAmount (double), entryMethod (String).

Notes: Database persistence handles storing/retrieving the itemsSold list via the separate sale_items table.

8. Key Workflows (Implemented/Partially Implemented in v0.1)

App Initialization: main.dart initializes Flutter, sets up SQFlite FFI for desktop, initializes DatabaseService, InventoryManager, SalesManager, loads initial inventory, and provides managers via Provider. Handles critical initialization errors. (Implemented).

View Inventory: InventoryScreen fetches product list from InventoryManager via Provider, handles loading/error states, displays products sorted alphabetically in Cards. Includes pull-to-refresh. (Implemented).

Add Product: Navigate from InventoryScreen to AddEditProductScreen (Add mode). User enters details into a validated Form. On save, calls InventoryManager.addProduct, returns to InventoryScreen, refreshes list. (Implemented).

Edit Product: Navigate from InventoryScreen (tap item or use menu) to AddEditProductScreen (Edit mode) with pre-filled data. User edits details. On save, calls InventoryManager.updateProduct, returns, refreshes list. (Implemented).

Delete Product: Triggered from InventoryScreen popup menu. Shows confirmation dialog. Calls InventoryManager.deleteProduct. Refreshes list on success. Handles potential DB constraint errors. (Implemented).

Record Sale: SalesManager.createSaleRecord logic is implemented. (UI for triggering this not yet implemented).

View Sales History: SalesManager.getSalesHistory and calculateTotalSales logic implemented. (UI not yet implemented).

9. User Interface (Implemented in v0.1)

main.dart: Sets up MaterialApp, theme, MultiProvider, and routes initial screen. Includes error widget for initialization failures.

InventoryScreen (lib/screens/inventory_screen.dart):

Displays a list of products using ListView.builder and Cards.

Shows product name, price, and stock.

Includes pull-to-refresh (RefreshIndicator).

AppBar action button navigates to Add Product screen.

List items are tappable to navigate to Edit Product screen.

Includes PopupMenuButton on each item for Edit/Delete actions.

Handles loading and error states.

AddEditProductScreen (lib/screens/add_edit_product_screen.dart):

Single screen for both adding and editing products (isEditMode).

Uses Form with TextFormFields for name, stock, price.

Includes input validation and input formatters.

Pre-fills data when editing.

Calls appropriate InventoryManager method on save.

Navigates back on successful save, returning true.

Shows loading indicator and handles save errors with SnackBars.

9. User Interface (Implemented in v0.1)
main.dart: Sets up MaterialApp, theme, MultiProvider, and routes initial screen. Includes error widget for initialization failures.
InventoryScreen (lib/screens/inventory_screen.dart):
Displays a list of products using ListView.builder and Cards.
Shows product name, price, and stock.
Includes pull-to-refresh (RefreshIndicator).
AppBar action button navigates to Add Product screen.
List items are tappable to navigate to Edit Product screen.
Includes PopupMenuButton on each item for Edit/Delete actions.
Handles loading and error states.
AddEditProductScreen (lib/screens/add_edit_product_screen.dart):
Single screen for both adding and editing products (isEditMode).
Uses Form with TextFormFields for name, stock, price.
Includes input validation and input formatters.
Pre-fills data when editing.
Calls appropriate InventoryManager method on save.
Navigates back on successful save, returning true.
Shows loading indicator and handles save errors with SnackBars.


10. Next Steps / Things To Do (Towards Phase 1 Completion)
This section outlines the immediate tasks required to continue development from the current state (v0.1) and complete the core manual entry features of Phase 1.
Implement Navigation:
Choose and implement a primary navigation method (e.g., BottomNavigationBar, Drawer).
Create placeholder screens/routing for "Sales Entry" and "Sales History".
Integrate InventoryScreen into this navigation structure. Update MyApp in main.dart to use the main navigation widget instead of directly showing InventoryScreen.
Implement SalesEntryScreen:
Create lib/screens/sales_entry_screen.dart.
Design UI to:
Select the sale date (DatePickerDialog).
Allow adding multiple items to the sale:
Use a dropdown or search functionality (e.g., DropdownButtonFormField, Autocomplete) to select a Product from the list provided by InventoryManager.getAllProducts().
Input fields for quantity and unit_price (pre-fill price from selected product's defaultUnitPrice).
Button to add the selected item details to a temporary list for the current sale.
Display the list of items added to the current sale with calculated lineTotal and a running grand totalAmount.
Allow removing items from the temporary list before finalizing.
Implement a "Finalize Sale" button that:
Collects the data into the List<SaleInputItem> format.
Calls SalesManager.createSaleRecord via Provider.
Handles loading states and potential errors (insufficient stock, etc.) returned from the SalesManager.
Clears the form or navigates away on success.
Implement SalesHistoryScreen:
Create lib/screens/sales_history_screen.dart.
Design UI to:
Allow selection of a date range (start and end dates).
Display a list of SaleRecords fetched using SalesManager.getSalesHistory for the selected range.
For each record, show key info (e.g., saleDate, totalAmount, maybe number of items).
Optionally, allow tapping a record to view its details (the SaleItem list).
Display the total sales for the selected period using SalesManager.calculateTotalSales.
Handle loading and error states.
Refine Error Handling & User Feedback:
Review existing error handling (try-catch blocks, SnackBars).
Ensure user-friendly messages are shown instead of raw exception strings where appropriate (e.g., use custom dialogs or formatted SnackBars).
Consider edge cases (e.g., what happens if InventoryManager.loadInventory fails critically in main - ensure the ErrorAppWidget path is robust).
(Optional but Recommended) Add Basic Tests:
Write unit tests for methods in InventoryManager and SalesManager, mocking their dependencies (DatabaseService).
Consider writing widget tests for simpler UI components or screens like AddEditProductScreen to verify form validation and basic interaction.

11. Phase 2: OCR Integration Plan (Future)

(This section remains the same as the initial plan)

Goal: Allow users to upload a JPEG image of a handwritten sales note and automatically populate the sale entry form for confirmation and saving.

New Components: ImageProcessor, SalesDataParser, OcrConfirmationScreen (UI).

Integration Strategy: Add "Upload Sale Image" option. Trigger ImageProcessor -> SalesDataParser -> OcrConfirmationScreen. Confirmed data uses existing SalesManager.create_sale_record with entryMethod="OCR".

Minimal Impact on Core Logic: SalesManager and InventoryManager operate on structured data, independent of source (manual vs. OCR).

Deferred Technology Choice: Specific OCR tool (Cloud API, Tesseract, AI Model) to be decided in Phase 2.

12. Technology Stack (Used in v0.1)

Language: Dart (SDK version from flutter --version)

Framework: Flutter (version from flutter --version)

State Management / Dependency Injection: provider

Data Persistence: sqflite (with sqflite_common_ffi for desktop)

Database: SQLite

Utilities: path (for DB path), uuid (for unique IDs)

13. Setup & Running

Ensure Flutter SDK is installed for the target platform (Windows setup documented previously).

For Windows Desktop: Ensure Visual Studio with "Desktop development with C++" workload is installed.

Clone the repository/obtain the source code.

Open the project in VS Code (or Android Studio).

Run flutter pub get to install dependencies.

Select the target device/platform (e.g., "Windows (desktop)"). Do not select "Web".

Run the application (e.g., F5 in VS Code).

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