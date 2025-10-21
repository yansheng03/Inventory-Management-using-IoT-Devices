// lib/services/pocketbase_service.dart
import 'dart:convert'; // Required for jsonEncode/jsonDecode
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_item.dart'; // Assuming this defines FoodItem correctly

class PocketBaseService {
  // Use your correct IPv4 address
  final String baseUrl = "http://192.168.100.9:8090";
  late final PocketBase _pb;

  // Keys for manual storage
  static const String _authKeyToken = 'pocketbase_auth_token';
  static const String _authKeyModel = 'pocketbase_auth_model';

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

  // Getter for the PocketBase client
  PocketBase get client => _pb;

  // --- Auth Methods ---

  // Get the currently logged in user's model
  RecordModel? get currentUser => _pb.authStore.record;

  // --- NEW: Get User's Device ID ---
  String? getCurrentUserDeviceID() {
    // Assumes the 'device' field in the users collection stores the related device ID
    return currentUser?.getStringValue('device');
  }
  // --- END NEW ---


  Future<bool> login(String email, String password) async {
    try {
      await _pb.collection('users').authWithPassword(email, password);
      await _saveAuthStoreManually();
      return _pb.authStore.isValid;
    } catch (e) {
      print('Login Error: $e');
      _pb.authStore.clear();
      await _clearAuthStoreManually();
      return false;
    }
  }

  Future<void> logout() async {
    _pb.authStore.clear();
    await _clearAuthStoreManually();
  }

  Future<bool> isLoggedIn() async {
    bool loaded = await _loadAuthStoreManually();
    if (!loaded || !_pb.authStore.isValid) {
      await logout();
      return false;
    }
    try {
      await _pb.collection('users').authRefresh().timeout(const Duration(seconds: 3));
      await _saveAuthStoreManually();
      return _pb.authStore.isValid;
    } catch (refreshError) {
      print('Auth refresh failed: $refreshError');
      await logout();
      return false;
    }
  }

  Future<void> _saveAuthStoreManually() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pb.authStore.isValid && _pb.authStore.token.isNotEmpty && _pb.authStore.record != null) {
      await prefs.setString(_authKeyToken, _pb.authStore.token);
      await prefs.setString(_authKeyModel, jsonEncode(_pb.authStore.record!.toJson()));
       print('AuthStore saved manually.');
    } else {
       print('AuthStore invalid state during save, clearing manual storage.');
      await _clearAuthStoreManually();
    }
  }

  Future<bool> _loadAuthStoreManually() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_authKeyToken);
    final modelString = prefs.getString(_authKeyModel);

    if (token != null && token.isNotEmpty && modelString != null && modelString.isNotEmpty) {
      try {
        final modelJson = jsonDecode(modelString) as Map<String, dynamic>;
        final model = RecordModel.fromJson(modelJson);
        _pb.authStore.save(token, model);
         print('AuthStore loaded manually.');
        return _pb.authStore.isValid && _pb.authStore.token == token;
      } catch (e) {
        print('Error decoding/loading manual AuthStore: $e');
        _pb.authStore.clear();
        await _clearAuthStoreManually();
        return false;
      }
    }
     print('No manual AuthStore data found.');
    return false;
  }

  Future<void> _clearAuthStoreManually() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKeyToken);
    await prefs.remove(_authKeyModel);
     print('Manual AuthStore cleared.');
  }

  // --- Inventory Collection Methods ---
  final String inventoryCollection = 'inventory';

  Future<List<FoodItem>> getInventoryItems() async {
    if (!_pb.authStore.isValid) {
      print("Attempted to fetch inventory while not logged in.");
      return [];
    }
    try {
      // --- UPDATED: Use PocketBase Expand syntax to fetch device owner info ---
      // This allows the API rule (@request.auth.id = source_device.owner.id) to work
      // by ensuring the owner ID is included when listing.
      final records = await _pb.collection(inventoryCollection).getFullList(
            sort: '-last_detected',
            // expand: 'source_device.owner', // Optional: if you need owner details in the app
          );

      // --- Filter client-side as a fallback/verification ---
      // (The API rule *should* handle this server-side)
      final currentUserDeviceId = getCurrentUserDeviceID();
      if (currentUserDeviceId == null) {
         print("User has no device linked, cannot fetch inventory.");
         return [];
      }

      return records
          .where((record) => record.getStringValue('source_device') == currentUserDeviceId) // Double check link
          .map((record) => FoodItem.fromJson(record.data, record.id))
          .toList();
    } catch (e) {
      print("Error fetching inventory: $e");
       if (e is ClientException && e.statusCode == 401) {
         print("Authentication error during fetch. Logging out.");
         await logout();
       } else if (e is ClientException && e.statusCode == 403) {
         print("Authorization error (403): Check PocketBase API rules for 'inventory'.");
       }
      return [];
    }
  }

  // Add Item - includes source_device if available in item.toJson()
  Future<void> addInventoryItem(FoodItem item) async {
    if (!_pb.authStore.isValid) return;
    try {
      // The item.toJson() now includes 'source_device'
      await _pb.collection(inventoryCollection).create(
            body: item.toJson(),
          );
    } catch (e) {
      print("Error adding item: $e");
       if (e is ClientException && e.statusCode == 400) {
          print("Bad Request (400): Check if 'source_device' field exists and is required in PocketBase 'inventory' collection. Body: ${item.toJson()}");
        }
      rethrow;
    }
  }

  // Update Item - includes source_device if available in item.toJson()
  Future<void> updateInventoryItem(FoodItem item) async {
    if (!_pb.authStore.isValid) return;
    try {
      // The item.toJson() now includes 'source_device'
      await _pb.collection(inventoryCollection).update(
            item.id,
            body: item.toJson(),
          );
    } catch (e) {
      print("Error updating item: $e");
      rethrow;
    }
  }

  // Delete Item - unchanged
  Future<void> deleteInventoryItem(String id) async {
    if (!_pb.authStore.isValid) return;
    try {
      await _pb.collection(inventoryCollection).delete(id);
    } catch (e) {
      print("Error deleting item: $e");
      rethrow;
    }
  }

  // --- Real-time Methods ---
  void subscribeToInventoryChanges(void Function() onInventoryChanged) {
     if (!_pb.authStore.isValid) return;
    try {
      // Consider filtering the subscription if PocketBase supports it for your rules
      // Example (syntax might vary): pb.collection(inventoryCollection).subscribe('*', (e) {...}, filter: 'source_device.owner.id = "${currentUser?.id}"');
      _pb.collection(inventoryCollection).subscribe('*', (e) {
        print('Real-time event: ${e.action}');
        onInventoryChanged();
      });
    } catch (e) {
      print("Error subscribing to changes: $e");
    }
  }

  void unsubscribe() {
    try {
      _pb.collection(inventoryCollection).unsubscribe();
    } catch (e) {
      // print("Error unsubscribing: $e");
    }
  }
}