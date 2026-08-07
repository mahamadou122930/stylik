import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Structure d'une mutation en attente de synchronisation.
class SyncItem {
  const SyncItem({
    required this.id,
    required this.action,
    required this.tableName,
    required this.recordId,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  final int id;

  /// 'INSERT', 'UPDATE', 'DELETE'
  final String action;
  final String tableName;
  final String recordId;
  final Map<String, dynamic> payload;
  final String createdAt;
  final int retryCount;

  factory SyncItem.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> payloadMap = {};
    try {
      payloadMap = jsonDecode(map['payload'] as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Erreur de décodage JSON dans SyncItem ${map['id']}: $e');
    }

    return SyncItem(
      id: map['id'] as int,
      action: map['action'] as String,
      tableName: map['table_name'] as String,
      recordId: map['record_id'] as String,
      payload: payloadMap,
      createdAt: map['created_at'] as String,
      retryCount: (map['retry_count'] as int?) ?? 0,
    );
  }
}

/// Service sécurisé de gestion de la base SQLite locale pour le mode Offline-First.
class LocalDbService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'stylik_offline.db');

      return await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE cached_records (
              table_name TEXT NOT NULL,
              id TEXT NOT NULL,
              salon_id TEXT NOT NULL,
              data TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (table_name, id)
            )
          ''');

          await db.execute('''
            CREATE TABLE sync_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              action TEXT NOT NULL,
              table_name TEXT NOT NULL,
              record_id TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL,
              retry_count INTEGER DEFAULT 0
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            try {
              await db.execute('ALTER TABLE sync_queue ADD COLUMN retry_count INTEGER DEFAULT 0');
            } catch (_) {}
          }
        },
      );
    } catch (e) {
      debugPrint('Erreur d\'ouverture de la base SQLite locale: $e');
      rethrow;
    }
  }

  // --- Gestion du Cache Local ---

  Future<void> cacheRecords({
    required String tableName,
    required String salonId,
    required List<Map<String, dynamic>> records,
  }) async {
    try {
      final db = await database;
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();

      for (final record in records) {
        final id = record['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        batch.insert(
          'cached_records',
          {
            'table_name': tableName,
            'id': id,
            'salon_id': salonId,
            'data': jsonEncode(record),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('Erreur lors de la mise en cache des enregistrements ($tableName): $e');
    }
  }

  Future<void> cacheRecord({
    required String tableName,
    required String salonId,
    required Map<String, dynamic> record,
  }) async {
    await cacheRecords(
      tableName: tableName,
      salonId: salonId,
      records: [record],
    );
  }

  Future<void> deleteCachedRecord({
    required String tableName,
    required String recordId,
  }) async {
    try {
      final db = await database;
      await db.delete(
        'cached_records',
        where: 'table_name = ? AND id = ?',
        whereArgs: [tableName, recordId],
      );
    } catch (e) {
      debugPrint('Erreur de suppression du cache local ($tableName, $recordId): $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedRecords({
    required String tableName,
    required String salonId,
  }) async {
    try {
      final db = await database;
      final rows = await db.query(
        'cached_records',
        where: 'table_name = ? AND salon_id = ?',
        whereArgs: [tableName, salonId],
      );

      final list = <Map<String, dynamic>>[];
      for (final row in rows) {
        try {
          final jsonStr = row['data'] as String;
          list.add(jsonDecode(jsonStr) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('Donnée de cache corrompue ignorée: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Erreur de lecture du cache local ($tableName): $e');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> getCachedRecordById({
    required String tableName,
    required String recordId,
  }) async {
    try {
      final db = await database;
      final rows = await db.query(
        'cached_records',
        where: 'table_name = ? AND id = ?',
        whereArgs: [tableName, recordId],
        limit: 1,
      );

      if (rows.isEmpty) return null;
      return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Erreur de lecture de l\'élément $recordId dans le cache local: $e');
      return null;
    }
  }

  // --- Gestion de la File de Synchronisation (Sync Queue) ---

  Future<void> enqueueMutation({
    required String action,
    required String tableName,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final db = await database;
      await db.insert('sync_queue', {
        'action': action,
        'table_name': tableName,
        'record_id': recordId,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });
    } catch (e) {
      debugPrint('Erreur d\'ajout dans la file d\'attente de synchro: $e');
    }
  }

  Future<List<SyncItem>> getPendingSyncItems() async {
    try {
      final db = await database;
      final rows = await db.query('sync_queue', orderBy: 'id ASC');
      final list = <SyncItem>[];
      for (final r in rows) {
        try {
          list.add(SyncItem.fromMap(r));
        } catch (e) {
          debugPrint('SyncItem invalide ignoré: $e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('Erreur de lecture de la file de synchro: $e');
      return const [];
    }
  }

  Future<int> getPendingCount() async {
    try {
      final db = await database;
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM sync_queue'),
      );
      return count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> incrementRetry(int syncId) async {
    try {
      final db = await database;
      await db.rawUpdate(
        'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
        [syncId],
      );
    } catch (e) {
      debugPrint('Erreur d\'incrémentation du nombre de retries pour $syncId: $e');
    }
  }

  Future<void> removeSyncItem(int syncId) async {
    try {
      final db = await database;
      await db.delete('sync_queue', where: 'id = ?', whereArgs: [syncId]);
    } catch (e) {
      debugPrint('Erreur de suppression de l\'élément de synchro $syncId: $e');
    }
  }
}

/// Provider du service de base de données locale.
final localDbServiceProvider = Provider<LocalDbService>((ref) {
  return LocalDbService();
});
