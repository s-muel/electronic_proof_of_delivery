import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class StampCaptureScreen extends StatefulWidget {
  const StampCaptureScreen({super.key});

  @override
  State<StampCaptureScreen> createState() => _StampCaptureScreenState();
}

class _StampCaptureScreenState extends State<StampCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _originalStampBytes;
  Uint8List? _processedStampBytes;
  bool _isProcessing = false;
  double? _originalAspectRatio;
  Rect _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
  Offset? _lastCropDragPosition;
  String _cropDragMode = 'move';

  Future<void> _pickStamp(ImageSource source) async {
    setState(() => _isProcessing = true);

    try {
      final pickedImage = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (pickedImage == null) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final originalBytes = await pickedImage.readAsBytes();
      final originalImage = img.decodeImage(originalBytes);
      final processedBytes = _cropStamp(originalBytes);

      if (!mounted) return;

      if (processedBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not process this stamp photo.')),
        );
      } else {
        setState(() {
          _originalStampBytes = originalBytes;
          _processedStampBytes = processedBytes;
          _originalAspectRatio = originalImage == null
              ? null
              : originalImage.width / originalImage.height;
          _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
        });
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not process the stamp image.')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reprocessStamp() async {
    final originalBytes = _originalStampBytes;
    if (originalBytes == null || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final processedBytes = _cropStamp(originalBytes);

      if (!mounted) return;

      if (processedBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not process this crop area.')),
        );
      } else {
        setState(() => _processedStampBytes = processedBytes);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Uint8List? _cropStamp(Uint8List sourceBytes) {
    final sourceImage = img.decodeImage(sourceBytes);
    if (sourceImage == null) return null;

    final croppedSource = _cropOriginalImage(sourceImage);

    final resized = croppedSource.width > 700 || croppedSource.height > 700
        ? img.copyResize(
            croppedSource,
            width: croppedSource.width >= croppedSource.height ? 700 : null,
            height: croppedSource.height > croppedSource.width ? 700 : null,
          )
        : croppedSource;

    return Uint8List.fromList(img.encodeJpg(resized, quality: 72));
  }

  img.Image _cropOriginalImage(img.Image sourceImage) {
    final leftPixels = (sourceImage.width * _cropRect.left).round();
    final topPixels = (sourceImage.height * _cropRect.top).round();
    final rightPixels = (sourceImage.width * _cropRect.right).round();
    final bottomPixels = (sourceImage.height * _cropRect.bottom).round();
    final width = rightPixels - leftPixels;
    final height = bottomPixels - topPixels;

    if (width < 20 || height < 20) {
      return sourceImage;
    }

    return img.copyCrop(
      sourceImage,
      x: leftPixels,
      y: topPixels,
      width: width,
      height: height,
    );
  }

  void _resetCrop() {
    setState(() => _cropRect = const Rect.fromLTWH(0, 0, 1, 1));
    _reprocessStamp();
  }

  void _startCropDrag(DragStartDetails details, Size size) {
    _lastCropDragPosition = details.localPosition;
    _cropDragMode = _detectCropDragMode(details.localPosition, size);
  }

  void _updateCropDrag(DragUpdateDetails details, Size size) {
    final previousPosition = _lastCropDragPosition;
    if (previousPosition == null || size.width == 0 || size.height == 0) {
      return;
    }

    final delta = details.localPosition - previousPosition;
    _lastCropDragPosition = details.localPosition;

    final dx = delta.dx / size.width;
    final dy = delta.dy / size.height;
    const minSize = 0.12;

    var left = _cropRect.left;
    var top = _cropRect.top;
    var right = _cropRect.right;
    var bottom = _cropRect.bottom;

    switch (_cropDragMode) {
      case 'topLeft':
        left = (left + dx).clamp(0.0, right - minSize);
        top = (top + dy).clamp(0.0, bottom - minSize);
        break;
      case 'topRight':
        right = (right + dx).clamp(left + minSize, 1.0);
        top = (top + dy).clamp(0.0, bottom - minSize);
        break;
      case 'bottomLeft':
        left = (left + dx).clamp(0.0, right - minSize);
        bottom = (bottom + dy).clamp(top + minSize, 1.0);
        break;
      case 'bottomRight':
        right = (right + dx).clamp(left + minSize, 1.0);
        bottom = (bottom + dy).clamp(top + minSize, 1.0);
        break;
      default:
        final width = right - left;
        final height = bottom - top;
        left = (left + dx).clamp(0.0, 1.0 - width);
        top = (top + dy).clamp(0.0, 1.0 - height);
        right = left + width;
        bottom = top + height;
    }

    setState(() => _cropRect = Rect.fromLTRB(left, top, right, bottom));
  }

  void _endCropDrag(DragEndDetails _) {
    _lastCropDragPosition = null;
    _reprocessStamp();
  }

  String _detectCropDragMode(Offset position, Size size) {
    final rect = Rect.fromLTRB(
      _cropRect.left * size.width,
      _cropRect.top * size.height,
      _cropRect.right * size.width,
      _cropRect.bottom * size.height,
    );
    const handleRadius = 34.0;

    if ((position - rect.topLeft).distance <= handleRadius) return 'topLeft';
    if ((position - rect.topRight).distance <= handleRadius) return 'topRight';
    if ((position - rect.bottomLeft).distance <= handleRadius) {
      return 'bottomLeft';
    }
    if ((position - rect.bottomRight).distance <= handleRadius) {
      return 'bottomRight';
    }

    return 'move';
  }

  void _useStamp() {
    final stampBytes = _processedStampBytes;
    if (stampBytes == null) return;
    Navigator.pop(context, stampBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Receiver Stamp',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF4F7FB),
        foregroundColor: const Color(0xFF172033),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDDE8F6)),
              ),
              child: const Text(
                'Take a clear photo of the client stamp, crop the stamp area, then save it on the waybill.',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFDDE8F6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.crop, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Crop stamp photo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isProcessing ? null : _resetCrop,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCropEditor(),
                  const Text(
                    'Drag inside the box to move it. Drag the corners to resize it, then release to preview.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFDDE8F6)),
                ),
                child: Center(
                  child: _isProcessing
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Cropping stamp...'),
                          ],
                        )
                      : _processedStampBytes == null
                      ? const Text(
                          'No stamp captured yet',
                          style: TextStyle(color: Colors.black54),
                        )
                      : Image.memory(
                          _processedStampBytes!,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _pickStamp(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose Photo'),
                ),
                FilledButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _pickStamp(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
                FilledButton.icon(
                  onPressed: _processedStampBytes == null || _isProcessing
                      ? null
                      : _useStamp,
                  icon: const Icon(Icons.check),
                  label: const Text('Use Stamp'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropEditor() {
    final originalBytes = _originalStampBytes;
    final aspectRatio = _originalAspectRatio;

    if (originalBytes == null || aspectRatio == null) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Capture or choose a stamp photo to crop it here.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = MediaQuery.of(context).size.height * 0.32;
        var width = constraints.maxWidth;
        var height = width / aspectRatio;

        if (height > maxHeight) {
          height = maxHeight;
          width = height * aspectRatio;
        }

        final cropBox = Size(width, height);

        return Center(
          child: SizedBox(
            width: cropBox.width,
            height: cropBox.height,
            child: GestureDetector(
              onPanStart: _isProcessing
                  ? null
                  : (details) => _startCropDrag(details, cropBox),
              onPanUpdate: _isProcessing
                  ? null
                  : (details) => _updateCropDrag(details, cropBox),
              onPanEnd: _isProcessing ? null : _endCropDrag,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(originalBytes, fit: BoxFit.fill),
                  ),
                  CustomPaint(painter: _CropOverlayPainter(_cropRect)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  const _CropOverlayPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      cropRect.left * size.width,
      cropRect.top * size.height,
      cropRect.right * size.width,
      cropRect.bottom * size.height,
    );

    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final cropPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(cropPath, overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      borderPaint,
    );

    final handlePaint = Paint()..color = Colors.white;
    final handleBorderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final point in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawCircle(point, 8, handlePaint);
      canvas.drawCircle(point, 8, handleBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
