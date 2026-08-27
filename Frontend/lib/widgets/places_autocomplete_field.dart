import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/places_service.dart';

/// A text field that shows live Google Places suggestions as the user types,
/// and returns full [PlaceDetails] (line1/city/state/pincode/lat/lng) once
/// they pick one — so the rest of the address form can be auto-filled
/// instead of typed by hand.
class PlacesAutocompleteField extends StatefulWidget {
  final String labelText;
  final String hintText;
  final ValueChanged<PlaceDetails> onPlaceSelected;

  const PlacesAutocompleteField({
    super.key,
    this.labelText = 'Search your address',
    this.hintText = 'Start typing your building, street or area…',
    required this.onPlaceSelected,
  });

  @override
  State<PlacesAutocompleteField> createState() => _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  final _placesService = PlacesService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _loading = false;
  bool _resolving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loading = true);
      final results = await _placesService.autocomplete(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() {
      _suggestions = [];
      _controller.text = suggestion.fullDescription;
      _resolving = true;
    });
    final details = await _placesService.getPlaceDetails(suggestion.placeId);
    if (!mounted) return;
    setState(() => _resolving = false);
    if (details != null) {
      widget.onPlaceSelected(details);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch that address. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_placesService.isConfigured) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'Google Places API key not configured (lib/config/api_config.dart). '
          'Address search is disabled — fill the fields manually below.',
          style: TextStyle(fontSize: 12.5, color: Colors.orange),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: (_loading || _resolving)
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
              itemBuilder: (context, i) {
                final s = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined, color: AppTheme.primaryColor),
                  title: Text(s.mainText, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: s.secondaryText.isNotEmpty
                      ? Text(s.secondaryText, style: TextStyle(fontSize: 12.5, color: Colors.grey[600]))
                      : null,
                  onTap: () => _selectSuggestion(s),
                );
              },
            ),
          ),
      ],
    );
  }
}