import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:relatoriooffline/services/location_service.dart';

class PhotoStampContext {
  const PhotoStampContext({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.endereco,
    required this.capturedAt,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? endereco;
  final DateTime capturedAt;
}

class PhotoStampService {
  PhotoStampService._();
  static final PhotoStampService instance = PhotoStampService._();

  static const String _logoAsset = 'lib/assets/logodc.png';
  static const Duration _geocodeTimeout = Duration(seconds: 2);

  ui.Image? _logoCache;

  Future<PhotoStampContext> buildContext({
    String? enderecoFormulario,
    double? latitude,
    double? longitude,
    double? precisaoGps,
  }) async {
    final capturedAt = DateTime.now();
    final enderecoForm = enderecoFormulario?.trim();
    final temEnderecoForm =
        enderecoForm != null && enderecoForm.isNotEmpty;

    double? lat = latitude;
    double? lng = longitude;
    double? accuracy = precisaoGps;

    if (lat == null || lng == null) {
      final position = await LocationService.instance.getPosition();
      lat = position?.latitude;
      lng = position?.longitude;
      accuracy = position?.accuracy;
    } else {
      LocationService.instance.rememberCoords(lat, lng, accuracy);
    }

    String? endereco = temEnderecoForm ? enderecoForm : null;
    if (!temEnderecoForm && lat != null && lng != null) {
      endereco = await _reverseGeocode(lat, lng)
          .timeout(_geocodeTimeout, onTimeout: () => null);
    }

    return PhotoStampContext(
      latitude: lat,
      longitude: lng,
      accuracyMeters: accuracy,
      endereco: endereco,
      capturedAt: capturedAt,
    );
  }

  Future<Uint8List> stamp(
    Uint8List photoBytes, {
    String? enderecoFormulario,
    double? latitude,
    double? longitude,
    double? precisaoGps,
  }) async {
    final ctxFuture = buildContext(
      enderecoFormulario: enderecoFormulario,
      latitude: latitude,
      longitude: longitude,
      precisaoGps: precisaoGps,
    );
    final logoFuture = _loadLogo();
    final ctx = await ctxFuture;
    await logoFuture;
    return apply(photoBytes, ctx);
  }

  Future<List<Uint8List>> stampAll(
    List<Uint8List> photos, {
    String? enderecoFormulario,
    double? latitude,
    double? longitude,
    double? precisaoGps,
  }) async {
    if (photos.isEmpty) return photos;
    final ctxFuture = buildContext(
      enderecoFormulario: enderecoFormulario,
      latitude: latitude,
      longitude: longitude,
      precisaoGps: precisaoGps,
    );
    final logoFuture = _loadLogo();
    final ctx = await ctxFuture;
    await logoFuture;
    final result = <Uint8List>[];
    for (final photo in photos) {
      result.add(await apply(photo, ctx));
    }
    return result;
  }

  Future<Uint8List> apply(Uint8List photoBytes, PhotoStampContext ctx) async {
    final photo = await _decodeImage(photoBytes);
    final logo = await _loadLogo();

    final width = photo.width.toDouble();
    final height = photo.height.toDouble();

    final lines = _buildLines(ctx);
    final bandHeight = _bandHeight(height, lines.length);
    final logoSize = (height * 0.09).clamp(36.0, 72.0);
    final padding = (height * 0.018).clamp(8.0, 16.0);
    final fontSize = (height * 0.028).clamp(12.0, 22.0);
    final textLeft = padding + logoSize + padding;
    final textWidth = width - textLeft - padding;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawImage(photo, ui.Offset.zero, ui.Paint());

    final bandTop = height - bandHeight;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, bandTop, width, bandHeight),
      ui.Paint()..color = const ui.Color(0xB3000000),
    );

    final logoSrc = ui.Rect.fromLTWH(
      0,
      0,
      logo.width.toDouble(),
      logo.height.toDouble(),
    );
    final logoDst = ui.Rect.fromLTWH(
      padding,
      bandTop + (bandHeight - logoSize) / 2,
      logoSize,
      logoSize,
    );
    canvas.drawImageRect(logo, logoSrc, logoDst, ui.Paint());

    var textY = bandTop + padding;
    for (final line in lines) {
      final paragraph = _buildParagraph(line, fontSize, textWidth);
      canvas.drawParagraph(paragraph, ui.Offset(textLeft, textY));
      textY += paragraph.height + 2;
    }

    final picture = recorder.endRecording();
    final stamped = await picture.toImage(photo.width, photo.height);
    photo.dispose();
    final byteData = await stamped.toByteData(format: ui.ImageByteFormat.png);
    stamped.dispose();

    if (byteData == null) return photoBytes;
    return byteData.buffer.asUint8List();
  }

  List<String> _buildLines(PhotoStampContext ctx) {
    final lines = <String>[];
    if (ctx.latitude != null && ctx.longitude != null) {
      lines.add(
        'Lat: ${ctx.latitude!.toStringAsFixed(6)}  '
        'Lng: ${ctx.longitude!.toStringAsFixed(6)}',
      );
      if (ctx.accuracyMeters != null) {
        lines.add('Precisão: ${ctx.accuracyMeters!.toStringAsFixed(1)} m');
      }
    } else {
      lines.add('GPS indisponível');
    }

    final endereco = ctx.endereco?.trim();
    if (endereco != null && endereco.isNotEmpty) {
      lines.add(endereco);
    }

    lines.add(DateFormat('dd/MM/yyyy HH:mm:ss').format(ctx.capturedAt));
    return lines;
  }

  double _bandHeight(double imageHeight, int lineCount) {
    final fontSize = (imageHeight * 0.028).clamp(12.0, 22.0);
    final padding = (imageHeight * 0.018).clamp(8.0, 16.0);
    final logoSize = (imageHeight * 0.09).clamp(36.0, 72.0);
    final textBlock = lineCount * (fontSize + 4) + padding * 2;
    return textBlock > logoSize + padding * 2
        ? textBlock
        : logoSize + padding * 2;
  }

  ui.Paragraph _buildParagraph(String text, double fontSize, double maxWidth) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.left,
        fontSize: fontSize,
        maxLines: 2,
        ellipsis: '…',
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: const ui.Color(0xFFFFFFFF),
          fontSize: fontSize,
          fontWeight: ui.FontWeight.w600,
        ),
      )
      ..addText(text);
    return builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final geocoding = Geocoding();
      if (!await geocoding.isPresent()) return null;
      final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      return _formatPlacemark(placemarks.first);
    } catch (_) {
      return null;
    }
  }

  String? _formatPlacemark(Placemark p) {
    final street = [
      if ((p.thoroughfare ?? '').trim().isNotEmpty) p.thoroughfare!.trim(),
      if ((p.subThoroughfare ?? '').trim().isNotEmpty) p.subThoroughfare!.trim(),
    ].join(', ');

    final parts = <String>[
      if (street.isNotEmpty) street,
      if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
      if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
      if ((p.administrativeArea ?? '').trim().isNotEmpty)
        p.administrativeArea!.trim(),
    ];

    if (parts.isEmpty) return null;
    return parts.join(' - ');
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<ui.Image> _loadLogo() async {
    if (_logoCache != null) return _logoCache!;
    final data = await rootBundle.load(_logoAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _logoCache = frame.image;
    return _logoCache!;
  }
}
