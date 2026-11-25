import 'package:flutter/material.dart';
import '../api_client.dart';
import '../tracking_service.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  Map<String, dynamic>? _trip;
  List<dynamic> _visits = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _meter = TextEditingController();
  final _place = TextEditingController();
  int? _planId; // null = other place

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _trip = await ApiClient.instance.getCurrentTrip();
      _visits = await ApiClient.instance.getVisits();
      await TrackingService.instance.setReason('trip', _trip != null);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _readMeter() {
    final v = double.tryParse(_meter.text.trim());
    if (v == null) setState(() => _error = 'Enter a valid meter reading.');
    return v;
  }

  Future<void> _run(Future<Map<String, dynamic>?> Function(double m) fn) async {
    final m = _readMeter();
    if (m == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _trip = await fn(m);
      _meter.clear();
      _place.clear();
      await TrackingService.instance.setReason('trip', _trip != null && _trip!['state'] == 'in_progress');
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _trip != null && _trip!['state'] == 'in_progress';
    return Scaffold(
      appBar: AppBar(title: const Text('Day Trip (KM)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_trip != null) ...[
                Card(
                  child: ListTile(
                    title: Text('${_trip!['name']}'),
                    subtitle: Text('Start meter ${_trip!['start_meter']}  |  ${_trip!['total_km']} km  |  ${_trip!['stop_count']} stops'),
                    trailing: Chip(label: Text('${_trip!['state']}')),
                  ),
                ),
                for (final l in (_trip!['lines'] as List))
                  ListTile(dense: true, title: Text('${l['name']}'), trailing: Text('${l['km']} km')),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _meter,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _trip == null ? 'Starting meter reading' : 'Current meter reading',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_trip == null)
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Day (tracking on)'),
                  onPressed: _busy ? null : () => _run((m) => ApiClient.instance.startTrip(m)),
                ),
              if (active) ...[
                DropdownButtonFormField<int?>(
                  value: _planId,
                  decoration: const InputDecoration(labelText: 'Stop at', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Other place')),
                    for (final v in _visits)
                      DropdownMenuItem<int?>(value: v['plan_id'] as int, child: Text('${v['institution']['name']}')),
                  ],
                  onChanged: (v) => setState(() => _planId = v),
                ),
                if (_planId == null) ...[
                  const SizedBox(height: 8),
                  TextField(controller: _place, decoration: const InputDecoration(labelText: 'Place name', border: OutlineInputBorder())),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Add Stop'),
                  onPressed: _busy
                      ? null
                      : () => _run((m) => ApiClient.instance.addTripStop(meter: m, planId: _planId, locationName: _place.text)),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.home),
                  label: const Text('Return Home & Finish Day'),
                  onPressed: _busy ? null : () => _run((m) => ApiClient.instance.finishTrip(m)),
                ),
              ],
            ]),
    );
  }
}
