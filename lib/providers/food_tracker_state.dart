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

  // Stream controller to broadcast batch events to the UI
  final _batchEventController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get batchEventStream =>
      _batchEventController.stream;

  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  List<FoodItem> get filteredItems {
    return _allItems.where((item) {
      final matchesCategory =
          _selectedCategory == 'all' || item.category == _selectedCategory;
      final matchesSearch = item.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
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
          .listen(
            (items) {
              // --- Batch Detection Logic ---
              if (_allItems.isNotEmpty) {
                _checkForBatchChanges(_allItems, items);
              }

              _allItems = items;
              _isLoading = false;
              notifyListeners();
            },
            onError: (e) {
              print("Error in inventory stream: $e");
              _isLoading = false;
              notifyListeners();
            },
          );
    } else {
      print("No device ID found during initialization.");
      _isLoading = false;
      notifyListeners();
    }
  }

  void _checkForBatchChanges(List<FoodItem> oldItems, List<FoodItem> newItems) {
    List<Map<String, dynamic>> changes = [];

    final oldMap = {for (var i in oldItems) i.id: i};
    final newMap = {for (var i in newItems) i.id: i};

    // 1. Check for Additions (New IDs) and Updates (Quantity Changes)
    for (var newItem in newItems) {
      if (!oldMap.containsKey(newItem.id)) {
        // Brand new item
        changes.add({
          'id': newItem.id,
          'name': newItem.name,
          'category': newItem.category,
          'quantity': newItem.quantity, // CHANGED: Added quantity
          'action': 'added',
        });
      } else {
        // Existing item, check quantity
        final oldItem = oldMap[newItem.id]!;
        if (newItem.quantity > oldItem.quantity) {
          changes.add({
            'id': newItem.id,
            'name': newItem.name,
            'category': newItem.category,
            'quantity': newItem.quantity, // CHANGED: Added quantity
            'action': 'added',
          });
        } else if (newItem.quantity < oldItem.quantity) {
          changes.add({
            'id': newItem.id,
            'name': newItem.name,
            'category': newItem.category,
            'quantity': newItem.quantity, // CHANGED: Added quantity
            'action': 'removed',
          });
        }
      }
    }

    // 2. Check for Removals (IDs that disappeared)
    for (var oldItem in oldItems) {
      if (!newMap.containsKey(oldItem.id)) {
        changes.add({
          'id': oldItem.id,
          'name': oldItem.name,
          'category': oldItem.category,
          'quantity': 0, // CHANGED: Item gone, qty is 0
          'action': 'removed',
        });
      }
    }

    // Threshold: Only trigger popup if > 3 items changed at once
    if (changes.length > 3) {
      _batchEventController.add(changes);
    }
  }

  @override
  void dispose() {
    _inventorySubscription?.cancel();
    _batchEventController.close();
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
    if (_deviceId.isEmpty) {
      throw Exception(
        "No device linked. Please go to the Device tab to connect your fridge monitor first.",
      );
    }
    try {
      await _service.addFoodItem(item, _deviceId);
    } catch (e) {
      print("Failed to add item: $e");
      rethrow;
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
