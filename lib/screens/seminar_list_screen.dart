import 'package:flutter/material.dart';
import '../api_client.dart';
import '../location_helper.dart';
import '../tracking_service.dart';

class SeminarListScreen extends StatefulWidget {
  const SeminarListScreen({super.key});

  @override
  State<SeminarListScreen> createState() => _SeminarListScreenState();
}

class _SeminarListScreenState extends State<SeminarListScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _items = await ApiClient.instance.getSeminars();
      final active = _items.any((s) => s['checkin_time'] != null && s['checkout_time'] == null);
      await TrackingService.instance.setReason('seminar', active);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkIn(Map s) => _run(() async {
        final pos = await LocationHelper.getCurrentPosition();
        if (pos == null) throw LocationException('Could not get your location. Try again in an open area.');
        await ApiClient.instance.seminarCheckIn(s['plan_id'] as int, pos.latitude, pos.longitude);
      });

  Future<void> _checkOut(Map s) => _run(() async {
        double? lat, lng;
        try {
          final pos = await LocationHelper.getCurrentPosition();
          lat = pos?.latitude;
          lng = pos?.longitude;
        } catch (_) {}
        await ApiClient.instance.seminarCheckOut(s['seminar_id'] as int, lat: lat, lng: lng);
        await TrackingService.instance.flush();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Seminars")),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                if (_error != null)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                if (_items.isEmpty) const Text('No seminars planned for today.'),
                for (final s in _items)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s['institution']['name'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text(s['institution']['address'] ?? '', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 6),
                        Text('Status: ${s['state']}'),
                        if (s['checkin_time'] != null) Text('In: ${s['checkin_time']} UTC'),
                        if (s['checkout_time'] != null) Text('Out: ${s['checkout_time']} UTC'),
                        const SizedBox(height: 8),
                        if (s['seminar_id'] == false || s['seminar_id'] == null)
                          FilledButton.icon(
                            icon: const Icon(Icons.location_on),
                            label: const Text('Check In (location required)'),
                            onPressed: _busy ? null : () => _checkIn(s),
                          )
                        else if (s['checkout_time'] == null)
                          FilledButton.icon(
                            icon: const Icon(Icons.logout),
                            label: const Text('Check Out'),
                            onPressed: _busy ? null : () => _checkOut(s),
                          )
                        else
                          const Text('Seminar done.', style: TextStyle(color: Colors.green)),
                      ]),
                    ),
                  ),
              ]),
      ),
    );
  }
}
