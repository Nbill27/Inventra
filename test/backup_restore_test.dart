import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peminjaman_barang/core/exceptions.dart';
import 'package:peminjaman_barang/db/database_helper.dart';
import 'package:peminjaman_barang/repositories/item_repository.dart';
import 'package:peminjaman_barang/services/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_database.dart';

/// Memulihkan backup berarti menukar berkas database yang sedang dipakai, jadi
/// urutan pemeriksaan dan penukarannya diuji langsung di sini, bukan lewat UI.
void main() {
  late Directory tempDir;

  setUp(() async {
    sqfliteFfiInit();
    tempDir = await Directory.systemTemp.createTemp('inventra_restore_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  DatabaseHelper helperAt(String fileName) {
    final helper = DatabaseHelper(
      factory: databaseFactoryFfi,
      path: p.join(tempDir.path, fileName),
      seedLoader: () async => [],
    );
    // Windows mengunci berkas yang masih terbuka, jadi setiap koneksi ditutup
    // sebelum folder sementara dihapus.
    addTearDown(helper.close);
    return helper;
  }

  /// Database berisi satu barang, ditutup, lalu dibaca sebagai bytes seperti
  /// berkas yang dipilih pengguna dari penyimpanan.
  Future<Uint8List> backupWithItem(String name) async {
    final helper = helperAt('sumber-$name.db');
    await ItemRepository(helper: helper).create(itemFixture(name: name));
    final path = await helper.databasePath();
    await helper.close();
    return File(path).readAsBytes();
  }

  test('isi backup menggantikan seluruh data yang ada', () async {
    final bytes = await backupWithItem('Kamera');

    final helper = helperAt('aktif.db');
    final items = ItemRepository(helper: helper);
    await items.create(itemFixture(name: 'Proyektor'));
    final service = BackupService(helper: helper, directory: () async => tempDir);

    await service.restoreFromBytes(bytes);

    final names = (await items.getAll()).map((item) => item.name);
    expect(names, contains('Kamera'));
    expect(names, isNot(contains('Proyektor')));
  });

  test('data lama tetap utuh bila berkasnya bukan database', () async {
    final helper = helperAt('aktif.db');
    final items = ItemRepository(helper: helper);
    await items.create(itemFixture(name: 'Proyektor'));
    final service = BackupService(helper: helper, directory: () async => tempDir);

    await expectLater(
      service.restoreFromBytes(Uint8List.fromList(utf8.encode('bukan database'))),
      throwsA(isA<StorageException>()),
    );

    expect((await items.getAll()).map((item) => item.name), contains('Proyektor'));
  });

  test('database asing tanpa tabel Inventra ditolak', () async {
    // Dibuat lewat factory mentah: kalau lewat DatabaseHelper, skema Inventra
    // ikut terbentuk dan berkasnya justru sah sebagai backup.
    final path = p.join(tempDir.path, 'asing.db');
    final asing = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1),
    );
    await asing.execute('CREATE TABLE catatan (id INTEGER PRIMARY KEY)');
    await asing.close();
    final bytes = await File(path).readAsBytes();

    final helper = helperAt('aktif.db');
    final items = ItemRepository(helper: helper);
    await items.create(itemFixture(name: 'Proyektor'));
    final service = BackupService(helper: helper, directory: () async => tempDir);

    await expectLater(
      service.restoreFromBytes(bytes),
      throwsA(isA<StorageException>()),
    );
    expect((await items.getAll()).map((item) => item.name), contains('Proyektor'));
  });

  test('salinan pengaman dibuat sebelum data ditukar', () async {
    final bytes = await backupWithItem('Kamera');

    final helper = helperAt('aktif.db');
    await ItemRepository(helper: helper).create(itemFixture(name: 'Proyektor'));
    final service = BackupService(helper: helper, directory: () async => tempDir);

    final safety = await service.restoreFromBytes(bytes);

    expect(File(safety).existsSync(), isTrue);
    final backups = await service.listBackups();
    expect(backups.map((file) => file.path), contains(safety));
  });
}
