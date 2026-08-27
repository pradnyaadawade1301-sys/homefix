import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';

/// Provides the user's current location state to the entire app.
///
/// Handles permission requests, GPS enablement, location fetching, and
/// reverse geocoding in a single, centralized provider. Screens that need
/// location data consume this provider instead of creating their own
/// [loc.Location] instances.
class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;

  /// Current resolved location result (null until first resolution).
  LocationResult? _locationResult;

  /// More specific area/sublocality from Google Places reverse geocoding
  /// (e.g. "Sector 15, Vashi") — used in place of the generic city/state
  /// display when available, matching the precision Saved Addresses already
  /// gets via PlacesService.
  String? _preciseArea;

  /// Whether a location resolution is currently in progress.
  bool _isResolving = false;

  /// Whether a resolution has been attempted at least once.
  bool _hasAttempted = false;

  /// Last error message from a failed resolution.
  String? _lastError;

  LocationProvider({required LocationService locationService})
      : _locationService = locationService;

  // --- Getters ---

  LocationResult? get locationResult => _locationResult;
  bool get isResolving => _isResolving;
  bool get hasAttempted => _hasAttempted;
  String? get lastError => _lastError;

  double? get latitude => _locationResult?.latitude;
  double? get longitude => _locationResult?.longitude;
  bool get hasLocation => _locationResult?.hasLocation ?? false;
  bool get hasAddress => _locationResult?.hasAddress ?? false;

  /// Human-readable address string (full address).
  String? get address => _locationResult?.address;

  /// City name from reverse geocoding.
  String? get city => _locationResult?.city;

  /// State name from reverse geocoding.
  String? get state => _locationResult?.state;

  /// Short display: precise area (from Google Places) if available, otherwise
  /// "City, State", otherwise "Set your location".
  String get displayCityState {
    if (_preciseArea != null && _preciseArea!.isNotEmpty) {
      return _preciseArea!;
    }
    if (_locationResult?.city != null && _locationResult!.city!.isNotEmpty) {
      if (_locationResult?.state != null && _locationResult!.state!.isNotEmpty) {
        return '${_locationResult!.city!}, ${_locationResult!.state!}';
      }
      return _locationResult!.city!;
    }
    return 'Set your location';
  }

  /// Short display: "City" if available, otherwise full address or fallback.
  String get displayCity {
    if (_locationResult?.city != null && _locationResult!.city!.isNotEmpty) {
      return _locationResult!.city!;
    }
    if (_locationResult?.address != null && _locationResult!.address!.isNotEmpty) {
      return _locationResult!.address!;
    }
    return 'Set your location';
  }

  /// The last known location status (permission, GPS, etc.)
  LocationStatus? get status => _locationResult?.status;

  // --- Public Methods ---

  /// Full location resolution: permission -> GPS -> location -> geocode.
  /// Call this on app start or when you need a fresh location.
  Future<void> resolveLocation() async {
    if (_isResolving) return; // Prevent concurrent resolutions

    _isResolving = true;
    _hasAttempted = true;
    _lastError = null;
    notifyListeners();

    try {
      debugPrint('[LocationProvider] Resolving location...');
      _locationResult = await _locationService.resolveLocation();
      debugPrint('[LocationProvider] Location result: ${_locationResult.toString()}');

      if (!hasLocation) {
        _lastError = _locationResult?.errorMessage ?? 'Could not determine your location.';
        debugPrint('[LocationProvider] Location resolution failed: $_lastError');
      } else {
        // Try to get a more precise area (sublocality/society level) via
        // Google Places, same as Saved Addresses does — falls back silently
        // to the plain city/state from LocationService if not configured or
        // if the request fails.
        _preciseArea = null;
        try {
          final placesService = PlacesService();
          if (placesService.isConfigured) {
            final details = await placesService.reverseGeocode(latitude!, longitude!);
            if (details != null && details.line1.isNotEmpty) {
              _preciseArea = details.line1;
              debugPrint('[LocationProvider] Precise area: $_preciseArea');
            }
          }
        } catch (e) {
          debugPrint('[LocationProvider] Precise area lookup failed (non-fatal): $e');
        }
      }
    } catch (e) {
      debugPrint('[LocationProvider] Unexpected error during location resolution: $e');
      _lastError = 'An unexpected error occurred while fetching your location.';
      _locationResult = LocationResult(
        status: LocationStatus.unknownError,
        errorMessage: _lastError,
      );
    } finally {
      _isResolving = false;
      notifyListeners();
    }
  }

  /// Retry location resolution (useful after granting permission or enabling GPS).
  Future<void> retry() => resolveLocation();

  /// Request location permission only (does not fetch GPS or geocode).
  /// Call this when the user taps "Enable Location" from a prompt.
  Future<LocationStatus> requestPermissionOnly() async {
    try {
      final status = await _locationService.requestPermission();
      if (status == LocationStatus.granted) {
        // If permission was just granted, attempt full resolution
        await resolveLocation();
      }
      return status;
    } catch (e) {
      debugPrint('[LocationProvider] Permission request error: $e');
      return LocationStatus.unknownError;
    }
  }

  /// Request GPS to be enabled.
  /// Returns `true` if GPS is now enabled.
  Future<bool> requestGpsEnabled() async {
    try {
      final enabled = await _locationService.requestGpsEnabled();
      if (enabled) {
        // GPS just enabled — full resolution
        await resolveLocation();
      }
      return enabled;
    } catch (e) {
      debugPrint('[LocationProvider] GPS request error: $e');
      return false;
    }
  }

  /// Refresh the current location (update coordinates and address).
  /// Useful when the user explicitly asks to refresh.
  Future<void> refreshLocation() async {
    debugPrint('[LocationProvider] Refreshing location...');
    await resolveLocation();
  }

  /// Clear any cached error state.
  void clearError() {
    _lastError = null;
    notifyListeners();
  }
}