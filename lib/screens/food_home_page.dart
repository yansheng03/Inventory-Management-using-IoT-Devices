// lib/screens/food_home_page.dart

import 'package:capstone_app/models/food_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/food_tracker_state.dart';
import '../widgets/food_item_dialog.dart';
import '../widgets/category_chip.dart';
import 'package:capstone_app/screens/profile_page.dart';
import 'package:capstone_app/screens/device_page.dart';
import 'package:capstone_app/services/firebase_service.dart';
import 'package:capstone_app/widgets/batch_review_dialog.dart';
import 'dart:async';

class FoodHomePage extends StatefulWidget {
  const FoodHomePage({super.key});

  @override
  State<FoodHomePage> createState() => _FoodHomePageState();
}

class _FoodHomePageState extends State<FoodHomePage> {
  int _selectedIndex = 1;
  StreamSubscription? _alertSubscription;
  final ScrollController _scrollController = ScrollController();

  late Map<String, GlobalKey> _categoryKeys;

  final List<String> _categories = ['all', ...FoodItem.validCategories];

  final List<String> _pageTitles = [
    'Device Connection',
    'Your Items',
    'My Profile',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FoodTrackerState>().initialize();
      _setupAlertListener();
    });
    _categoryKeys = {for (var category in _categories) category: GlobalKey()};
  }

  void _setupAlertListener() {
    final firebaseService = context.read<FirebaseService>();
    _alertSubscription = firebaseService.getBatchAlertsStream().listen((
      alerts,
    ) {
      if (alerts.isNotEmpty && mounted) {
        // Just take the first one to show
        final alert = alerts.first;

        // Prevent stacking dialogs if one is already open?
        // Simple way: just show it.
        showDialog(
          context: context,
          barrierDismissible: false, // Force them to press OK
          builder: (ctx) => BatchReviewDialog(
            alertId: alert['id'],
            changes: alert['changes'] ?? [],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _alertSubscription?.cancel(); // <--- Clean up
    _scrollController.dispose();
    super.dispose();
  }

  void _onCategoryTap(String category) {
    context.read<FoodTrackerState>().setCategory(category);

    final key = _categoryKeys[category];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  void _onNavTap(int index) => setState(() => _selectedIndex = index);

  void _showFoodItemDialog({FoodItem? item}) {
    showDialog(
      context: context,
      builder: (_) => FoodItemDialog(existingItem: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<FoodTrackerState>();

    final List<Widget> pages = [
      const DevicePage(),
      _buildHomePageContent(appState),
      const ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pageTitles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () => _showFoodItemDialog(),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.devices_other_outlined),
            selectedIcon: Icon(Icons.devices_other),
            label: 'Device',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
      ),
    );
  }

  Widget _buildHomePageContent(FoodTrackerState appState) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            onChanged: appState.updateSearch,
            decoration: InputDecoration(
              hintText: 'Search food...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () => _onCategoryTap(category),
                  child: CategoryChip(
                    key: _categoryKeys[category],
                    label: category,
                    selected: appState.selectedCategory == category,
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: appState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : appState.filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.kitchen_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text("No items found."),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text("Refresh"),
                        onPressed: context.read<FoodTrackerState>().initialize,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: context.read<FoodTrackerState>().initialize,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: appState.filteredItems.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = appState.filteredItems[index];
                      final dateString = item.lastDetected
                          .toLocal()
                          .toString()
                          .split(' ')[0];

                      return ListTile(
                        leading: Text(
                          item.icon,
                          style: const TextStyle(fontSize: 28),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text("Last seen: $dateString"),
                        onTap: () => _showFoodItemDialog(item: item),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.quantity.toString(),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                _showDeleteDialog(context, item.id, item.name);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              context.read<FoodTrackerState>().deleteItem(id);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
