import 'package:geolocator/geolocator.dart';

class DeviceLocation {
  const DeviceLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class LocationService {
  LocationService._();

  static Future<bool> get isPermissionGranted async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    return Geolocator.checkPermission().then(_accepted);
  }

  static Future<DeviceLocation?> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (!_accepted(permission)) {
      permission = await Geolocator.requestPermission();
      if (!_accepted(permission)) return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on Exception {
      return null;
    }
  }

  static bool _accepted(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}