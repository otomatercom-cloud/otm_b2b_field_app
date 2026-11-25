import 'package:flutter/material.dart';
import '../api_client.dart';
import 'login_screen.dart';
import 'visit_list_screen.dart';
import 'institutions_screen.dart';
import 'seminar_list_screen.dart';
import 'trip_screen.dart';
import '../tracking_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _dashboard;
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
      final data = await ApiClient.instance.getDashboard();
      setState(() => _dashboard = data);
      try {
        final trip = await ApiClient.instance.getCurrentTrip();
        await TrackingService.instance.setReason('trip', trip != null);
      } catch (_) {}
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await TrackingService.instance.stop();
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = (_dashboard?['cards'] as Map?) ?? {};
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${ApiClient.instance.userName ?? ''}'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Log out'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ])
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _StatCard(
                            label: "Today's Visits",
                            value: '${cards['today_visits'] ?? 0}',
                            icon: Icons.today,
                            color: Colors.blue,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const VisitListScreen(scope: 'today'))),
                          ),
                          _StatCard(
                            label: 'Upcoming Visits',
                            value: '${cards['upcoming_visits'] ?? 0}',
                            icon: Icons.event,
                            color: Colors.orange,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const VisitListScreen(scope: 'upcoming'))),
                          ),
                          _StatCard(
                            label: 'High Priority',
                            value: '${cards['high_priority_institutions'] ?? 0}',
                            icon: Icons.star,
                            color: Colors.amber,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const InstitutionsScreen(highPriorityOnly: true))),
                          ),
                          _StatCard(
                            label: 'My Institutions',
                            value: '${cards['my_institutions'] ?? cards['total_institutions'] ?? 0}',
                            icon: Icons.apartment,
                            color: Colors.teal,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const InstitutionsScreen())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.school),
                        label: const Text("Today's Seminars"),
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const SeminarListScreen())),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.directions_car),
                        label: const Text('Day Trip (KM + live tracking)'),
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const TripScreen())),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.location_on),
                        label: const Text("Start Today's Visits"),
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const VisitListScreen(scope: 'today'))),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
