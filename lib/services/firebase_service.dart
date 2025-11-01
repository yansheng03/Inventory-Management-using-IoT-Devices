// lib/services/firebase_service.dart

import 'dart:async';
import 'package:capstone_app/models/food_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Auth ---

  /// Get the current logged-in user.
  User? get currentUser => _auth.currentUser;

  /// Get a stream of authentication state changes (login/logout).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get the current user's unique ID.
  String? get currentUserId => _auth.currentUser?.uid;

  /// Login with email and password.
  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Handle errors (e.g., user-not-found, wrong-password)
      print("Login error: ${e.message}");
      rethrow;
    }
  }

  /// Sign up a new user.
  Future<UserCredential> signUp(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Add user's name
      await userCredential.user?.updateDisplayName(name);

      // We can also create a 'users' document to store extra info
      if (userCredential.user != null) {
        await _db.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'email': email,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle errors (e.g., email-already-in-use)
      print("Sign up error: ${e.message}");
      rethrow;
    }
  }

  /// Log out the current user.
  Future<void> logout() async {
    await _auth.signOut();
  }

  // --- Device Management ---
  
  /// Gets the first device ID linked to the current user.
  Future<String?> getUserDevice() async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      // Query the 'devices' collection
      final query = await _db
          .collection('devices')
          .where('owner_id', isEqualTo: userId)
          .limit(1)
          .get();
          
      if (query.docs.isNotEmpty) {
        return query.docs.first.id; // This is the device's Record ID
      }
      print("No device found for this user.");
      return null;
    } catch (e) {
      print("Error getting user device: $e");
      return null;
    }
  }

  // --- Inventory Management ---

  /// Get a REAL-TIME stream of inventory items for a specific device.
  Stream<List<FoodItem>> getInventoryStream(String deviceId) {
    if (deviceId.isEmpty) {
      return Stream.value([]); // Return empty list if no device
    }

    return _db
        .collection('inventory')
        .where('source_device_id', isEqualTo: deviceId)
        .orderBy('lastDetected', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FoodItem.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  // --- NEW: updateFoodItem METHOD ---
  /// Updates an existing food item in Firestore.
  Future<void> updateFoodItem(FoodItem item) async {
    if (item.id.isEmpty) {
      print("Error: Cannot update item without an ID.");
      return;
    }
    await _db
        .collection('inventory')
        .doc(item.id)
        .update(item.toFirestoreUpdate()); // Use the new update map
  }

  // --- HEAVILY MODIFIED: addFoodItem (now an "Upsert") ---
  /// Adds a new food item or updates the quantity of an existing one.
  Future<void> addFoodItem(FoodItem item, String deviceId) async {
    final userId = currentUserId;
    if (userId == null || deviceId.isEmpty) {
      print("Cannot add item: User not logged in or no device ID.");
      return;
    }

    // Normalized name for searching
    final normalizedName = item.name.toLowerCase();

    // 1. Query for an existing item
    final query = _db
        .collection('inventory')
        .where('source_device_id', isEqualTo: deviceId)
        .where('name_normalized', isEqualTo: normalizedName)
        .where('category', isEqualTo: item.category)
        .limit(1);

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      // --- 2a. No item found: Create a new one ---
      print("No existing item found. Creating new one.");
      await _db.collection('inventory').add(
        item.toFirestore(userId, deviceId)
      );
    } else {
      // --- 2b. Item found: Update the existing one ---
      print("Existing item found. Updating quantity.");
      final existingDoc = snapshot.docs.first;
      final existingQuantity = (existingDoc.data()['quantity'] ?? 0) as int;
      final newQuantity = existingQuantity + item.quantity;
      
      await _db.collection('inventory').doc(existingDoc.id).update({
        'quantity': newQuantity,
        'lastDetected': Timestamp.fromDate(item.lastDetected),
      });
    }
  }

  /// Delete a food item from the inventory.
  Future<void> deleteFoodItem(String itemId) async {
    await _db.collection('inventory').doc(itemId).delete();
  }

  /// Creates a new device document in Firestore for the current user.
  /// Returns the unique ID of the newly created device document.
  Future<String?> registerNewDevice({String deviceName = "My Fridge"}) async {
    final userId = currentUserId;
    if (userId == null) {
      print("Error: Cannot register device, user not logged in.");
      return null; 
    }

    try {
      final docRef = await _db.collection('devices').add({
        'owner_id': userId,
        'name': deviceName,
        'registered_at': FieldValue.serverTimestamp(),
        // You could add other initial fields here if needed
      });
      print("Device registered successfully with ID: ${docRef.id}");
      return docRef.id; // Return the auto-generated ID
    } catch (e) {
      print("Error registering device in Firestore: $e");
      return null;
    }
  }
}