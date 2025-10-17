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
    var items = appState.filteredItems;

    Widget currentScreen;
    if (_selectedIndex == 0) {
      currentScreen = const Center(child: Text('Device Page – Connect your IoT fridge here'));
    } else if (_selectedIndex == 2) {
      currentScreen = const Center(child: Text('Profile Page – User details and settings'));
    } else {
      currentScreen = Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: appState.updateSearch,
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  CategoryChip(label: 'all', selected: appState.selectedCategory == 'all'),
                  CategoryChip(label: 'vegetables', selected: appState.selectedCategory == 'vegetables'),
                  CategoryChip(label: 'meat', selected: appState.selectedCategory == 'meat'),
                  CategoryChip(label: 'fruit', selected: appState.selectedCategory == 'fruit'),
                  CategoryChip(label: 'dairy', selected: appState.selectedCategory == 'dairy'),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: Text(item.icon, style: const TextStyle(fontSize: 28)),
                  title: Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  subtitle: Text(item.expiry),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.quantity, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(item.location, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Food', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26)),
        backgroundColor: Colors.grey[50],
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: currentScreen,
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () => showDialog(context: context, builder: (_) => const AddFoodDialog()),
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.devices_other), label: 'Device'),
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        backgroundColor: Colors.white,
        indicatorColor: Colors.greenAccent.withOpacity(0.3),
      ),
    );
  }
}
