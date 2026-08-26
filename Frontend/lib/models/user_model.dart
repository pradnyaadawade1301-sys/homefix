class User {
  final String id;
  final String name;
  final String? email;
  final String phone;
  final String role; // customer | technician | admin
  final bool phoneVerified;
  final bool emailVerified;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.role,
    required this.phoneVerified,
    this.emailVerified = false,
    this.photoUrl,
    required this.isActive,
    required this.createdAt,
  });

  bool get isTechnician => role == 'technician';

  /// Returns a copy with emailVerified updated — used by AuthProvider right
  /// after a successful verifyEmailOtp so the UI reflects it immediately.
  User copyWithEmailVerified(bool verified) {
    return User(
      id: id,
      name: name,
      email: email,
      phone: phone,
      role: role,
      phoneVerified: phoneVerified,
      emailVerified: verified,
      photoUrl: photoUrl,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String,
      role: (json['role'] as String?) ?? 'customer',
      phoneVerified: json['phone_verified'] as bool? ?? false,
      emailVerified: json['email_verified'] as bool? ?? false,
      photoUrl: json['photo_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'phone_verified': phoneVerified,
      'email_verified': emailVerified,
      'photo_url': photoUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Address {
  final String id;
  final String userId;
  final String label; // home, office, other
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String pincode;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.pincode,
    this.latitude,
    this.longitude,
    required this.isDefault,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      label: (json['label'] as String?) ?? '',
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      pincode: json['pincode'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'line1': line1,
      'line2': line2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
    };
  }
}

class AuthResponse {
  final User user;
  final String accessToken;
  final String refreshToken;

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}