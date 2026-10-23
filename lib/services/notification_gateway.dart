import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

/// Pembungkus tipis di atas `flutter_local_notifications`.
///
/// Ada sebagai antarmuka supaya [ReminderScheduler] bisa diuji tanpa plugin
/// platform (yang tidak tersedia di `flutter_test`).
abstract class NotificationGateway {
  /// Menyiapkan plugin dan zona waktu. Aman dipanggil berkali-kali.
  Future<void> initialize({void Function()? onTap});

  /// Meminta izin notifikasi. Mengembalikan true bila notifikasi boleh tampil.
  Future<bool> requestPermission();

  /// Status izin saat ini, tanpa memunculkan dialog.
  Future<bool> hasPermission();

  /// Waktu sekarang di zona jadwal (WIB), bukan zona perangkat.
  ///
  /// Jam ditaruh di sini supaya hanya gateway yang tahu zona waktunya, dan
  /// pengujian bisa memakai jam tetap.
  DateTime nowInZone();

  /// Jumlah notifikasi yang saat ini menunggu jadwalnya.
  Future<int> pendingCount();

  /// Membatalkan seluruh notifikasi terjadwal milik aplikasi.
  Future<void> cancelAll();

  /// Menjadwalkan satu slot pengingat.
  Future<void> schedule(ReminderSlot slot);

  /// Menampilkan satu notifikasi sekarang juga, tanpa menunggu slot.
  ///
  /// Dipakai tombol "Kirim notifikasi uji" di Pengaturan: kalau notifikasi ini
  /// tampil, izin, ikon, dan channel sudah benar, sehingga kegagalan berikutnya
  /// pasti ada di sisi jadwal, bukan di sisi tampilan.
  Future<void> showTest();
}

class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway({
    FlutterLocalNotificationsPlugin? plugin,
    this.timeZone = 'Asia/Jakarta',
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'loan_reminder';
  static const channelName = 'Pengingat pengembalian';
  static const channelDescription =
      'Mengingatkan barang yang harus dikembalikan pada 09.00, 13.00, dan '
      '15.00 sampai barang dikembalikan.';

  /// Ikon status bar. Harus siluet putih; lihat `res/drawable`.
  static const icon = 'ic_stat_reminder';

  /// Semua notifikasi pengingat memakai payload ini, sehingga ketukan bisa
  /// diarahkan ke daftar peminjaman.
  static const payload = 'loan_reminder:list';

  /// ID notifikasi uji. Jauh di bawah rentang pengingat terjadwal (1e9+), jadi
  /// keduanya tidak pernah saling menimpa.
  static const testNotificationId = 1;

  final FlutterLocalNotificationsPlugin _plugin;

  /// Spesifikasi menyebut WIB, jadi jadwal tidak mengikuti zona perangkat.
  final String timeZone;

  bool _initialized = false;

  @override
  Future<void> initialize({void Function()? onTap}) async {
    if (_initialized) {
      return;
    }
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(timeZone));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(icon),
      ),
      onDidReceiveNotificationResponse: (_) => onTap?.call(),
    );
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> requestPermission() async {
    final granted = await _android?.requestNotificationsPermission();
    // null berarti platform tidak punya konsep izin runtime (Android < 13).
    return granted ?? true;
  }

  @override
  Future<bool> hasPermission() async => await _android?.areNotificationsEnabled() ?? true;

  @override
  DateTime nowInZone() => tz.TZDateTime.now(tz.local);

  @override
  Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;

  /// Membatalkan seluruh notifikasi terjadwal. Aman karena hanya pengingat
  /// yang pernah dijadwalkan aplikasi ini.
  @override
  Future<void> cancelAll() => _plugin.cancelAllPendingNotifications();

  @override
  Future<void> schedule(ReminderSlot slot) {
    final when = tz.TZDateTime(
      tz.local,
      slot.when.year,
      slot.when.month,
      slot.when.day,
      slot.when.hour,
    );
    return _plugin.zonedSchedule(
      id: slot.id,
      title: slot.title,
      body: slot.summary,
      scheduledDate: when,
      payload: payload,
      // Inexact: tidak butuh izin exact alarm, dan selisih beberapa menit
      // tidak berarti untuk pengingat harian.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: _details(
        BigTextStyleInformation(
          slot.detail,
          contentTitle: slot.title,
          summaryText: slot.summary,
        ),
      ),
    );
  }

  @override
  Future<void> showTest() async {
    await initialize();
    const title = 'Pengingat pengembalian aktif';
    await _plugin.show(
      id: testNotificationId,
      title: title,
      body: 'Ini notifikasi uji, bukan pengingat sungguhan.',
      payload: payload,
      notificationDetails: _details(
        const BigTextStyleInformation(
          'Kalau notifikasi ini terlihat, izin, ikon, dan channel sudah '
          'benar. Pengingat asli dikirim pukul 09.00, 13.00, dan 15.00 '
          'setiap hari sampai barang ditandai dikembalikan.\n\n'
          'Ketuk untuk membuka daftar',
          contentTitle: title,
        ),
      ),
    );
  }

  /// Tampilan notifikasi yang dipakai bersama oleh pengingat terjadwal dan
  /// notifikasi uji, supaya keduanya tidak pernah berbeda channel atau ikon.
  NotificationDetails _details(StyleInformation styleInformation) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          icon: icon,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          styleInformation: styleInformation,
        ),
      );
}
