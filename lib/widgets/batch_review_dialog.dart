// lib/widgets/batch_review_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_app/models/food_item.dart';
import 'package:capstone_app/services/firebase_service.dart';
import 'package:capstone_app/widgets/food_item_dialog.dart';

class BatchReviewDialog extends StatefulWidget {
  final List<dynamic> changes;

  const BatchReviewDialog({super.key, required this.changes});

  @override
  State<BatchReviewDialog> createState() => _BatchReviewDialogState();
}

class _BatchReviewDialogState extends State<BatchReviewDialog> {
  late List<dynamic> _localChanges;

  @override
  void initState() {
    super.initState();
    _localChanges = List.from(widget.changes);
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(
      context,
      listen: false,
    );

    return AlertDialog(
      title: const Text("Batch Update Detected"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("The following items were recently changed:"),
            const SizedBox(height: 10),
            Flexible(
              child: _localChanges.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "All items handled.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _localChanges.length,
                      itemBuilder: (context, index) {
                        final change = _localChanges[index];
                        final name = change['name'] ?? 'Unknown';
                        final action = change['action'] ?? 'unknown';
                        final category = change['category'] ?? 'others';
                        final quantity = change['quantity'] ?? 0;
                        final id = change['id'];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      action == 'added'
                                          ? Icons.add_circle
                                          : Icons.remove_circle,
                                      color: action == 'added'
                                          ? Colors.green
                                          : Colors.red,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name.toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "$action - $category",
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Quantity: $quantity",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: Colors.blue,
                                      ),
                                      label: const Text(
                                        "Edit",
                                        style: TextStyle(color: Colors.blue),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () async {
                                        final item = FoodItem(
                                          id: id,
                                          name: name,
                                          category: category,
                                          quantity: quantity,
                                          lastDetected: DateTime.now(),
                                        );

                                        // --- FIX 1: Wait for result and update ---
                                        final result = await showDialog(
                                          context: context,
                                          builder: (_) => FoodItemDialog(
                                            existingItem: item,
                                          ),
                                        );

                                        if (result != null &&
                                            result is FoodItem) {
                                          setState(() {
                                            _localChanges[index]['name'] =
                                                result.name;
                                            _localChanges[index]['category'] =
                                                result.category;
                                            _localChanges[index]['quantity'] =
                                                result.quantity;
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
                                        "Delete",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        firebaseService.deleteFoodItem(id);
                                        setState(() {
                                          _localChanges.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        // --- FIX 2: Handle Adding Items ---
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text("Add New Item"),
          onPressed: () async {
            final result = await showDialog(
              context: context,
              builder: (_) => const FoodItemDialog(),
            );

            if (result != null && result is FoodItem) {
              setState(() {
                // Add the new item to the local list so it appears instantly
                _localChanges.add({
                  'id': result.id.isEmpty ? 'temp_id' : result.id,
                  'name': result.name,
                  'category': result.category,
                  'quantity': result.quantity,
                  'action': 'added', // Mark as added
                });
              });
            }
          },
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("OK, All Good"),
        ),
      ],
    );
  }
}
