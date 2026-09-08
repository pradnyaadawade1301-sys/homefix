import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../config/api_config.dart';

/// A single suggestion returned by Google's Places Autocomplete API.
class PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullDescription;

  PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullDescription,
  });
}

/// Full address details resolved from a place (or from reverse geocoding a
/// lat/lng), broken down into the fields the app's Address model needs.
class PlaceDetails {
  final String line1;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;
  final String formattedAddress;

  PlaceDetails({
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
  });
}

/// Wraps Google's Places Autocomplete, Place Details, and Geocoding REST APIs.
///
/// Requires [ApiConfig.googlePlacesApiKey] to be set to a valid key with
/// "Places API" and "Geocoding API" enabled in Google Cloud Console.
class PlacesService {
  static const String _autocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';
  static const String _geocodeUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  final Dio _dio = Dio();
  final Uuid _uuid = const Uuid();

  /// Google bills autocomplete sessions as one unit if you pass the same
  /// sessiontoken across the autocomplete calls + the final details call.
  /// Call [newSession] once when the user starts typing in a fresh field.
  String? _sessionToken;

  void newSession() {
    _sessionToken = _uuid.v4();
  }

  bool get isConfigured =>
      ApiConfig.googlePlacesApiKey.isNotEmpty &&
      ApiConfig.googlePlacesApiKey != 'PASTE_YOUR_GOOGLE_PLACES_API_KEY_HERE';

  /// Returns autocomplete suggestions for [input]. Biased towards India.
  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (input.trim().isEmpty) return [];
    _sessionToken ??= _uuid.v4();
    try {
      final response = await _dio.get(_autocompleteUrl, queryParameters: {
        'input': input,
        'key': ApiConfig.googlePlacesApiKey,
        'sessiontoken': _sessionToken,
        'components': 'country:in',
        'language': 'en',
      });
      final data = response.data;
      if (data['status'] != 'OK') {
        debugPrint('[PlacesService] autocomplete status: ${data['status']} ${data['error_message'] ?? ''}');
        return [];
      }
      final predictions = data['predictions'] as List;
      return predictions.map((p) {
        final structured = p['structured_formatting'] ?? {};
        return PlaceSuggestion(
          placeId: p['place_id'] as String,
          mainText: (structured['main_text'] as String?) ?? p['description'] as String,
          secondaryText: (structured['secondary_text'] as String?) ?? '',
          fullDescription: p['description'] as String,
        );
      }).toList();
    } catch (e) {
      debugPrint('[PlacesService] autocomplete error: $e');
      return [];
    }
  }

  /// Resolves a [placeId] (from [autocomplete]) into full address details.
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final response = await _dio.get(_detailsUrl, queryParameters: {
        'place_id': placeId,
        'key': ApiConfig.googlePlacesApiKey,
        'sessiontoken': _sessionToken,
        'fields': 'address_component,formatted_address,geometry',
      });
      // Session is done once details are fetched — next search starts a new one.
      _sessionToken = null;
      final data = response.data;
      if (data['status'] != 'OK') {
        debugPrint('[PlacesService] details status: ${data['status']} ${data['error_message'] ?? ''}');
        return null;
      }
      return _parseComponents(data['result']);
    } catch (e) {
      debugPrint('[PlacesService] details error: $e');
      return null;
    }
  }

  /// Reverse geocodes a lat/lng (e.g. from device GPS) into address details.
  Future<PlaceDetails?> reverseGeocode(double latitude, double longitude) async {
    try {
      final response = await _dio.get(_geocodeUrl, queryParameters: {
        'latlng': '$latitude,$longitude',
        'key': ApiConfig.googlePlacesApiKey,
        'language': 'en',
      });
      final data = response.data;
      if (data['status'] != 'OK') {
        debugPrint('[PlacesService] reverseGeocode status: ${data['status']} ${data['error_message'] ?? ''}');
        return null;
      }
      final results = data['results'] as List;
      if (results.isEmpty) return null;
      return _parseComponents(results.first, fallbackLat: latitude, fallbackLng: longitude);
    } catch (e) {
      debugPrint('[PlacesService] reverseGeocode error: $e');
      return null;
    }
  }

  PlaceDetails _parseComponents(Map<String, dynamic> result, {double? fallbackLat, double? fallbackLng}) {
    final components = result['address_components'] as List? ?? [];
    String get(List<String> types) {
      for (final c in components) {
        final cTypes = (c['types'] as List).cast<String>();
        if (types.any(cTypes.contains)) return c['long_name'] as String;
      }
      return '';
    }

    final streetNumber = get(['street_number']);
    final route = get(['route']);
    final sublocality = get(['sublocality', 'sublocality_level_1', 'neighborhood']);
    final line1Parts = [streetNumber, route, sublocality].where((s) => s.isNotEmpty).join(', ');

    final city = get(['locality', 'administrative_area_level_2', 'postal_town']);
    final state = get(['administrative_area_level_1']);
    final pincode = get(['postal_code']);

    final geometry = result['geometry']?['location'];
    final lat = (geometry?['lat'] as num?)?.toDouble() ?? fallbackLat ?? 0.0;
    final lng = (geometry?['lng'] as num?)?.toDouble() ?? fallbackLng ?? 0.0;

    return PlaceDetails(
      line1: line1Parts.isNotEmpty ? line1Parts : (result['formatted_address'] as String? ?? ''),
      city: city,
      state: state,
      pincode: pincode,
      latitude: lat,
      longitude: lng,
      formattedAddress: result['formatted_address'] as String? ?? '',
    );
  }
}