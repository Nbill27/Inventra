import 'package:flutter/services.dart';

/// Jembatan tipis ke Android untuk hal yang tidak bisa dibaca dari Dart: versi
/// paket yang benar-benar terpasang dan status optimasi baterai.
///
/// Semua metode mengembalikan null bila kanal tidak tersedia (widget test atau
/// platform lain), sehingga layar tetap bisa dirender tanpa plugin platform.
class SystemGateway {
  const SystemGateway();

  static const _channel = MethodChannel('inventra/system');

  /// Contoh hasil: `1.1.0 (3)`.
  Future<String?> appVersion() => _invoke<String>('appVersion');

  /// True bila Android tidak membatasi app ini; null bila tidak bisa dibaca.
  Future<bool?> isIgnoringBatteryOptimizations() =>
      _invoke<bool>('isIgnoringBatteryOptimizations');

  /// Membuka daftar aplikasi yang dikecualikan dari optimasi baterai.
  Future<void> openBatterySettings() async {
    try {
      await _channel.invokeMethod<void>('openBatterySettings');
    } on PlatformException {
      // Tidak ada halaman setelan yang bisa dibuka; tombolnya tidak berbuat apa-apa.
    } on MissingPluginException {
      // Platform tanpa kanal ini.
    }
  }

  Future<T?> _invoke<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
