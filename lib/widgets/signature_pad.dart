import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SignaturePad extends StatefulWidget {
  final Function(Uint8List) onSignatureGenerated;

  const SignaturePad({
    super.key,
    required this.onSignatureGenerated,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  late List<Offset?> _points;
  bool _isEmpty = true;
  static const double canvasWidth = 500;
  static const double canvasHeight = 350;

  double _getCanvasHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - 150;
    return availableHeight > canvasHeight ? canvasHeight : availableHeight * 0.7;
  }

  double _getCanvasWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth - 32;
    return maxWidth > canvasWidth ? canvasWidth : maxWidth;
  }

  @override
  void initState() {
    super.initState();
    _points = [];
  }

  void _clearSignature() {
    setState(() {
      _points.clear();
      _isEmpty = true;
    });
  }

  bool _isPointInBounds(Offset point, Size canvasSize) {
    return point.dx >= 0 &&
        point.dx <= canvasSize.width &&
        point.dy >= 0 &&
        point.dy <= canvasSize.height;
  }

  Future<void> _saveSignature() async {
    if (_isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, desenhe uma assinatura')),
      );
      return;
    }

    final canvasWidth = _getCanvasWidth(context);
    final canvasHeight = _getCanvasHeight(context);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(canvasWidth, canvasHeight);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != null && _points[i + 1] != null) {
        canvas.drawLine(_points[i]!, _points[i + 1]!, paint);
      } else if (_points[i] != null && _points[i + 1] == null) {
        canvas.drawPoints(ui.PointMode.points, [_points[i]!], paint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    if (mounted) {
      widget.onSignatureGenerated(pngBytes);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvasWidth = _getCanvasWidth(context);
    final canvasHeight = _getCanvasHeight(context);
    final canvasSize = Size(canvasWidth, canvasHeight);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Desenhe sua assinatura',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            GestureDetector(
              onPanStart: (details) {
                if (_isPointInBounds(details.localPosition, canvasSize)) {
                  _points.add(details.localPosition);
                }
              },
              onPanUpdate: (details) {
                if (_isPointInBounds(details.localPosition, canvasSize)) {
                  setState(() {
                    _points.add(details.localPosition);
                    _isEmpty = false;
                  });
                }
              },
              onPanEnd: (details) {
                _points.add(null);
              },
              child: CustomPaint(
                painter: _SignaturePainter(_points),
                size: canvasSize,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _clearSignature,
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saveSignature,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3F7A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = Colors.grey[400]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(ui.PointMode.points, [points[i]!], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}

