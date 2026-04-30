import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignatureCaptureScreen extends StatefulWidget {
  final String title;

  const SignatureCaptureScreen({
    super.key,
    required this.title,
  });

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  late final SignatureController _signatureController;

  @override
  void initState() {
    super.initState();

    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> saveSignature() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign before saving'),
        ),
      );
      return;
    }

    final Uint8List? signatureBytes =
        await _signatureController.toPngBytes();

    if (signatureBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save signature. Please try again.'),
        ),
      );
      return;
    }

    Navigator.pop(context, signatureBytes);
  }

  void clearSignature() {
    _signatureController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton.icon(
            onPressed: clearSignature,
            icon: const Icon(Icons.clear, color: Colors.red),
            label: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Container(
          width: isWideScreen ? 650 : double.infinity,
          margin: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Text(
                'Sign inside the box below',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1.5),
                    color: Colors.white,
                  ),
                  child: Signature(
                    controller: _signatureController,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: saveSignature,
                  icon: const Icon(Icons.check),
                  label: const Text('Save Signature'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}