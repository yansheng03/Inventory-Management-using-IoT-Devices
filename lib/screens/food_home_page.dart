import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/food_tracker_state.dart';
import '../widgets/add_food_dialog.dart';
import '../widgets/category_chip.dart';
import 'device_page.dart';   // <-- Import DevicePage
import 'profile_page.dart';  // <-- Import ProfilePage

class FoodHomePage extends StatefulWidget {
  const FoodHomePage({super.key});

  @override
  State<FoodHomePage> createState() => _FoodHomePageState();
}

class _FoodHomePageState extends State<FoodHomePage> {
  int _selectedIndex = 1;
  final ScrollController _scrollController = ScrollController();
  
  // A map to hold a key for each category chip for scrolling
  late Map<String, GlobalKey> _categoryKeys;

  // List of categories to generate keys for
  final List<String> _categories = [
    'all', 'vegetables', 'meat', 'fruit', 'dairy', 
    'drinks', 'packaged', 'condiments', 'others'
  ];

  @override
  void initState() {
    super.initState();
    _categoryKeys = { for (var category in _categories) category: GlobalKey() };
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onCategoryTap(String category) {
    // Set the category in the state
    context.read<FoodTrackerState>().setCategory(category);
    
    // Scroll the selected chip into view
    final key = _categoryKeys[category];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // Center the chip
      );
    }
  }

  void _onNavTap(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<FoodTrackerState>();

    // This list holds the three main pages of the app
    final List<Widget> pages = [
      const DevicePage(),   // <-- Use the new DevicePage
      _buildHomePageContent(appState), // Home page content is built in a helper
      const ProfilePage(),  // <-- Use the new ProfilePage
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Items',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26)),
        elevation: 0,
        centerTitle: true,
      ),
      body: pages[_selectedIndex], // Display the selected page
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () =>
                  showDialog(context: context, builder: (_) => const AddFoodDialog()),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.devices_other_outlined),
              selectedIcon: Icon(Icons.devices_other),
              label: 'Device'),
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
      ),
    );
  }

  // Helper method to build the home page content
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
        // --- Category Chips with Scrolling ---
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
                // We wrap the chip in a custom GestureDetector
                child: GestureDetector(
                  onTap: () => _onCategoryTap(category),
                  child: CategoryChip(
                    key: _categoryKeys[category], // Assign the key
                    label: category,
                    selected: appState.selectedCategory == category,
                  ),
                ),
              );
            },
          ),
        ),
        // --- Item List ---
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
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = appState.filteredItems[index];
                          final dateString =
                              item.lastDetected.toLocal().toString().split(' ')[0];
                          
                          return ListTile(
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
