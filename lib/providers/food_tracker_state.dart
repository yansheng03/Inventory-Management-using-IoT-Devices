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

  // --- NEW: Preference Flag ---
  bool _autoAcceptChanges = false;

  StreamSubscription? _inventorySubscription;

  final _batchEventController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get batchEventStream =>
      _batchEventController.stream;

  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;

  // --- NEW: Getter ---
  bool get autoAcceptChanges => _autoAcceptChanges;

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

  // --- NEW: Setter to toggle the setting ---
  void toggleAutoAccept(bool value) {
    _autoAcceptChanges = value;
    notifyListeners();
  }

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
              // --- UPDATED: Check preference before running logic ---
              if (_allItems.isNotEmpty && !_autoAcceptChanges) {
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
    // If auto-accept is ON, we simply stop here.
    if (_autoAcceptChanges) return;

    List<Map<String, dynamic>> changes = [];

    final oldMap = {for (var i in oldItems) i.id: i};
    final newMap = {for (var i in newItems) i.id: i};

    for (var newItem in newItems) {
      if (!oldMap.containsKey(newItem.id)) {
        changes.add({
          'id': newItem.id,
          'name': newItem.name,
          'category': newItem.category,
          'quantity': newItem.quantity,
          'action': 'added',
        });
      } else {
        final oldItem = oldMap[newItem.id]!;
        if (newItem.quantity > oldItem.quantity) {
          changes.add({
            'id': newItem.id,
            'name': newItem.name,
            'category': newItem.category,
            'quantity': newItem.quantity,
            'action': 'added',
          });
        } else if (newItem.quantity < oldItem.quantity) {
          changes.add({
            'id': newItem.id,
            'name': newItem.name,
            'category': newItem.category,
            'quantity': newItem.quantity,
            'action': 'removed',
          });
        }
      }
    }

    for (var oldItem in oldItems) {
      if (!newMap.containsKey(oldItem.id)) {
        changes.add({
          'id': oldItem.id,
          'name': oldItem.name,
          'category': oldItem.category,
          'quantity': 0,
          'action': 'removed',
        });
      }
    }

    if (changes.length >= 3) {
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
    await _service.addFoodItem(item, _deviceId);
  }

  Future<void> updateItem(FoodItem item) async {
    await _service.updateFoodItem(item);
  }

  Future<void> deleteItem(String id) async {
    await _service.deleteFoodItem(id);
  }
}
