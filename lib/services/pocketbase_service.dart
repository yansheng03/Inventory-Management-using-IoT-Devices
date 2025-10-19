// lib/services/pocketbase_service.dart
// COMPLETE REPLACEMENT - Delete old code
import 'package:pocketbase/pocketbase.dart';
import '../models/food_item.dart';

class PocketBaseService {
  // Use your correct IPv4 address
  final String baseUrl = "http://192.168.100.9:8090"; 
  late final PocketBase _pb;

  // Private constructor
  PocketBaseService._internal() {
    _pb = PocketBase(baseUrl);
  }

  // Singleton instance
  static final PocketBaseService _instance = PocketBaseService._internal();

  // Factory constructor to return the singleton instance
  factory PocketBaseService() {
    return _instance;
  }

  // Getter for the PocketBase client (optional, but good to have)
  PocketBase get client => _pb;

  // --- Inventory Collection Methods ---
  final String inventoryCollection = 'inventory';

  // Fetch all items from the inventory
  Future<List<FoodItem>> getInventoryItems() async {
    try {
      final records = await _pb.collection(inventoryCollection).getFullList(
            sort: '-last_detected', // Sort by most recently detected
          );

      // Convert each 'RecordModel' into our 'FoodItem' model
      return records
          .map((record) => FoodItem.fromJson(record.data, record.id))
          .toList();
    } catch (e) {
      print("Error fetching inventory: $e");
      // This error often means the phone is not on the same WiFi as the PC
      // or the PocketBase server is not running.
      return [];
    }
  }

  // Add a new food item (for manual adds from the app)
  Future<void> addInventoryItem(FoodItem item) async {
    try {
      await _pb.collection(inventoryCollection).create(
            body: item.toJson(), // Uses the toJson method from our model
          );
    } catch (e) {
      print("Error adding item: $e");
      rethrow; // Throw the error so the UI can know
    }
  }

  // Delete a food item (for manual deletes from the app)
  Future<void> deleteInventoryItem(String id) async {
    try {
      await _pb.collection(inventoryCollection).delete(id);
    } catch (e) {
      print("Error deleting item: $e");
      rethrow;
    }
  }

  // --- Real-time Methods ---

  // Subscribe to any changes in the inventory
  void subscribeToInventoryChanges(void Function() onInventoryChanged) {
    try {
      _pb.collection(inventoryCollection).subscribe('*', (e) {
        print('Real-time event: ${e.action}');
        // When any change happens, call the callback function.
        // This will trigger the state to refetch and notify listeners.
        onInventoryChanged();
      });
    } catch (e) {
      print("Error subscribing to changes: $e");
    }
  }

  // Unsubscribe when the app state is disposed
  void unsubscribe() {
    try {
      _pb.collection(inventoryCollection).unsubscribe();
    } catch (e) {
      print("Error unsubscribing: $e");
    }
  }
}