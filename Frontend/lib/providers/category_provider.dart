import 'dart:io';
import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import '../services/service_locator.dart';
import '../utils/working_hours.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryService _categoryService;

  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  CategoryProvider({required CategoryService categoryService}) : _categoryService = categoryService;

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _categoryService.getCategories();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('CategoryProvider.fetchCategories error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// Technician Provider
class TechnicianProvider extends ChangeNotifier {
  final TechnicianService _technicianService;

  List<Technician> _technicians = [];
  bool _isLoading = false;
  String? _error;

  TechnicianProvider({required TechnicianService technicianService})
      : _technicianService = technicianService;

  List<Technician> get technicians => _technicians;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchTechnicians({String? categoryId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _technicians = await _technicianService.getTechnicians(categoryId: categoryId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('TechnicianProvider.fetchTechnicians error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // NOTE: technician text-search isn't implemented on the backend yet (Day 2 scope).
  // The home screen's search bar currently filters the already-fetched `technicians`
  // list client-side instead of calling this.
}

// Nearby Technician Provider — drives the nearby-technicians map/tracking screen.
class NearbyTechnicianProvider extends ChangeNotifier {
  final TechnicianService _technicianService;

  NearbyTechnicianProvider({required TechnicianService technicianService})
      : _technicianService = technicianService;

  List<TechnicianNearby> _technicians = [];
  bool _isLoading = false;
  String? _error;

  List<TechnicianNearby> get technicians => _technicians;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchNearby({required String categoryId, double? lat, double? lng}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _technicians = await _technicianService.getAvailableNearby(categoryId: categoryId, lat: lat, lng: lng);
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// Technician KYC Provider — drives the technician registration (KYC) screen and the
// post-login approval-status gate (pending / approved / rejected).
class TechnicianKycProvider extends ChangeNotifier {
  final TechnicianKycService _kycService;

  TechnicianKycProvider({required TechnicianKycService kycService}) : _kycService = kycService;

  TechnicianProfile? _profile;
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;

  TechnicianProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;

  /// Loads the technician's own profile. Leaves [profile] null (no error) if the
  /// technician hasn't submitted KYC yet — callers should route to the KYC screen.
  Future<void> loadMyProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _kycService.getMyProfile();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<void> updateLocation(double lat, double lng) async {
  final profile = _profile;
  if (profile == null) return;
  try {
    await _kycService.updateLocation(profile.id, lat, lng);
  } catch (_) {}
}

  /// Online/offline master toggle. This is the ONLY thing that actually
  /// flips `is_available` in the DB — without calling this, a technician
  /// never shows up in the customer-facing "nearest available" match, and
  /// preferred-technician video calls hit the same `is_available` gate too.
  /// Optimistic UI update with rollback on failure.
  Future<bool> setAvailability(bool available) async {
    final profile = _profile;
    if (profile == null) return false;
    final previous = profile.isAvailable;
    _profile = profile.copyWith(isAvailable: available);
    _error = null;
    notifyListeners();
    try {
      await _kycService.setAvailability(profile.id, available);
      return true;
    } catch (e) {
      _profile = _profile?.copyWith(isAvailable: previous);
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Saves the technician's weekly working hours (display-only for customers).
  /// Optimistic update with rollback on failure, mirroring [setAvailability].
  Future<bool> updateWorkingHours(Map<String, DayHours?> hours) async {
    final profile = _profile;
    if (profile == null) return false;
    final previous = profile.workingHours;
    _profile = profile.copyWith(workingHours: hours);
    _error = null;
    notifyListeners();
    try {
      await _kycService.setWorkingHours(profile.id, workingHoursToJson(hours));
      return true;
    } catch (e) {
      _profile = _profile?.copyWith(workingHours: previous);
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<String?> uploadFile(File file) async {
    _isUploading = true;
    _error = null;
    notifyListeners();
    try {
      final url = await _kycService.uploadFile(file);
      return url;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// Changes (photoUrl non-empty) or removes (photoUrl == '') the
  /// technician's own profile photo. Optimistic update with rollback on
  /// failure, mirroring [setAvailability].
  Future<bool> updateProfilePhoto(String photoUrl) async {
    final profile = _profile;
    if (profile == null) return false;
    final previous = profile.profilePhotoUrl;
    _profile = profile.copyWith(profilePhotoUrl: photoUrl);
    _error = null;
    notifyListeners();
    try {
      await _kycService.updateProfilePhoto(photoUrl);
      return true;
    } catch (e) {
      _profile = _profile?.copyWith(profilePhotoUrl: previous);
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> submit({
    required String categoryId,
    required int experienceYears,
    required String address,
    required String governmentIdUrl,
    required String profilePhotoUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _kycService.register(
        categoryId: categoryId,
        experienceYears: experienceYears,
        address: address,
        governmentIdUrl: governmentIdUrl,
        profilePhotoUrl: profilePhotoUrl,
      );
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// User Profile Provider
class UserProvider extends ChangeNotifier {
  final UserService _userService;

  User? _user;
  bool _isLoading = false;
  String? _error;

  UserProvider({required UserService userService}) : _userService = userService;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _userService.getProfile();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _userService.updateProfile(data);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Changes (photoUrl non-empty) or removes (photoUrl == '') the user's own
  /// profile photo, then re-fetches so [user] reflects the new photo_url
  /// (or falls back to the name-initial avatar when removed).
  Future<bool> updatePhoto(String photoUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _userService.updatePhoto(photoUrl);
      _user = await _userService.getProfile();
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}