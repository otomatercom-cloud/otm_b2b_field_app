import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../location_helper.dart';

class CompleteVisitScreen extends StatefulWidget {
  final Map<String, dynamic> visit;
  const CompleteVisitScreen({super.key, required this.visit});

  @override
  State<CompleteVisitScreen> createState() => _CompleteVisitScreenState();
}

class _NewContact {
  final nameCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
}

class _CompleteVisitScreenState extends State<CompleteVisitScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<dynamic> _existingContacts = [];
  List<dynamic> _activityTypes = [];
  final Set<int> _selectedContactIds = {};
  final List<_NewContact> _newContacts = [];

  int? _activityTypeId;
  final _remarksCtrl = TextEditingController();
  final _nextActionCtrl = TextEditingController();
  DateTime? _followupDate;

  Map<String, dynamic> get _institution => widget.visit['institution'] as Map<String, dynamic>;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final contacts = await ApiClient.instance.getInstitutionContacts(_institution['id'] as int);
      final types = await ApiClient.instance.getActivityTypes();
      setState(() {
        _existingContacts = contacts;
        _activityTypes = types;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addContactRow() {
    setState(() => _newContacts.add(_NewContact()));
  }

  Future<void> _submit() async {
    if (_remarksCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Remarks are required.');
      return;
    }
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
        // GPS optional at completion time - it was already captured at check-in.
      }
      final newContacts = _newContacts
          .where((c) => c.nameCtrl.text.trim().isNotEmpty || c.mobileCtrl.text.trim().isNotEmpty)
          .map((c) => {'name': c.nameCtrl.text.trim(), 'mobile': c.mobileCtrl.text.trim()})
          .toList();

      await ApiClient.instance.completeVisit(
        planId: widget.visit['plan_id'] as int?,
        visitRecordId: widget.visit['visit_record_id'] as int?,
        activityTypeId: _activityTypeId,
        remarks: _remarksCtrl.text.trim(),
        nextAction: _nextActionCtrl.text.trim(),
        nextFollowupDate: _followupDate != null ? DateFormat('yyyy-MM-dd').format(_followupDate!) : null,
        contactIds: _selectedContactIds.toList(),
        newContacts: newContacts,
        latitude: lat,
        longitude: lng,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('Complete Visit')), body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Visit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_institution['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Activity Type', border: OutlineInputBorder()),
            value: _activityTypeId,
            items: _activityTypes
                .map((t) => DropdownMenuItem<int>(value: t['id'] as int, child: Text(t['name'] ?? '')))
                .toList(),
            onChanged: (v) => setState(() => _activityTypeId = v),
          ),
          const SizedBox(height: 16),
          const Text('Contacts Met', style: TextStyle(fontWeight: FontWeight.bold)),
          if (_existingContacts.isEmpty) const Text('No saved contacts yet for this institution.', style: TextStyle(color: Colors.grey)),
          ..._existingContacts.map((c) {
            final id = c['id'] as int;
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _selectedContactIds.contains(id),
              title: Text(c['name'] ?? ''),
              subtitle: Text([c['designation'], c['mobile']].where((s) => (s ?? '').toString().isNotEmpty).join(' - ')),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selectedContactIds.add(id);
                } else {
                  _selectedContactIds.remove(id);
                }
              }),
            );
          }),
          const SizedBox(height: 8),
          ..._newContacts.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: c.nameCtrl,
                    decoration: const InputDecoration(labelText: 'New contact name', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: c.mobileCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _newContacts.removeAt(i)),
                ),
              ]),
            );
          }),
          TextButton.icon(
            onPressed: _addContactRow,
            icon: const Icon(Icons.add),
            label: const Text('Add another contact'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _remarksCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Remarks *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nextActionCtrl,
            decoration: const InputDecoration(labelText: 'Next Action', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _followupDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Next Followup Date', border: OutlineInputBorder()),
              child: Text(_followupDate != null ? DateFormat('dd MMM yyyy').format(_followupDate!) : 'Not set'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Mark Visit Done'),
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
