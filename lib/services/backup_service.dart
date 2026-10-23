import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart'
    show Database, DatabaseException, OpenDatabaseOptions;

import '../core/exceptions.dart';
import '../db/database_helper.dart';

/// Membuat salinan database ke folder backup, mengeluarkannya ke lokasi pilihan
/// pengguna, dan memulihkan data dari berkas salinan.
///
/// Isinya seluruh data app (barang, peminjaman, riwayat) dalam satu berkas
/// `.db`. Salinan dibuat lewat `VACUUM INTO`, bukan menyalin berkasnya langsung,
/// supaya isinya konsisten meski database sedang terbuka.
class BackupService {
  BackupService({
    DatabaseHelper? helper,
    Future<Directory> Function()? directory,
  })  : _helper = helper ?? DatabaseHelper.instance,
        _directory = directory ?? getApplicationDocumentsDirectory;

  final DatabaseHelper _helper;

  /// Folder dokumen app. Bisa diganti di test supaya tidak butuh path_provider.
  final Future<Directory> Function() _directory;

  /// Nama folder di dalam folder dokumen app.
  static const folderName = 'backup';

  /// Salinan otomatis yang disimpan; yang lebih lama dihapus.
  static const keepCount = 6;

  /// Tabel yang wajib ada agar sebuah berkas dianggap backup Inventra.
  static const _requiredTables = {'items', 'loans', 'app_settings'};

  /// Membuat satu berkas backup dan mengembalikan jalurnya.
  Future<String> runBackup() async {
    final docs = await _directory();
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
    final docs = await _directory();
    return p.join(docs.path, folderName);
  }

  /// Daftar berkas backup yang ada saat ini, terbaru lebih dulu.
  Future<List<File>> listBackups() async {
    final docs = await _directory();
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

  /// Membuat salinan baru lalu menawarkan lokasi penyimpanannya ke pengguna.
  ///
  /// Ini satu-satunya jalan keluar berkas backup dari penyimpanan privat app:
  /// tanpa langkah ini, salinan ikut terhapus saat aplikasi di-uninstall.
  /// Mengembalikan false bila pengguna membatalkan dialog.
  Future<bool> saveCopyToDevice() async {
    final path = await runBackup();
    final bytes = await File(path).readAsBytes();
    final uri = await FilePicker.saveFile(
      fileName: p.basename(path),
      bytes: bytes,
      mimeType: 'application/octet-stream',
      dialogTitle: 'Simpan salinan data Inventra',
    );
    return uri != null;
  }

  /// Meminta satu berkas backup dari perangkat. Null bila dibatalkan.
  ///
  /// Tipe berkas sengaja `any`: Android memetakan filter ekstensi ke MIME, dan
  /// berkas `.db` sering tidak punya MIME yang dikenali, sehingga filternya
  /// justru menyembunyikan berkas yang dicari. Isi berkas tetap diperiksa di
  /// [_validate].
  Future<Uint8List?> pickBackupBytes() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Pilih berkas backup Inventra',
      type: FileType.any,
    );
    return file?.readAsBytes();
  }

  /// Mengganti seluruh data dengan isi [bytes], dan mengembalikan path salinan
  /// pengaman data lama.
  ///
  /// Urutannya penting: berkas diperiksa lebih dulu supaya berkas asing tidak
  /// pernah menyentuh database, lalu data saat ini disalin, baru database
  /// ditutup dan berkasnya ditukar. Database dibuka lagi sebelum kembali, jadi
  /// kegagalan migrasi terlihat di sini, bukan di layar berikutnya.
  Future<String> restoreFromBytes(Uint8List bytes) async {
    final temp = File(p.join(Directory.systemTemp.path, 'inventra-restore.db'));
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await _validate(temp);

      final safety = await runBackup();
      final target = await _helper.databasePath();
      await _helper.close();

      await temp.copy(target);
      // Sisa WAL dari database lama akan diputar ulang ke berkas baru dan
      // membuat isinya campur, jadi keduanya dibuang.
      for (final suffix in const ['-wal', '-shm']) {
        final sidecar = File('$target$suffix');
        if (sidecar.existsSync()) {
          await sidecar.delete();
        }
      }

      // Membuka kembali menjalankan migrasi bila backup berasal dari versi
      // skema yang lebih lama.
      await _helper.database;
      return safety;
    } on FileSystemException catch (error) {
      throw StorageException('Gagal menulis data: ${error.message}');
    } finally {
      if (temp.existsSync()) {
        await temp.delete();
      }
    }
  }

  /// Memastikan berkas benar-benar database Inventra, bukan sekadar berkas
  /// berakhiran `.db`.
  Future<void> _validate(File file) async {
    Database? db;
    try {
      db = await _helper.factory.openDatabase(
        file.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tables = rows.map((row) => row['name'] as String).toSet();
      if (!tables.containsAll(_requiredTables)) {
        throw const StorageException('Berkas itu bukan backup Inventra.');
      }

      final version = (await db.rawQuery('PRAGMA user_version')).first.values.first;
      if (version is int && version > DatabaseHelper.schemaVersion) {
        throw const StorageException(
          'Backup dibuat oleh aplikasi versi lebih baru. Perbarui aplikasi dulu.',
        );
      }
    } on DatabaseException {
      throw const StorageException(
        'Berkas itu tidak bisa dibaca sebagai database Inventra.',
      );
    } finally {
      await db?.close();
    }
  }
}
