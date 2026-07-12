import 'package:flutter/material.dart';

class DebugSplashScreen extends StatefulWidget {
  final Future<void> initializationFuture;

  const DebugSplashScreen({
    super.key,
    required this.initializationFuture,
  });

  @override
  State<DebugSplashScreen> createState() => _DebugSplashScreenState();
}

class _DebugSplashScreenState extends State<DebugSplashScreen> {
  String _status = 'Initializing...';
  String _error = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _status = 'Loading Firebase...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() => _status = 'Setting up Providers...');
      await widget.initializationFuture;
      
      setState(() => _status = 'Complete!');
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _status = 'ERROR!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _status,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _error,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (_initialized) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}
