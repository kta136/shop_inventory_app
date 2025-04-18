// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io'; // Import dart:io to check the platform
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Import your project files
import 'managers/inventory_manager.dart';
import 'managers/sales_manager.dart'; // <-- Import SalesManager
import 'models/product.dart';
import 'services/database_service.dart';
import 'services/sqlite_database_service.dart';

// Import the screen (we will rename/create this soon)
import 'screens/inventory_screen.dart'; // <-- Adjusted path


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    print("Running on Desktop, Initializing sqflite FFI...");
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    print("sqflite FFI Initialized.");
  }

  print("Starting App Initialization...");

  DatabaseService? initializedDbService;
  InventoryManager? initializedInventoryManager;
  SalesManager? initializedSalesManager; // <-- Add variable for SalesManager
  bool initSuccess = false;

  try {
    print("Creating Database Service...");
    initializedDbService = SQLiteDatabaseService();
    print("Database Service Created.");

    print("Initializing Database...");
    await initializedDbService.initDatabase();
    print("Database Initialized Successfully.");

    print("Creating Inventory Manager...");
    initializedInventoryManager = InventoryManager(initializedDbService);
    print("Inventory Manager Created.");

    print("Loading Inventory...");
    await initializedInventoryManager.loadInventory();
    print("Inventory Loaded Successfully.");

    // --- Initialize SalesManager --- <-- ADDED ---
    print("Creating Sales Manager...");
    initializedSalesManager = SalesManager(initializedDbService, initializedInventoryManager);
    print("Sales Manager Created.");
    // --- End SalesManager Init ---

    initSuccess = true;

  } catch (e, stackTrace) {
     print("!!! CRITICAL ERROR DURING INITIALIZATION: $e");
     print("!!! StackTrace: $stackTrace");
  }

  if (!initSuccess || initializedInventoryManager == null || initializedDbService == null || initializedSalesManager == null) { // <-- Check SalesManager too
     print("Initialization failed. Running Error App (Placeholder).");
     runApp(ErrorAppWidget("App initialization failed. Please check logs and restart."));
     return;
  }

  print("Initialization Complete. Running App with Provider...");

  runApp(
    MultiProvider(
      providers: [
        Provider<InventoryManager>(create: (_) => initializedInventoryManager!),
        Provider<DatabaseService>(create: (_) => initializedDbService!),
        Provider<SalesManager>(create: (_) => initializedSalesManager!), // <-- Provide SalesManager
      ],
      child: const MyApp(),
    ),
  );
}

// --- Your Main Application Widget ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop Inventory App',
      theme: ThemeData(
         primarySwatch: Colors.blueGrey, // Changed theme slightly
         visualDensity: VisualDensity.adaptivePlatformDensity,
         useMaterial3: true, // Opt-in to Material 3
      ),
      // Update home to point to the renamed/new screen
      home: const InventoryScreen(), // <-- Changed from PlaceholderHomeScreen
    );
  }
}


// --- Error Widget (Keep as is) ---
class ErrorAppWidget extends StatelessWidget {
   final String message;
   const ErrorAppWidget(this.message, {super.key});
    @override
   Widget build(BuildContext context) {
     // ... (keep implementation the same) ...
     return MaterialApp(
       home: Scaffold(
         body: Center(
           child: Padding(
             padding: const EdgeInsets.all(20.0),
             child: Text(message, style: TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center,),
           ),
         ),
       ),
     );
   }
}

// --- PlaceholderHomeScreen REMOVED ---
// We will create InventoryScreen and AddEditProductScreen in separate files.