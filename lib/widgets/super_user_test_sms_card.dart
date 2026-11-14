import 'dart:math';

import 'package:flutter/material.dart';

import '../services/driver_sms_service.dart';

class SuperUserTestSmsCard extends StatefulWidget {
  const SuperUserTestSmsCard({super.key});

  @override
  State<SuperUserTestSmsCard> createState() => _SuperUserTestSmsCardState();
}

class _SuperUserTestSmsCardState extends State<SuperUserTestSmsCard> {
  final _phone = TextEditingController();
  final _message = TextEditingController();
  Map<String, String>? _pending;
  bool _sending = false;
  String? _result;

  @override
  void dispose() {
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final phone = _phone.text.trim();
    final message = _message.text.trim();
    if (phone.isEmpty || message.isEmpty || message.length > 480) return;
    final rng = Random.secure();
    setState(() {
      _sending = true;
      _result = null;
      _pending ??= {
        'testSms': 'true',
        'requestId': List.generate(
          16,
          (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
        'phone': phone,
        'message': message,
      };
    });
    try {
      final response = await DriverSmsService.request(data: _pending!);
      if (!mounted) return;
      final record = response['record'] as Map<String, dynamic>;
      setState(() {
        _pending = null;
        _result = record['detail']?.toString().trim();
        if (_result == null || _result!.isEmpty) {
          _result = 'Attempt recorded. Check Arkesel before resending.';
        }
        final id = record['providerId']?.toString() ?? '';
        if (id.isNotEmpty) _result = '$_result\nArkesel message ID: $id';
        if ([
          'accepted',
          'preview',
          'unknown',
          'pending',
        ].contains(record['status'])) {
          _message.clear();
        }
      });
    } on SmsRejected catch (error) {
      if (!mounted) return;
      setState(() {
        _pending = null;
        _result = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final detail = error is StateError ? '${error.message}\n' : '';
        _result =
            '${detail}Could not confirm the result. Retry the same attempt to avoid a duplicate.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _sending || _pending != null;
    final ready =
        !_sending &&
        _phone.text.trim().isNotEmpty &&
        _message.text.trim().isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Test SMS', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Send a test text to a number you control.'),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              enabled: !locked,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Test phone number',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              enabled: !locked,
              minLines: 2,
              maxLines: null,
              maxLength: 480,
              decoration: const InputDecoration(
                labelText: 'Test message',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: ready ? _send : null,
                icon: const Icon(Icons.sms_outlined),
                label: Text(
                  _sending
                      ? 'Sending…'
                      : _pending != null
                      ? 'Retry same attempt'
                      : 'Send test SMS',
                ),
              ),
            ),
            if (_result != null) SelectableText(_result!),
          ],
        ),
      ),
    );
  }
}
