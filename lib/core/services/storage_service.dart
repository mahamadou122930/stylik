import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_tables.dart';

/// Upload de fichiers vers Supabase Storage (logos, photos avant/après).
class StorageService {
  const StorageService(this._client);

  final SupabaseClient _client;

  /// Téléverse [file] dans [bucket] et retourne son URL publique.
  ///
  /// [path] doit être unique et préfixé par le salon, ex :
  /// `"<salonId>/<clientId>/before_1712345678.jpg"`.
  Future<String> upload({
    required String bucket,
    required String path,
    required File file,
    bool upsert = true,
  }) async {
    await _client.storage.from(bucket).upload(
          path,
          file,
          fileOptions: FileOptions(upsert: upsert),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Photo avant/après d'un client.
  Future<String> uploadClientPhoto({
    required String salonId,
    required String clientId,
    required File file,
    required bool isBefore,
  }) {
    final label = isBefore ? 'before' : 'after';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return upload(
      bucket: SupabaseBuckets.clientPhotos,
      path: '$salonId/$clientId/${label}_$stamp.jpg',
      file: file,
    );
  }

  /// Logo du salon.
  Future<String> uploadSalonLogo({
    required String salonId,
    required File file,
  }) {
    return upload(
      bucket: SupabaseBuckets.salonLogos,
      path: '$salonId/logo.jpg',
      file: file,
    );
  }

  Future<void> remove({required String bucket, required String path}) =>
      _client.storage.from(bucket).remove([path]);
}
