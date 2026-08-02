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
  final List<Offset?> _points = [];
  bool _isEmpty = true;
  Size _lastCanvasSize = Size.zero;

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

    final size = _lastCanvasSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
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
    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : media.size.width - 16;
          final maxHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : media.size.height - 16;

          return SizedBox(
            width: maxWidth,
            height: maxHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Desenhe sua assinatura',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        tooltip: 'Fechar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, canvasConstraints) {
                        final canvasSize = Size(
                          canvasConstraints.maxWidth,
                          canvasConstraints.maxHeight,
                        );
                        _lastCanvasSize = canvasSize;
                        return GestureDetector(
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
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade400, width: 1.5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CustomPaint(
                              painter: _SignaturePainter(_points),
                              size: canvasSize,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearSignature,
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveSignature,
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3A3F7A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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

    final guideY = size.height * 0.72;
    canvas.drawLine(
      Offset(size.width * 0.06, guideY),
      Offset(size.width * 0.94, guideY),
      Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = 1,
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
