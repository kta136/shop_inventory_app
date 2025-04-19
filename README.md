Okay, here is the complete project documentation, updated to **Version 0.3**, incorporating the full implementation details up to the `SalesHistoryScreen`, the currency change, hotkeys, and the detailed notes on the unresolved focus issue in `SalesEntryScreen`.

---

# **Project Documentation: Shop Sales & Inventory Manager**

**Version:** 0.3
**Date:** 2023-10-27 (Updated)

**Table of Contents:**

1.  [Introduction](#1-introduction)
2.  [Goals & Scope](#2-goals--scope)
3.  [Target Platform & User](#3-target-platform--user)
4.  [Development Phases](#4-development-phases)
5.  [High-Level Architecture](#5-high-level-architecture)
6.  [Core Modules & Classes (Implemented in v0.3)](#6-core-modules--classes-implemented-in-v03)
7.  [Data Models (Implemented in v0.3)](#7-data-models-implemented-in-v03)
8.  [Key Workflows (Implemented/Partially Implemented in v0.3)](#8-key-workflows-implementedpartially-implemented-in-v03)
9.  [User Interface (Implemented in v0.3)](#9-user-interface-implemented-in-v03)
10. [Next Steps / Things To Do (Post v0.3 - Phase 1 Refinements)](#10-next-steps--things-to-do-post-v03---phase-1-refinements)
11. [Phase 2: OCR Integration Plan (Future)](#11-phase-2-ocr-integration-plan-future)
12. [Technology Stack (Used in v0.3)](#12-technology-stack-used-in-v03)
13. [Setup & Running](#13-setup--running)
14. [Future Considerations (Long Term)](#14-future-considerations-long-term)
15. [Documentation Maintenance](#15-documentation-maintenance)

---

## 1. Introduction

The **Shop Sales & Inventory Manager** is a cross-platform application designed to help a small shop owner manage daily sales records and maintain product inventory levels digitally. Version 0.3 completes the core manual entry functionality (Phase 1), providing screens for inventory management, sales recording, and viewing sales history, all functional on native desktop platforms with INR (₹) as the default currency.

## 2. Goals & Scope

*   **Primary Goal:** Accurately record sales transactions and update inventory stock levels accordingly.
*   **Secondary Goal:** Provide simple views for sales history and current inventory status.
*   **Scope (v0.3 - Phase 1 Implemented):**
    *   Core data models (`Product`, `SaleItem`, `SaleRecord`).
    *   SQLite database persistence (`sqflite`, `sqflite_common_ffi` for desktop).
    *   `InventoryManager` for product CRUD and stock operations.
    *   `SalesManager` logic for creating sales (manual entry), deleting sales, and retrieving history/totals.
    *   Dependency injection setup using `Provider`.
    *   Main application navigation using `BottomNavigationBar` (`MainScreen`).
    *   Functional UI (`InventoryScreen`) for viewing, adding, editing (via `AddEditProductScreen`), and deleting inventory items, including pull-to-refresh and keyboard shortcuts.
    *   Functional UI (`SalesEntryScreen`) for manually recording sales: date selection, searchable product selection (`Autocomplete`), quantity/price input, temporary item list management, finalizing sales (triggers `SalesManager`), user feedback, screen clearing, initial focus management, and keyboard shortcuts.
    *   Functional UI (`SalesHistoryScreen`) for viewing sales history: date range selection, list display, total display, view item details dialog, record deletion with confirmation, and basic refresh action.
    *   Keyboard shortcuts (Hotkeys) implemented for primary actions across screens (tab switching, new product, save product, finalize sale).
    *   Currency formatting updated to display Indian Rupees (INR - ₹) throughout the UI.
*   **Scope (Future - Phase 1 Refinements):**
    *   UI/UX Refinements (e.g., `SalesEntryScreen` Autocomplete hover highlighting, focus fixes).
    *   Implementation of complex features like stock reversal on sale deletion.
    *   Comprehensive error handling review.
    *   Addition of unit and widget tests.
*   **Scope (Future - Phase 2):** OCR integration for automated sales entry from images.

## 3. Target Platform & User

*   **Platform (v0.3 Validated):** Windows Desktop.
*   **Platform (Code Compatible):** Android, iOS (via Flutter and `sqflite` standard implementation). Linux, macOS Desktop (via Flutter and `sqflite_common_ffi`).
*   **Platform (Excluded):** Web (due to `sqflite` limitations).
*   **User:** Single primary user (shop owner/manager).

## 4. Development Phases

*   **Phase 1 (Completed - v0.3):** Implemented the core application logic with manual data entry. Built the foundation for inventory management, sales recording, data persistence, and the primary user interfaces (Inventory, Sales Entry, Sales History) with basic functionality and keyboard support. Currency set to INR.
*   **Phase 1 Refinements (Post v0.3):** Focus on improving usability (autocomplete hover, focus issues), adding complex features (stock reversal), enhancing robustness (error handling, testing).
*   **Phase 2 (Future Implementation):** Add functionality to upload JPEG images, process via OCR, allow user confirmation, and record sales automatically.

## 5. High-Level Architecture

The application follows a layered architecture pattern:

1.  **User Interface (UI):** Built with Flutter. Handles user interaction, displays data, gathers input. Managed via `MainScreen` with `BottomNavigationBar`. Includes `InventoryScreen`, `AddEditProductScreen`, `SalesEntryScreen`, and `SalesHistoryScreen`.
2.  **Business Logic Layer:** Contains core application logic. Dependencies are injected/managed via `Provider`.
    *   `InventoryManager`: Manages product data (CRUD, stock). Implemented.
    *   `SalesManager`: Manages sales records (create, delete, retrieve). Implemented.
    *   *(Phase 2)* `ImageProcessor`, `SalesDataParser`: (Not Implemented).
3.  **Data Persistence Layer:** Abstracts database interactions.
    *   `DatabaseService`: Interface defining persistence contract. Implemented.
    *   `SQLiteDatabaseService`: Concrete implementation using `sqflite` / `sqflite_common_ffi`. Handles SQL operations, table creation, transactions. Implemented.
    *   `SQLite Database`: Local file (`shop_inventory.db`).

**Dependency Flow:** UI Widgets -> access Managers (via Provider) -> Managers -> use DatabaseService -> DatabaseService -> interacts with SQLite DB.

## 6. Core Modules & Classes (Implemented in v0.3)

*   **`InventoryManager` (`lib/managers/inventory_manager.dart`)**
    *   **Purpose:** Central point for managing product catalog and stock levels. Uses an in-memory cache (`_productsCache`) synchronized with the database for performance.
    *   **Dependencies:** `DatabaseService`. Injected via constructor.
    *   **Key Functions:** `loadInventory()`, `addProduct()`, `updateProduct()`, `deleteProduct()`, `getProductById()`, `findProductByName()`, `getAllProducts()` (returns `List.unmodifiable`), `decreaseStock()`, `increaseStock()`.
    *   **Details:** Generates UUIDs for new products. Requires `loadInventory()` call on app startup. Performs client-side checks (e.g., duplicate name on add, sufficient stock on decrease). Handles database constraint errors on delete (e.g., if product is in a sale).

*   **`SalesManager` (`lib/managers/sales_manager.dart`)**
    *   **Purpose:** Handles creation, retrieval, deletion, and aggregation of sales records. Interacts with `InventoryManager` for stock validation and updates during sale creation.
    *   **Dependencies:** `DatabaseService`, `InventoryManager`. Injected via constructor.
    *   **Key Functions:** `createSaleRecord()`, `getSalesHistory()`, `calculateTotalSales()`, `deleteSaleRecord()`.
    *   **Details:** `createSaleRecord` uses `SaleInputItem` record type, validates input, checks product existence, attempts `InventoryManager.decreaseStock` for all items *before* saving the sale record to the database (this sequence has atomicity limitations between stock update and sale save). `deleteSaleRecord` calls `DatabaseService` to remove the record (associated items deleted via DB cascade). **Note:** `deleteSaleRecord` currently **does not** revert inventory stock changes automatically; this is marked as a complex future enhancement requiring careful transaction management and error handling (See To-Do List).

*   **`DatabaseService` (`lib/services/database_service.dart`)**
    *   **Purpose:** Abstract interface (abstract class) defining the contract for data persistence operations, decoupling business logic from SQLite specifics.
    *   **Methods:** `initDatabase`, `saveProduct`, `deleteProduct`, `getAllProductsFromDb`, `getProductByIdFromDb`, `updateStockInDb`, `saveSaleRecord`, `getSalesRecordsFromDb`, `deleteSaleRecord`, `closeDatabase`.

*   **`SQLiteDatabaseService` (`lib/services/sqlite_database_service.dart`)**
    *   **Purpose:** Concrete implementation of `DatabaseService` for SQLite.
    *   **Details:** Uses `sqflite` and `sqflite_common_ffi`. Handles DB initialization (`_initDB`), table creation (`_onCreate` with specific schemas, primary/foreign keys, indexes, and `ON DELETE` constraints). Implements all CRUD methods using SQL commands (`INSERT`, `UPDATE`, `DELETE`, `QUERY`). Uses `db.transaction` for `saveSaleRecord` and `deleteSaleRecord` for atomicity within the database operations themselves. Stores `DateTime` as ISO8601 strings. Requires FFI initialization in `main.dart` for desktop execution.

## 7. Data Models (Implemented in v0.3)

*   **`Product` (`lib/models/product.dart`)**
    *   Attributes: `productId` (String, PK), `itemName` (String), `currentStock` (int), `defaultUnitPrice` (double).
    *   Includes `toMap`, `fromMap` helpers.

*   **`SaleItem` (`lib/models/sale_item.dart`)**
    *   Attributes: `saleItemId` (String, PK), `saleRecordId` (String, FK->SaleRecord), `productId` (String, FK->Product), `itemNameSnapshot` (String - captures name at time of sale), `quantity` (int), `unitPrice` (double), `lineTotal` (double - calculated).
    *   Includes `toMap`, `fromMap` helpers.

*   **`SaleRecord` (`lib/models/sale_record.dart`)**
    *   Attributes: `recordId` (String, PK), `saleDate` (DateTime), `processedTimestamp` (DateTime), `itemsSold` (List<SaleItem>), `totalAmount` (double), `entryMethod` (String - e.g., "MANUAL").
    *   Persistence handles the `itemsSold` list via the separate `sale_items` table linked by `saleRecordId`.

## 8. Key Workflows (Implemented/Partially Implemented in v0.3)

*   **App Initialization:** `main.dart` ensures Flutter bindings, initializes SQFlite FFI (if desktop), creates and initializes `DatabaseService`, `InventoryManager`, `SalesManager`, calls `loadInventory()`, sets up `MultiProvider` with manager instances, and runs `MyApp` starting with `MainScreen`. Includes basic critical error handling. (Implemented).
*   **Inventory Viewing:** User selects "Inventory" tab on `MainScreen`. `InventoryScreen` fetches data via `InventoryManager`, displays sorted list in `Card`s with stock/price, supports pull-to-refresh. (Implemented).
*   **Add Inventory Product:** User taps "+" icon (or `Ctrl+N`) on `InventoryScreen`. Navigates to `AddEditProductScreen` (Add mode). User fills form (with validation/formatting). Taps Save icon (or `Ctrl+S`). `_saveProduct` calls `InventoryManager.addProduct`. On success, navigates back, `InventoryScreen` refreshes. (Implemented).
*   **Edit Inventory Product:** User taps list item or uses menu on `InventoryScreen`. Navigates to `AddEditProductScreen` (Edit mode) with data pre-filled. User modifies form. Taps Save icon (or `Ctrl+S`). `_saveProduct` calls `InventoryManager.updateProduct`. On success, navigates back, `InventoryScreen` refreshes. (Implemented).
*   **Delete Inventory Product:** User uses menu on `InventoryScreen`. Confirmation dialog shown. If confirmed, calls `InventoryManager.deleteProduct`. Handles potential foreign key constraint errors from DB. `InventoryScreen` refreshes on success. (Implemented).
*   **Manual Sales Entry:** User selects "Record Sale" tab on `MainScreen`. `SalesEntryScreen` loads available products for `Autocomplete`. User selects date, searches/selects product, enters quantity/price. User clicks "+" button to add item to temporary list (`_currentSaleItems`). List updates, total updates, form clears. User can remove items from list. (Implemented - *Known issue: Focus doesn't reliably return to product field after adding*).
*   **Finalize Manual Sale:** User clicks "Finalize Sale" button (AppBar or bottom row) or presses `Ctrl+Enter` on `SalesEntryScreen`. `_finalizeSale` validates list isn't empty, converts items to `SaleInputItem` format, calls `SalesManager.createSaleRecord`. `SalesManager` validates stock/decreases stock via `InventoryManager`, saves record via `DatabaseService`. Screen shows success/error feedback and clears on success. (Implemented).
*   **Sales History Viewing:** User selects "History" tab. `SalesHistoryScreen` loads, allows date range selection via `showDateRangePicker`, fetches data via `SalesManager`, displays sorted list in `Card`s with total, date, item count, entry method. Displays total sales for the period. (Implemented).
*   **View Sale Details:** User taps history item or uses menu on `SalesHistoryScreen`. `_showSaleDetailsDialog` displays item list in an `AlertDialog`. (Implemented).
*   **Delete Sales Record:** User uses menu on `SalesHistoryScreen`. Shows confirmation (warning about no stock reversal). Calls `SalesManager.deleteSaleRecord`. Refreshes history list. (Implemented).

## 9. User Interface (Implemented in v0.3)

*   **`main.dart`:** Core setup: `WidgetsFlutterBinding`, FFI init, manager initialization, `MultiProvider`, `MaterialApp` (theme, home route). Includes `ErrorAppWidget`. Currency formatting using `intl` package configured for INR (₹).
*   **`MainScreen` (`lib/screens/main_screen.dart`)**: Stateful widget acting as the main app shell. Hosts `Scaffold`, `BottomNavigationBar`, `IndexedStack`. Manages selected tab index. Implements `Ctrl+1/2/3` hotkeys. Tab labels include hotkey hints.
*   **`InventoryScreen` (`lib/screens/inventory_screen.dart`)**: Stateful widget displaying inventory. Fetches/displays sorted products list (`Card`s, `ListView`). Includes `RefreshIndicator`. Add/Edit/Delete actions via AppBar/`ListTile`/`PopupMenuButton` (with confirmation). Handles loading/error states. Implements `Ctrl+N` hotkey. Currency displayed is INR (₹).
*   **`AddEditProductScreen` (`lib/screens/add_edit_product_screen.dart`)**: Stateful widget for adding/editing products. Handles Add/Edit modes. Uses `Form` with validation/`InputFormatters`. Pre-fills data. Saves via `InventoryManager`. Navigates back on success. Handles loading state, feedback (SnackBars). Implements `Ctrl+S` hotkey. Currency prefix/hint updated to INR (₹). Focus flow between fields implemented.
*   **`SalesEntryScreen` (`lib/screens/sales_entry_screen.dart`)**: Stateful widget for recording sales. Allows date selection. Uses `Autocomplete` for searchable product selection with loading state. Includes `Form` section for Quantity/Price validation. Manages temporary list of sale items (`_currentSaleItems`) with add/remove functionality. Displays running total. Finalize/Save actions via AppBar/Bottom Button/`Ctrl+Enter` trigger `SalesManager`. Handles loading/feedback/clearing state. Currency displayed/input updated to INR (₹). Initial focus set to product search. **Known Issue:** Focus does not reliably return to product field after adding an item.
*   **`SalesHistoryScreen` (`lib/screens/sales_history_screen.dart`)**: Stateful widget displaying sales history. Allows date range selection (`showDateRangePicker`). Fetches records/totals via `SalesManager`. Displays records (`Card`s, `ListView`) with date, item count, total, entry method. Displays total sales for period. Handles loading/error/empty states. Provides "View Items" dialog and "Delete Record" action (with confirmation) via `PopupMenuButton`. Currency formatted as INR (₹).

## 10. Next Steps / Things To Do (Post v0.3 - Phase 1 Refinements)

1.  **(Complex)** Implement **Stock Reversal on Sale Deletion:**
    *   Modify `SalesManager.deleteSaleRecord`.
    *   Fetch `SaleItem`s before deleting the `SaleRecord`.
    *   Call `InventoryManager.increaseStock` for each item.
    *   Implement robust transaction/compensating logic to handle potential failures. Update user confirmation dialog.

2.  **Refine `SalesEntryScreen` Autocomplete:**
    *   Add visual highlighting (e.g., background color change) on mouse hover for product suggestions in `optionsViewBuilder`.

3.  **Improve Keyboard Navigation & Focus Flow:** *(Partially Addressed - Issue Remaining)*
    *   **Issue:** In `SalesEntryScreen`, after adding an item via `_addItemToSale`, the input focus does not reliably return to the Product Autocomplete field (`_productFocusNode`).
        *   *Solutions Attempted (Unsuccessful):* Direct `requestFocus()`, `requestFocus()` inside `addPostFrameCallback`, `requestFocus()` after `Future.delayed()`, `unfocus()` followed by delayed `requestFocus()`.
        *   *Next Steps (If Revisited):* Investigate potential interference from `Autocomplete`'s internal focus management, timing issues after `setState`, or other widgets grabbing focus. May require deeper focus debugging or alternative focus request strategies.
    *   **Task:** Verify focus flow between fields in `AddEditProductScreen` (Name -> Stock -> Price -> Save) using Enter/Tab works reliably.
    *   **Task (Advanced):** Explore keyboard navigation within lists (`InventoryScreen`, `SalesHistoryScreen`).
    *   **Task:** Verify keyboard navigability within dialogs.

4.  **Implement Currency Change (USD to INR):** *(Done - Implemented in v0.3)*
    *   ~~Update currency formatting (`\$` to `₹ `) throughout the UI.~~

5.  **Refine Error Handling & User Feedback:**
    *   Review all `try-catch` blocks and user messages for clarity. Improve presentation of errors caught during initialization or manager operations.

6.  **(Optional but Recommended) Add Basic Tests:**
    *   Unit tests for `InventoryManager` & `SalesManager` logic (mocking `DatabaseService`).
    *   Widget tests for `AddEditProductScreen` form validation or key UI interactions.

## 11. Phase 2: OCR Integration Plan (Future)

*(Remains the same - Outlines OCR goal, new components (`ImageProcessor`, `SalesDataParser`, `OcrConfirmationScreen`), integration strategy, deferred technology choice)*

## 12. Technology Stack (Used in v0.3)

*   **Language:** Dart (Version: `[Insert Dart Version from 'flutter --version']`)
*   **Framework:** Flutter (Version: `[Insert Flutter Version from 'flutter --version']`)
*   **State Management / DI:** `provider` (Version: `^6.1.1` or latest used) *(Example version update)*
*   **Data Persistence:** `sqflite` (Version: `^2.3.0` or latest used)
*   **Desktop DB Support:** `sqflite_common_ffi` (Version: `^2.3.0` or latest used)
*   **Utilities:**
    *   `path` (Version: `^1.8.3` or latest used) - For DB path
    *   `uuid` (Version: `^4.2.1` or latest used) - For unique IDs
    *   `intl` (Version: `^0.18.1` or latest used) - For Date/Number/Currency formatting (Configured for INR ₹)

## 13. Setup & Running

*(Remains the same as v0.2 - Ensure Flutter/VS/C++ setup, clone, pub get, select Windows target, run)*

## 14. Future Considerations (Long Term)

*(Remains the same - Dashboard, Categories, Profit Tracking, Charts, Export, Backup, Barcode, etc.)*

## 15. Documentation Maintenance

*(Remains the same - Emphasizes keeping docs updated)*

---

This v0.3 documentation should accurately reflect the project's current state, including the completed Phase 1 core features and the outstanding refinements.

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

16. Future Considerations

Phase 1 Completion: UI for Sales Entry and Sales History viewing.

Phase 2: OCR Integration.

More sophisticated reporting (profit, trends).

Data backup/restore/sync.

Barcode scanning.

Enhanced error handling and user feedback.

Refined UI/UX.

Testing (Unit, Widget, Integration).

17. Documentation Maintenance

This document should be updated concurrently with development, especially when:

Data models are changed.

Function signatures in core managers/services are modified.

Key workflows or UI screens are added/altered.

Decisions about future implementation details are made.

This document (v0.1) reflects the current state where the core backend logic for inventory and sales is established, and the UI for managing inventory is functional. The next steps involve building the UI for sales entry and history.
