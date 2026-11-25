import 'package:geolocator/geolocator.dart';

/// Captures real device GPS - this is the actual fix for "location not
/// recorded": a phone's own GPS chip, not a desktop browser's location
/// prompt (which the backend "+New" button could never reliably trigger).
class LocationHelper {
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Location services are turned off on this phone. Please enable GPS/Location.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission was denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
          'Location permission is permanently denied. Enable it from the phone\'s app settings.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
  }
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}
