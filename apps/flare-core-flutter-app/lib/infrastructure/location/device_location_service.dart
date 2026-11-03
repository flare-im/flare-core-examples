import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DeviceLocationSnapshot {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String? title;
  final String? address;

  const DeviceLocationSnapshot({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.title,
    this.address,
  });

  static String staticMapUrl({
    required double latitude,
    required double longitude,
    int zoom = 16,
  }) {
    final z = zoom.clamp(1, 18);
    final center = '$latitude,$longitude';
    return 'https://staticmap.openstreetmap.de/staticmap.php?center=${Uri.encodeComponent(center)}&zoom=$z&size=640x240';
  }
}

class LocationSearchResult {
  final double latitude;
  final double longitude;
  final String title;
  final String? address;

  const LocationSearchResult({
    required this.latitude,
    required this.longitude,
    required this.title,
    this.address,
  });

  DeviceLocationSnapshot toSnapshot({double? accuracyMeters}) {
    return DeviceLocationSnapshot(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      title: title,
      address: address,
    );
  }
}

class DeviceLocationService {
  const DeviceLocationService();

  Future<DeviceLocationSnapshot> currentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('手机定位服务未开启');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('未获得定位权限');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError('定位权限已被系统拒绝，请在系统设置中开启');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

    final place = await reverseGeocode(position.latitude, position.longitude);
    return DeviceLocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy.isFinite ? position.accuracy : null,
      title: place?.title,
      address: place?.address,
    );
  }

  Future<List<LocationSearchResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final locations = await locationFromAddress(q);
    final out = <LocationSearchResult>[];
    for (final loc in locations.take(8)) {
      final place = await reverseGeocode(loc.latitude, loc.longitude);
      out.add(
        LocationSearchResult(
          latitude: loc.latitude,
          longitude: loc.longitude,
          title: place?.title?.trim().isNotEmpty == true ? place!.title! : q,
          address: place?.address,
        ),
      );
    }
    return out;
  }

  Future<({String? title, String? address})?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      if (places.isEmpty) return null;
      final first = places.first;
      final name = _firstNonEmpty([
        first.name,
        first.street,
        first.subLocality,
        first.locality,
      ]);
      final address = _joinNonEmpty([
        first.country,
        first.administrativeArea,
        first.locality,
        first.subLocality,
        first.street,
      ]);
      return (title: name, address: address.isEmpty ? null : address);
    } catch (_) {
      return null;
    }
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final v in values) {
      final t = v?.trim() ?? '';
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  String _joinNonEmpty(Iterable<String?> values) {
    final seen = <String>{};
    final parts = <String>[];
    for (final v in values) {
      final t = v?.trim() ?? '';
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      parts.add(t);
    }
    return parts.join(' ');
  }
}
