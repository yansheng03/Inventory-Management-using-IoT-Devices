// lib/providers/food_tracker_state.dart
import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../services/pocketbase_service.dart';

class FoodTrackerState extends ChangeNotifier {
  final PocketBaseService _service = PocketBaseService();

  // Internal state
  List<FoodItem> _allItems = [];
  bool _isLoading = false; // <-- Set to false
  String _selectedCategory = 'all';
  String _searchQuery = '';

  // Getters
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  List<FoodItem> get filteredItems {
    return _allItems.where((item) {
      final matchesCategory =
          _selectedCategory == 'all' || item.category == _selectedCategory;
      final matchesSearch =
          item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // Constructor
  FoodTrackerState() {
    // --- UPDATED ---
    // Only subscribe if the user is already logged in.
    // fetchInventory will be called by FoodHomePage when it loads.
    if (_service.client.authStore.isValid) {
      _service.subscribeToInventoryChanges(fetchInventory);
    }
  }

  @override
  void dispose() {
    _service.unsubscribe();
    super.dispose();
  }

  // --- Methods ---

  Future<void> fetchInventory() async {
    // Don't run if user is not logged in
    if (!_service.client.authStore.isValid) return; 

    _isLoading = true;
    notifyListeners();

    try {
      _allItems = await _service.getInventoryItems();
    } catch (e) {
      print("Error in fetchInventory (State): $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void updateSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addItem(FoodItem item) async {
    try {
      await _service.addInventoryItem(item);
      // Real-time subscription will handle the update
    } catch (e) {
      print("Failed to add item: $e");
    }
  }

  // --- NEW: Update Method ---
  Future<void> updateItem(FoodItem item) async {
    try {
      await _service.updateInventoryItem(item);
      // Real-time subscription will handle the update
    } catch (e) {
      print("Failed to update item: $e");
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _service.deleteInventoryItem(id);
      // Real-time subscription will handle the update
    } catch (e) {
      print("Failed to delete item: $e");
    }
  }
}