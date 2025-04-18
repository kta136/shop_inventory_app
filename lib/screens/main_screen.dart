// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- Import for LogicalKeySet etc.

// Import the screen widgets
import 'inventory_screen.dart';
import 'sales_entry_screen.dart';
import 'sales_history_screen.dart';

// --- Define Intent for Tab Navigation ---
class GoToTabIntent extends Intent {
  final int tabIndex;
  const GoToTabIntent(this.tabIndex);
}
// --- End Intent Definition ---

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const InventoryScreen(),
    const SalesEntryScreen(),
    const SalesHistoryScreen(),
  ];

  void _onItemTapped(int index) {
    // Ensure index is within bounds before updating
    if (index >= 0 && index < _widgetOptions.length) {
        setState(() {
           _selectedIndex = index;
        });
    }
  }

  // --- Define Actions Map ---
  // Map Intent Types to Action Instances
  late final Map<Type, Action<Intent>> _tabActions = <Type, Action<Intent>>{
    // Map GoToTabIntent to a CallbackAction that calls our _onItemTapped method
    GoToTabIntent: CallbackAction<GoToTabIntent>(
      onInvoke: (GoToTabIntent intent) => _onItemTapped(intent.tabIndex),
    ),
  };
  // --- End Actions Map Definition ---

  // --- Define Shortcuts Map ---
  // Map Key Combinations (LogicalKeySet) to Intents
  final Map<LogicalKeySet, Intent> _tabShortcuts = <LogicalKeySet, Intent>{
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1): const GoToTabIntent(0), // Ctrl+1 -> Inventory
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.numpad1): const GoToTabIntent(0), // Ctrl+Numpad1
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2): const GoToTabIntent(1), // Ctrl+2 -> Record Sale
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.numpad2): const GoToTabIntent(1), // Ctrl+Numpad2
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit3): const GoToTabIntent(2), // Ctrl+3 -> History
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.numpad3): const GoToTabIntent(2), // Ctrl+Numpad3
  };
 // --- End Shortcuts Map Definition ---


  @override
  Widget build(BuildContext context) {
    // Wrap the entire Scaffold with Actions and Shortcuts
    // This makes the shortcuts globally available while this screen is active
    return Actions( // Handles mapping Intents to Actions
      actions: _tabActions,
      child: Shortcuts( // Handles mapping Key combinations to Intents
        shortcuts: _tabShortcuts,
        child: Scaffold( // Your original Scaffold
          body: IndexedStack( // Keep IndexedStack
            index: _selectedIndex,
            children: _widgetOptions,
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Inventory (Ctrl+1)', // Add hint to label
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.point_of_sale_outlined),
                activeIcon: Icon(Icons.point_of_sale),
                label: 'Record Sale (Ctrl+2)', // Add hint to label
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_outlined),
                activeIcon: Icon(Icons.history),
                label: 'History (Ctrl+3)', // Add hint to label
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
          ),
        ),
      ),
    );
  }
}