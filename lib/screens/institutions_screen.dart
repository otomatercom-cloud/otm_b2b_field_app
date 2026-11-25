import 'dart:async';
import 'package:flutter/material.dart';
import '../api_client.dart';

class InstitutionsScreen extends StatefulWidget {
  final bool highPriorityOnly;
  const InstitutionsScreen({super.key, this.highPriorityOnly = false});

  @override
  State<InstitutionsScreen> createState() => _InstitutionsScreenState();
}

class _InstitutionsScreenState extends State<InstitutionsScreen> {
  List<dynamic> _institutions = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String q = ''}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.instance.searchInstitutions(q: q, highPriorityOnly: widget.highPriorityOnly);
      setState(() => _institutions = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(q: v));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.highPriorityOnly ? 'High Priority Institutions' : 'Institutions'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name, city or area',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : ListView.separated(
                        itemCount: _institutions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final inst = _institutions[i] as Map<String, dynamic>;
                          return ListTile(
                            leading: Icon(inst['is_high_priority'] == true ? Icons.star : Icons.apartment,
                                color: inst['is_high_priority'] == true ? Colors.amber : null),
                            title: Text(inst['name'] ?? ''),
                            subtitle: Text(inst['address'] ?? ''),
                            trailing: Text(inst['tier'] ?? ''),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
