import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_client.dart';
import '../location_helper.dart';
import '../tracking_service.dart';
import 'complete_visit_screen.dart';

class VisitDetailScreen extends StatefulWidget {
  final Map<String, dynamic> visit;
  const VisitDetailScreen({super.key, required this.visit});

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  late Map<String, dynamic> _visit;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _visit = widget.visit;
  }

  Map<String, dynamic> get _institution => _visit['institution'] as Map<String, dynamic>;

  Future<void> _checkIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pos = await LocationHelper.getCurrentPosition();
      if (pos == null) {
        throw LocationException('Could not get your location. Move to an open area and try again.');
      }
      final result = await ApiClient.instance.checkIn(
        planId: _visit['plan_id'] as int,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      setState(() {
        _visit = {
          ..._visit,
          'state': 'in_progress',
          'visit_record_id': result['visit_record_id'],
        };
      });
      await TrackingService.instance.setReason('visit', true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked in - location captured.')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOut() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      double? lat, lng;
      try {
        final pos = await LocationHelper.getCurrentPosition();
        lat = pos?.latitude;
        lng = pos?.longitude;
      } catch (_) {
        // check-out must never be blocked by GPS
      }
      final r = await ApiClient.instance.checkOut(
        visitRecordId: _visit['visit_record_id'] as int,
        latitude: lat,
        longitude: lng,
      );
      setState(() => _visit = {..._visit, 'checkout_time': r['checkout_time']});
      await TrackingService.instance.setReason('visit', false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked out.')));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _call(String phone) async {
    if (phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _openMap(double lat, double lng) async {
    if (lat == 0 && lng == 0) return;
    await launchUrl(Uri.parse('https://www.google.com/maps?q=$lat,$lng'));
  }

  @override
  Widget build(BuildContext context) {
    final state = _visit['state'] as String? ?? 'draft';
    final phone = (_institution['phone'] ?? '') as String;
    final lat = (_institution['latitude'] ?? 0.0) as num;
    final lng = (_institution['longitude'] ?? 0.0) as num;

    return Scaffold(
      appBar: AppBar(title: Text(_institution['name'] ?? 'Visit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(_institution['name'] ?? '',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    if (_institution['is_high_priority'] == true) const Icon(Icons.star, color: Colors.amber),
                  ]),
                  const SizedBox(height: 4),
                  Text(_institution['address'] ?? '', style: const TextStyle(color: Colors.grey)),
                  if ((_institution['location'] ?? '').toString().isNotEmpty)
                    Text(_institution['location'], style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (phone.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.call, size: 18),
                        label: Text(phone),
                        onPressed: () => _call(phone),
                      ),
                    if (lat != 0 || lng != 0)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('Map'),
                        onPressed: () => _openMap(lat.toDouble(), lng.toDouble()),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Chip(label: Text('Status: $state')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          if (state == 'draft' || state == 'planned')
            FilledButton.icon(
              icon: const Icon(Icons.location_on),
              label: const Text('Check In (captures GPS now)'),
              onPressed: _busy ? null : _checkIn,
            ),
          if (state == 'in_progress' && _visit['visit_record_id'] != null && _visit['checkout_time'] == null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Check Out'),
              onPressed: _busy ? null : _checkOut,
            ),
          ],
          if (state == 'in_progress' || state == 'planned' || state == 'draft') ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.check_circle),
              label: const Text('Complete Visit'),
              onPressed: _busy
                  ? null
                  : () async {
                      final done = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => CompleteVisitScreen(visit: _visit)),
                      );
                      if (done == true) await TrackingService.instance.setReason('visit', false);
                      if (done == true && mounted) Navigator.of(context).pop();
                    },
            ),
          ],
          if (state == 'completed')
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('This visit is already completed.', style: TextStyle(color: Colors.green)),
            ),
        ],
      ),
    );
  }
}
