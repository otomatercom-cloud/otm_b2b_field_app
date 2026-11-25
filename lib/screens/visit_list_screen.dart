import 'package:flutter/material.dart';
import '../api_client.dart';
import 'visit_detail_screen.dart';

class VisitListScreen extends StatefulWidget {
  final String scope; // 'today' | 'upcoming'
  const VisitListScreen({super.key, required this.scope});

  @override
  State<VisitListScreen> createState() => _VisitListScreenState();
}

class _VisitListScreenState extends State<VisitListScreen> {
  List<dynamic> _visits = [];
  bool _loading = true;
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
      final visits = await ApiClient.instance.getVisits(scope: widget.scope);
      setState(() => _visits = visits);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.scope == 'today' ? "Today's Visits" : 'Upcoming Visits')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!))])
                : _visits.isEmpty
                    ? ListView(children: const [
                        Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No visits.')))
                      ])
                    : ListView.separated(
                        itemCount: _visits.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final v = _visits[i] as Map<String, dynamic>;
                          final inst = v['institution'] as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _priorityColor(v['priority']),
                              child: Icon(
                                inst['is_high_priority'] == true ? Icons.star : Icons.apartment,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(inst['name'] ?? ''),
                            subtitle: Text('${inst['address'] ?? ''}\nState: ${v['state']}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => VisitDetailScreen(visit: v)),
                              );
                              _load();
                            },
                          );
                        },
                      ),
      ),
    );
  }
}
