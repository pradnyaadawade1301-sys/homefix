import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/service_locator.dart';

class AddressProvider extends ChangeNotifier {
  final AddressService _addressService;

  List<Address> _addresses = [];
  bool _isLoading = false;
  String? _error;

  AddressProvider({required AddressService addressService}) : _addressService = addressService;

  List<Address> get addresses => _addresses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAddresses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _addresses = await _addressService.listAddresses();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Address> addAddress({
    required String label,
    required String line1,
    String? line2,
    required String city,
    required String state,
    required String pincode,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final addr = await _addressService.addAddress(
      label: label,
      line1: line1,
      line2: line2,
      city: city,
      state: state,
      pincode: pincode,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
    );
    _addresses.add(addr);
    notifyListeners();
    return addr;
  }
}