import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Utility class to delete all local and cloud data
class DataDeletionService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DataDeletionService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  /// Delete local SQLite database
  Future<void> deleteLocalDatabase() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'hangout_spot.sqlite'));

      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ Local database deleted: ${file.path}');
      } else {
        debugPrint('ℹ️ Local database file not found');
      }

      // Also delete any WAL or SHM files
      final walFile = File(p.join(dbFolder.path, 'hangout_spot.sqlite-wal'));
      final shmFile = File(p.join(dbFolder.path, 'hangout_spot.sqlite-shm'));

      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();
    } catch (e) {
      debugPrint('❌ Error deleting local database: $e');
      rethrow;
    }
  }

  /// Delete all cloud data from Firestore
  Future<void> deleteCloudData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('ℹ️ No user logged in, skipping cloud data deletion');
        return;
      }

      final baseRef = _firestore.collection('cafes').doc(user.uid);

      // Delete menu data
      await _deleteCollection(baseRef.collection('menu'));

      // Delete other data
      await _deleteCollection(baseRef.collection('data'));

      // Delete the base document
      await baseRef.delete();

      debugPrint('✅ Cloud data deleted for user: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error deleting cloud data: $e');
      rethrow;
    }
  }

  /// Helper to delete a Firestore collection
  Future<void> _deleteCollection(CollectionReference collection) async {
    try {
      final snapshot = await collection.get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error deleting collection: $e');
    }
  }

  /// Delete both local and cloud data
  Future<void> deleteAllData() async {
    await deleteLocalDatabase();
    await deleteCloudData();
    debugPrint('✅ All data deleted (local + cloud)');
  }

  /// Show confirmation dialog and delete all data
  static Future<void> showDeleteDataDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete All Data?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• All local database data'),
            Text('• All cloud/Firebase data'),
            Text('• Orders, customers, menu items'),
            Text('• Settings and configurations'),
            SizedBox(height: 16),
            Text(
              '⚠️ This action CANNOT be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('The app will need to be restarted after deletion.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE ALL DATA'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting all data...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        final service = DataDeletionService();
        await service.deleteAllData();

        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog

          // Show success message
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text('Data Deleted'),
                ],
              ),
              content: const Text(
                'All data has been successfully deleted.\n\n'
                'Please restart the app to continue.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Force exit the app
                    exit(0);
                  },
                  child: const Text('Exit App'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
