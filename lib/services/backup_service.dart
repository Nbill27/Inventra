import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';

/// Membuat salinan database ke folder backup.
///
/// Isinya seluruh data app (barang, peminjaman, riwayat) dalam satu berkas
/// `.db` yang bisa disalin kembali ke perangkat lain bila diperlukan. Salinan
/// dibuat lewat `VACUUM INTO`, bukan menyalin berkasnya langsung, supaya
/// isinya konsisten meski database sedang terbuka.
class BackupService {
  BackupService({DatabaseHelper? helper}) : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;

  /// Nama folder di dalam folder dokumen app.
  static const folderName = 'backup';

  /// Salinan otomatis yang disimpan; yang lebih lama dihapus.
  static const keepCount = 6;

  /// Membuat satu berkas backup dan mengembalikan jalurnya.
  Future<String> runBackup() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, folderName));
    await dir.create(recursive: true);

    final stamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
    final target = p.join(dir.path, 'backup-inventra-$stamp.db');

    final db = await _helper.database;
    await db.execute('VACUUM INTO ?', [target]);

    await _prune(dir);
    return target;
  }

  /// Folder tempat backup otomatis disimpan, untuk ditampilkan di layar.
  Future<String> backupFolderPath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, folderName);
  }

  /// Daftar berkas backup yang ada saat ini, terbaru lebih dulu.
  Future<List<File>> listBackups() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, folderName));
    if (!dir.existsSync()) {
      return const [];
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.db'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Menyisakan [keepCount] salinan terbaru.
  Future<void> _prune(Directory dir) async {
    final files = await listBackups();
    for (final file in files.skip(keepCount)) {
      try {
        await file.delete();
      } on FileSystemException {
        // Berkas yang sedang dipakai sistem dilewati; percobaan berikutnya
        // akan menghapusnya.
      }
    }
  }
}
