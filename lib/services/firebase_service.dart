// lib/services/firebase_service.dart

import 'dart:async';
import 'package:capstone_app/models/food_item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Auth ---
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      print("Login error: ${e.message}");
      rethrow;
    }
  }

  Future<UserCredential> signUp(String email, String password, String name) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user?.updateDisplayName(name);
      if (userCredential.user != null) {
        await _db.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'email': email,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Sign up error: ${e.message}");
      rethrow;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  // --- Profile Management ---

  Future<void> updateDisplayName(String newName) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(newName);
      await _db.collection('users').doc(user.uid).update({'name': newName});
      await user.reload(); 
    }
  }

  Future<void> updatePassword(String newPassword) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    }
  }

  // --- Device Management ---

  Future<String?> getUserDevice() async {
    final userId = currentUserId;
    if (userId == null) return null;
    try {
      final query = await _db
          .collection('devices')
          .where('owner_id', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
      return null;
    } catch (e) {
      print("Error getting user device: $e");
      return null;
    }
  }

  Future<void> registerConfirmedDevice({required String deviceId, required String deviceName}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception("User not logged in");

    try {
      await _db.collection('devices').doc(deviceId).set({
        'owner_id': userId,
        'name': deviceName,
        'last_setup_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print("Device registered/updated successfully: $deviceId");
    } catch (e) {
      print("Error registering confirmed device: $e");
      rethrow;
    }
  }

  // --- Inventory Management ---

  Stream<List<FoodItem>> getInventoryStream(String deviceId) {
    final userId = currentUserId;
    if (deviceId.isEmpty || userId == null) return Stream.value([]);
    
    return _db
        .collection('inventory')
        .where('source_device_id', isEqualTo: deviceId)
        .where('owner_id', isEqualTo: userId) 
        .orderBy('lastDetected', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FoodItem.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  Future<void> updateFoodItem(FoodItem item) async {
    if (item.id.isEmpty) return;
    await _db.collection('inventory').doc(item.id).update(item.toFirestoreUpdate());
  }

  Future<void> addFoodItem(FoodItem item, String deviceId) async {
    final userId = currentUserId;
    if (userId == null || deviceId.isEmpty) return;

    final normalizedName = item.name.toLowerCase();
    
    final query = _db
        .collection('inventory')
        .where('source_device_id', isEqualTo: deviceId)
        .where('owner_id', isEqualTo: userId) 
        .where('name_normalized', isEqualTo: normalizedName)
        .where('category', isEqualTo: item.category)
        .limit(1);

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      // CREATE NEW ITEM
      await _db.collection('inventory').add({
        'name': item.name,
        'name_normalized': normalizedName,
        'quantity': item.quantity,
        'category': item.category,
        'lastDetected': Timestamp.fromDate(item.lastDetected),
        'source_device_id': deviceId,
        'owner_id': userId,
      });
    } else {
      // UPDATE EXISTING ITEM
      final existingDoc = snapshot.docs.first;
      final existingQuantity = (existingDoc.data()['quantity'] ?? 0) as int;
      final newQuantity = existingQuantity + item.quantity;
      
      await _db.collection('inventory').doc(existingDoc.id).update({
        'quantity': newQuantity,
        'lastDetected': Timestamp.fromDate(item.lastDetected),
      });
    }
  }

  Future<void> deleteFoodItem(String itemId) async {
    await _db.collection('inventory').doc(itemId).delete();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).delete();
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          throw Exception("For security, please log out and log in again before deleting your account.");
        }
        rethrow;
      }
    }
  }

}