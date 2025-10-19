// lib/screens/food_home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/food_tracker_state.dart';
import '../widgets/add_food_dialog.dart';
import '../widgets/category_chip.dart';

class FoodHomePage extends StatefulWidget {
  const FoodHomePage({super.key});

  @override
  State<FoodHomePage> createState() => _FoodHomePageState();
}

class _FoodHomePageState extends State<FoodHomePage> {
  int _selectedIndex = 1;

  void _onNavTap(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<FoodTrackerState>();

    Widget currentScreen;
    if (_selectedIndex == 0) {
      currentScreen = const Center(
          child: Text('Device Page – Connect your IoT fridge here'));
    } else if (_selectedIndex == 2) {
      currentScreen =
          const Center(child: Text('Profile Page – User details and settings'));
    } else {
      currentScreen = Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: appState.updateSearch,
              // --- FIXED: Restored original decoration ---
              decoration: InputDecoration(
                hintText: 'Search food...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              // --- END OF FIX ---
            ),
          ),
          // Category Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  CategoryChip(
                      label: 'all',
                      selected: appState.selectedCategory == 'all'),
                  CategoryChip(
                      label: 'vegetables',
                      selected: appState.selectedCategory == 'vegetables'),
                  CategoryChip(
                      label: 'meat',
                      selected: appState.selectedCategory == 'meat'),
                  CategoryChip(
                      label: 'fruit',
                      selected: appState.selectedCategory == 'fruit'),
                  CategoryChip(
                      label: 'dairy',
                      selected: appState.selectedCategory == 'dairy'),
                  CategoryChip(
                      label: 'drinks',
                      selected: appState.selectedCategory == 'drinks'),
                  CategoryChip(
                      label: 'packaged',
                      selected: appState.selectedCategory == 'packaged'),
                  CategoryChip(
                      label: 'condiments',
                      selected: appState.selectedCategory == 'condiments'),
                  CategoryChip(
                      label: 'others',
                      selected: appState.selectedCategory == 'others'),
                ],
              ),
            ),
          ),
          // Item List
          Expanded(
            child: appState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : appState.filteredItems.isEmpty
                    ? const Center(child: Text("No items found."))
                    : RefreshIndicator(
                        onRefresh: appState.fetchInventory,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: appState.filteredItems.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = appState.filteredItems[index];
                            final dateString =
                                item.lastDetected.toLocal().toString().split(' ')[0];
                            
                            return ListTile(
                              // Display the computed icon
                              leading: Text(item.icon,
                                  style: const TextStyle(fontSize: 28)),
                              title: Text(item.name,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text("Last seen: $dateString"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.quantity.toString(),
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
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

    return Scaffold(
      appBar: AppBar(
        // --- FIXED: Restored original properties ---
        title: const Text('Your Food',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26)),
        backgroundColor: Colors.grey[50],
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        // --- END OF FIX ---
      ),
      body: currentScreen,
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () =>
                  showDialog(context: context, builder: (_) => const AddFoodDialog()),
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        // --- FIXED: Restored original properties ---
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.devices_other), label: 'Device'),
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        backgroundColor: Colors.white,
        indicatorColor: Colors.greenAccent.withOpacity(0.3),
        // --- END OF FIX ---
      ),
    );
  }

  // Helper function for delete confirmation
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