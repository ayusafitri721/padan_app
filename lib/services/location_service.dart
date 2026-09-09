import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

class DeviceLocation {
  const DeviceLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  /// True bila dua titik dalam ~1 km (2 desimal) — cukup untuk kode adm4.
  bool isCloseTo(DeviceLocation other) =>
      latitude.toStringAsFixed(2) == other.latitude.toStringAsFixed(2) &&
      longitude.toStringAsFixed(2) == other.longitude.toStringAsFixed(2);
}

class LocationService {
  LocationService._();

  /// Hasil GPS terakhir sesi ini (TTL 5 menit) + single-flight:
  /// berapa pun pemanggilnya (cuaca, rekomendasi, detail), request GPS
  /// device hanya terjadi SEKALI — sisanya pakai hasil yang sama.
  static DeviceLocation? _cached;
  static DateTime? _cachedAt;
  static Future<DeviceLocation?>? _inFlight;
  static const _cacheTtl = Duration(minutes: 5);

  /// Lokasi presisi terakhir yang berhasil didapat sesi ini (tanpa TTL).
  /// Dipakai untuk paint pertama agar tidak lewat default Kemayoran —
  /// mencegah kartu cuaca "melompat" Cerah → Hujan tiap dibuka.
  static DeviceLocation? lastResolved;

  static Future<DeviceLocation?> getSharedLocation() {
    final cached = _cached;
    if (cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return Future.value(cached);
    }
    return _inFlight ??= _fetchAndCache();
  }

  static Future<DeviceLocation?> _fetchAndCache() async {
    try {
      final loc = await getCurrentLocation();
      if (loc != null) {
        _cached = loc;
        _cachedAt = DateTime.now();
      }
      return loc;
    } finally {
      _inFlight = null;
    }
  }

  static Future<bool> get isPermissionGranted async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    return Geolocator.checkPermission().then(_accepted);
  }

  static Future<DeviceLocation?> getLastKnownLocation() async {
    // geolocator_web TIDAK mengimplementasikan ini (selalu throw
    // UnsupportedError) — jangan panggil sama sekali di web.
    if (kIsWeb) return null;
    // Instan (tanpa fix GPS / dialog izin) — cocok untuk paint pertama.
    // .timeout paksa: di beberapa browser future plugin tidak pernah
    // selesai bila lokasi tak tersedia — tanpa ini UI muter selamanya.
    try {
      final position = await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 3));
      if (position == null) return null;
      return DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<DeviceLocation?> getBestLocation() async {
    // Lokasi terakhir yang tersimpan dulu (instan), baru fix GPS
    // presisi — dan fix-nya dishare satu sesi via getSharedLocation.
    return await getLastKnownLocation() ?? await getSharedLocation();
  }

  static Future<DeviceLocation?> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (!_accepted(permission)) {
      permission = await Geolocator.requestPermission();
      if (!_accepted(permission)) return null;
    }

    try {
      // Backstop 10 detik: timeLimit plugin tidak selalu dihormati di web.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      ).timeout(const Duration(seconds: 10));
      final loc = DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      lastResolved = loc;
      return loc;
    } catch (_) {
      return null;
    }
  }

  static bool _accepted(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}