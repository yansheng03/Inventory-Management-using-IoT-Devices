// lib/providers/food_tracker_state.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:capstone_app/models/food_item.dart';
import 'package:capstone_app/services/firebase_service.dart';

class FoodTrackerState extends ChangeNotifier {
  final FirebaseService _service;

  List<FoodItem> _allItems = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  String _deviceId = '';

  StreamSubscription? _inventorySubscription;

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

  FoodTrackerState(this._service);

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    _deviceId = await _service.getUserDevice() ?? '';
    _allItems = [];
    await _inventorySubscription?.cancel();
    
    if (_deviceId.isNotEmpty) {
      _inventorySubscription = _service
          .getInventoryStream(_deviceId)
          .listen((items) {
        _allItems = items;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        print("Error in inventory stream: $e");
        _isLoading = false;
        notifyListeners();
      });
    } else {
      print("No device ID found during initialization.");
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    super.dispose();
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
    // --- IMPROVED: Explicitly check for device connection ---
    if (_deviceId.isEmpty) {
      throw Exception("No device linked. Please go to the Device tab to connect your fridge monitor first.");
    }
    try {
      await _service.addFoodItem(item, _deviceId);
    } catch (e) {
      print("Failed to add item: $e");
      rethrow; // Pass error to UI
    }
  }

  Future<void> updateItem(FoodItem item) async {
    try {
      await _service.updateFoodItem(item);
    } catch (e) {
      print("Failed to update item: $e");
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _service.deleteFoodItem(id); 
    } catch (e) {
      print("Failed to delete item: $e");
      rethrow;
    }
  }
}