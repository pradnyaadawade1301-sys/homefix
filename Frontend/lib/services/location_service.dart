import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';

/// Result from a full location resolution attempt.
class LocationResult {
  final double? latitude;
  final double? longitude;
  final LocationStatus status;
  final String? errorMessage;
  final String? address;
  final String? city;
  final String? state;
  // Sublocality-level precision (e.g. "Vashi") from the free `geocoding`
  // package — used for the header's "precise area" display instead of the
  // paid Google Places API, which may not be configured (see PlacesService).
  final String? area;

  LocationResult({
    this.latitude,
    this.longitude,
    required this.status,
    this.errorMessage,
    this.address,
    this.city,
    this.state,
    this.area,
  });

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasAddress => address != null && address!.isNotEmpty;

  @override
  String toString() {
    return 'LocationResult(lat: $latitude, lng: $longitude, '
        'status: $status, address: $address, city: $city, state: $state, '
        'area: $area, error: $errorMessage)';
  }
}

enum LocationStatus {
  granted,
  denied,
  deniedForever,
  restricted,
  gpsDisabled,
  timeout,
  networkError,
  unknownError,
}

/// Centralized location service wrapping the `location` and `geocoding`
/// packages with full error handling, permission management, GPS checks,
/// reverse geocoding, and detailed debug logging.
class LocationService {
  final loc.Location _location = loc.Location();

  /// Default timeout for location requests.
  static const Duration _locationTimeout = Duration(seconds: 30);

  /// Check and request location permission.
  /// Returns [LocationStatus.granted] if permission is obtained,
  /// otherwise the corresponding denied/restricted status.
  Future<LocationStatus> requestPermission() async {
    debugPrint('[LocationService] Checking location permission...');
    try {
      loc.PermissionStatus permission = await _location.hasPermission();
      debugPrint('[LocationService] Current permission status: $permission');

      if (permission == loc.PermissionStatus.granted) {
        debugPrint('[LocationService] Permission already granted.');
        return LocationStatus.granted;
      }

      if (permission == loc.PermissionStatus.deniedForever) {
        debugPrint('[LocationService] Permission denied forever â€” user must enable from system settings.');
        return LocationStatus.deniedForever;
      }

      // Request permission
      permission = await _location.requestPermission();
      debugPrint('[LocationService] Permission request result: $permission');

      switch (permission) {
        case loc.PermissionStatus.granted:
        case loc.PermissionStatus.grantedLimited:
          debugPrint('[LocationService] Permission granted after request.');
          return LocationStatus.granted;
        case loc.PermissionStatus.denied:
          debugPrint('[LocationService] Permission denied by user.');
          return LocationStatus.denied;
        case loc.PermissionStatus.deniedForever:
          debugPrint('[LocationService] Permission denied forever.');
          return LocationStatus.deniedForever;
      }
    } catch (e) {
      debugPrint('[LocationService] Error checking/requesting permission: $e');
      return LocationStatus.unknownError;
    }
  }

  /// Check if GPS / location services are enabled on the device.
  /// Returns `true` if enabled.
  Future<bool> isGpsEnabled() async {
    debugPrint('[LocationService] Checking GPS status...');
    try {
      final enabled = await _location.serviceEnabled();
      debugPrint('[LocationService] GPS enabled: $enabled');
      return enabled;
    } catch (e) {
      debugPrint('[LocationService] Error checking GPS: $e');
      return false;
    }
  }

  /// Request the user to enable GPS/location services.
  /// Returns `true` if GPS is enabled after the request.
  Future<bool> requestGpsEnabled() async {
    debugPrint('[LocationService] Requesting GPS to be enabled...');
    try {
      final enabled = await _location.requestService();
      debugPrint('[LocationService] GPS after request: $enabled');
      return enabled;
    } catch (e) {
      debugPrint('[LocationService] Error requesting GPS: $e');
      return false;
    }
  }

  /// Fetch the current device location with a timeout.
  /// Returns [loc.LocationData] on success, or `null` on failure.
  Future<loc.LocationData?> getCurrentLocation() async {
    debugPrint('[LocationService] Fetching current location...');
    try {
      final data = await _location.getLocation().timeout(_locationTimeout);
      debugPrint('[LocationService] Location received: lat=${data.latitude}, lng=${data.longitude}, '
          'accuracy=${data.accuracy}, altitude=${data.altitude}');
      return data;
    } on TimeoutException {
      debugPrint('[LocationService] Location request timed out after ${_locationTimeout.inSeconds}s.');
      return null;
    } catch (e) {
      debugPrint('[LocationService] Error getting location: $e');
      return null;
    }
  }

