import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const Duration cacheTtl = Duration(seconds: 60);
  static const Duration firstFixWait = Duration(seconds: 5);
  static const Duration streamMaxRuntime = Duration(seconds: 60);
  static const double maxAcceptableAccuracyMeters = 25;

  final StreamController<Position> _updatesController =
      StreamController<Position>.broadcast();

  Stream<Position> get updates => _updatesController.stream;

  Position? _cachedPosition;
  DateTime? _cachedPositionAt;
  StreamSubscription<Position>? _subscription;
  Timer? _stopTimer;

  Position? get lastPosition => _cachedPosition;

  Future<Position?> getPosition({bool requestPermissionIfNeeded = true}) async {
    final cached = _cachedPosition;
    final cachedAt = _cachedPositionAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < cacheTtl &&
        _isAcceptable(cached)) {
      return cached;
    }

    if (!await _hasPermission(requestPermissionIfNeeded)) return null;

    _ensureStreamRunning();

    try {
      return await updates
          .firstWhere(_isAcceptable)
          .timeout(firstFixWait);
    } on TimeoutException {
    } catch (_) {
    }

    if (_cachedPosition != null) return _cachedPosition;
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  void _ensureStreamRunning() {
    if (_subscription != null) return;

    _subscription = Geolocator.getPositionStream(
      locationSettings: _streamSettings(),
    ).listen(
      (position) {
        _rememberIfBetter(position);
        _updatesController.add(position);
        if (_isAcceptable(position)) {
          _stopStream();
        }
      },
      onError: (_) => _stopStream(),
    );
    _stopTimer = Timer(streamMaxRuntime, _stopStream);
  }

  void _stopStream() {
    _subscription?.cancel();
    _subscription = null;
    _stopTimer?.cancel();
    _stopTimer = null;
  }

  LocationSettings _streamSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.other,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );
  }

  Future<bool> _hasPermission(bool requestIfNeeded) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (!requestIfNeeded) return false;
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  void _rememberIfBetter(Position position) {
    final cached = _cachedPosition;
    if (cached != null &&
        _isAcceptable(cached) &&
        !_isAcceptable(position) &&
        _cachedPositionAt != null &&
        DateTime.now().difference(_cachedPositionAt!) < cacheTtl) {
      return;
    }
    remember(position);
  }

  bool _isAcceptable(Position position) {
    if (position.accuracy <= 0) return false;
    return position.accuracy <= maxAcceptableAccuracyMeters;
  }

  void remember(Position position) {
    _cachedPosition = position;
    _cachedPositionAt = DateTime.now();
  }

  void rememberCoords(double lat, double lng, double? accuracy) {
    final cached = _cachedPosition;
    if (cached != null &&
        _isAcceptable(cached) &&
        _cachedPositionAt != null &&
        DateTime.now().difference(_cachedPositionAt!) < cacheTtl) {
      return;
    }
    remember(
      Position(
        longitude: lng,
        latitude: lat,
        timestamp: DateTime.now(),
        accuracy: accuracy ?? 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
  }
}
