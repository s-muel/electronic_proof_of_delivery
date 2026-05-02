import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NetworkStatusBar extends StatefulWidget {
  const NetworkStatusBar({super.key});

  @override
  State<NetworkStatusBar> createState() => _NetworkStatusBarState();
}

class _NetworkStatusBarState extends State<NetworkStatusBar> {
  Timer? _timer;
  bool? _isOnline;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkConnection(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);

    try {
      final response = await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 4));

      if (!mounted) return;

      setState(() {
        _isOnline = response.statusCode >= 200 && response.statusCode < 400;
        _isChecking = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isOnline = false;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _isOnline;
    final isConnected = isOnline == true;
    final color = isConnected ? Colors.green : Colors.red;
    final icon = isConnected ? Icons.cloud_done : Icons.cloud_off;
    final title = isConnected ? 'Internet connected' : 'No internet connection';
    final subtitle = isConnected
        ? 'Online sync and Cloudinary uploads are available.'
        : 'Deliveries will be saved offline and synced when internet returns.';

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (_isChecking && isOnline == null)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isChecking && isOnline == null
                        ? 'Checking internet connection...'
                        : title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isChecking && isOnline == null
                        ? 'Please wait while the app checks network access.'
                        : subtitle,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _isChecking ? null : _checkConnection,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Check'),
            ),
          ],
        ),
      ),
    );
  }
}
