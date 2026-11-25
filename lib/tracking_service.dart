import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_client.dart';

/// Live location tracking. Runs only while a reason is active (a day trip is
/// open, or a visit/seminar is checked in) and stops on check-out / trip end /
/// logout. On Android a foreground notification keeps it alive with the
/// screen off. Points are buffered and re-sent if the network drops.
class TrackingService {
  static final TrackingService instance = TrackingService._();
  TrackingService._();

  final Set<String> _reasons = {};
  final List<Map<String, dynamic>> _buffer = [];
  StreamSubscription<Position>? _sub;
  Timer? _timer;
  DateTime _lastKept = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isRunning => _sub != null;

  Future<void> setReason(String reason, bool on) async {
    if (on) {
      _reasons.add(reason);
      await _start();
    } else {
      _reasons.remove(reason);
      if (_reasons.isEmpty) await stop();
    }
  }

  Future<void> _start() async {
    if (_sub != null) return;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Otomater B2B',
          notificationText: 'Location tracking is on while your visit/trip is active.',
          enableWakeLock: true,
        ),
      );
      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition, onError: (_) {});
      _timer = Timer.periodic(const Duration(seconds: 60), (_) => flush());
    } catch (_) {
      // tracking must never break the main flow
    }
  }

  void _onPosition(Position p) {
    final now = DateTime.now();
    if (now.difference(_lastKept).inSeconds < 20) return;
    _lastKept = now;
    _buffer.add({
      'latitude': p.latitude,
      'longitude': p.longitude,
      'accuracy': p.accuracy,
      'recorded_at': now.toUtc().toIso8601String().substring(0, 19).replaceFirst('T', ' '),
    });
    if (_buffer.length > 500) _buffer.removeRange(0, _buffer.length - 500);
  }

  Future<void> flush() async {
    if (_buffer.isEmpty || !ApiClient.instance.isLoggedIn) return;
    final batch = List<Map<String, dynamic>>.from(_buffer.take(100));
    try {
      await ApiClient.instance.sendPings(batch);
      _buffer.removeRange(0, batch.length);
    } catch (_) {
      // keep buffered, retry on next tick
    }
  }

  Future<void> stop() async {
    _reasons.clear();
    await _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    await flush();
  }
}