  /// Reverse geocode latitude/longitude into a human-readable address.
  /// Returns a map with [address], [city], [state], [area] keys — [area] is
  /// the sublocality (e.g. "Vashi"), the same level of precision the "Use
  /// current location" button in Saved Addresses already shows, sourced from
  /// the free `geocoding` package rather than the (possibly unconfigured)
  /// Google Places API.
  Future<Map<String, String>> reverseGeocode(double latitude, double longitude) async {
    debugPrint('[LocationService] Reverse geocoding: lat=$latitude, lng=$longitude');
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final address = [
          if (pm.subThoroughfare != null) pm.subThoroughfare,
          if (pm.thoroughfare != null) pm.thoroughfare,
          if (pm.subLocality != null) pm.subLocality,
          if (pm.locality != null) pm.locality,
          if (pm.administrativeArea != null) pm.administrativeArea,
          if (pm.postalCode != null) pm.postalCode,
          if (pm.country != null) pm.country,
        ].where((s) => s != null && s.isNotEmpty).cast<String>().join(', ');

        final city = pm.locality ?? pm.subAdministrativeArea ?? '';
        final state = pm.administrativeArea ?? '';
        final area = pm.subLocality ?? '';

        debugPrint('[LocationService] Reverse geocode result: address="$address", city="$city", '
            'state="$state", area="$area"');
        return {
          'address': address,
          'city': city,
          'state': state,
          'area': area,
        };
      }
      debugPrint('[LocationService] No placemarks found for coordinates.');
      return {'address': '', 'city': '', 'state': '', 'area': ''};
    } catch (e) {
      debugPrint('[LocationService] Reverse geocode error: $e');
      return {'address': '', 'city': '', 'state': '', 'area': ''};
    }
  }

  /// Attempts the full location resolution flow:
  /// 1. Request permission
  /// 2. Ensure GPS is enabled
  /// 3. Fetch current location
  /// 4. Reverse geocode to get address
  ///
  /// Returns a [LocationResult] with the outcome of each step.
  Future<LocationResult> resolveLocation() async {
    debugPrint('[LocationService] === Starting full location resolution ===');

    // Step 1: Permission
    final permStatus = await requestPermission();
    if (permStatus != LocationStatus.granted) {
      debugPrint('[LocationService] Location resolution failed at PERMISSION step: $permStatus');
      return LocationResult(status: permStatus, errorMessage: _permissionErrorMessage(permStatus));
    }

    // Step 2: GPS check
    bool gpsOn = await isGpsEnabled();
    if (!gpsOn) {
      debugPrint('[LocationService] GPS is disabled â€” requesting user to enable...');
      gpsOn = await requestGpsEnabled();
      if (!gpsOn) {
        debugPrint('[LocationService] Location resolution failed: GPS still disabled after request.');
        return LocationResult(
          status: LocationStatus.gpsDisabled,
          errorMessage: 'Location services are disabled. Please enable GPS to use location features.',
        );
      }
    }

    // Step 3: Get location
    final locationData = await getCurrentLocation();
    if (locationData == null || locationData.latitude == null || locationData.longitude == null) {
      debugPrint('[LocationService] Location resolution failed: could not get coordinates.');
      return LocationResult(
        status: LocationStatus.timeout,
        errorMessage: 'Could not determine your current location. Please try again.',
      );
    }

    final lat = locationData.latitude!;
    final lng = locationData.longitude!;

    // Step 4: Reverse geocode
    final geocodeResult = await reverseGeocode(lat, lng);

    debugPrint('[LocationService] === Location resolution complete ===');
    return LocationResult(
      latitude: lat,
      longitude: lng,
      status: LocationStatus.granted,
      address: geocodeResult['address'],
      city: geocodeResult['city'],
      state: geocodeResult['state'],
      area: geocodeResult['area'],
    );
  }

  /// Returns a user-friendly error message for a given [LocationStatus].
  static String _permissionErrorMessage(LocationStatus status) {
    switch (status) {
      case LocationStatus.denied:
        return 'Location permission is needed to find nearby technicians and show your address.';
      case LocationStatus.deniedForever:
        return 'Location permission is permanently denied. Please enable it in your device settings to use location features.';
      case LocationStatus.restricted:
        return 'Location access is restricted on this device.';
      default:
        return 'Could not access location services.';
    }
  }

  /// Returns a user-friendly error message for GPS/location failure.
  static String gpsDisabledMessage() {
    return 'GPS is disabled. Please enable location services to use this feature.';
  }
}