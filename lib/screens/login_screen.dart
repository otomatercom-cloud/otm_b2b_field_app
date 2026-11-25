import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_config.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverCtrl = TextEditingController(text: AppConfig.isLocked ? AppConfig.serverUrl : 'https://');
  final _dbCtrl = TextEditingController(text: AppConfig.dbName);
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient.instance.login(
        serverUrl: _serverCtrl.text.trim(),
        db: _dbCtrl.text.trim(),
        login: _loginCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.business_center, size: 64, color: Color(0xFF1565C0)),
                  const SizedBox(height: 8),
                  const Text('Otomater B2B Field App',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Logic School of Management',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 32),
                  if (!AppConfig.isLocked) ...[
                  TextFormField(
                    controller: _serverCtrl,
                    decoration: const InputDecoration(labelText: 'Server URL', prefixIcon: Icon(Icons.dns)),
                    keyboardType: TextInputType.url,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dbCtrl,
                    decoration: const InputDecoration(labelText: 'Database name', prefixIcon: Icon(Icons.storage)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _loginCtrl,
                    decoration: const InputDecoration(labelText: 'Email / Username', prefixIcon: Icon(Icons.person)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                    obscureText: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Log In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
