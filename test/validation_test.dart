import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/core/exceptions.dart';
import 'package:peminjaman_barang/core/validation.dart';

void main() {
  group('contactProblem', () {
    test('kosong selalu diterima', () {
      expect(contactProblem(null), isNull);
      expect(contactProblem('   '), isNull);
      expect(optionalContact('  '), isNull);
    });

    test('nomor telepon lolos', () {
      expect(contactProblem('0812-3456-7890'), isNull);
      expect(contactProblem('+62 812 3456 7890'), isNull);
      expect(contactProblem('(021) 555-1234'), isNull);
    });

    test('email lolos, termasuk garis bawah dan domain bertitik', () {
      // Kolom ini petunjuknya "nomor HP, email, atau WA", jadi `@` tidak boleh
      // ditolak seperti sebelumnya.
      expect(contactProblem('budi@contoh.id'), isNull);
      expect(contactProblem('budi_setiawan@contoh.co.id'), isNull);
      expect(contactProblem('a@b.co'), isNull);
    });

    test('email yang bentuknya salah ditolak dengan pesan sendiri', () {
      expect(contactProblem('budi@'), 'Kontak berupa email harus berformat nama@domain.');
      expect(contactProblem('@contoh.id'), contains('nama@domain'));
      expect(contactProblem('budi@contoh'), contains('nama@domain'));
      expect(contactProblem('budi@@contoh.id'), contains('nama@domain'));
    });

    test('karakter di luar daftar ditolak', () {
      expect(contactProblem('budi#1'), contains('hanya boleh'));
      expect(contactProblem('<script>'), contains('hanya boleh'));
      expect(contactProblem('a;b'), contains('hanya boleh'));
    });

    test('batas panjang ditegakkan', () {
      expect(contactProblem('0' * contactMaxLength), isNull);
      expect(
        contactProblem('0' * (contactMaxLength + 1)),
        'Kontak maksimal $contactMaxLength karakter.',
      );
    });

    test('optionalContact melempar untuk isi yang salah', () {
      expect(
        () => optionalContact('budi@'),
        throwsA(isA<ValidationException>()),
      );
      // Panjang minimum sengaja bukan urusan lapisan ini, supaya data lama yang
      // pendek masih bisa disunting.
      expect(optionalContact(' 0812 '), '0812');
    });
  });
}
