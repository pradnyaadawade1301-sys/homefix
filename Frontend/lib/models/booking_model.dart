// Booking-related models.
//
// IMPORTANT: these field names are kept in exact sync with the backend JSON
// (see homefix_backend/internal/models/booking.go — BookingDetail). The
// customer-facing "My Bookings" screen and the technician-facing "My Jobs"
// screen both use the same [Booking] shape: `customer` is always present,
// `technician` is null until one is assigned.

class BookingCustomerInfo {
  final String id;
  final String name;
  final String phone;

  BookingCustomerInfo({required this.id, required this.name, required this.phone});

  factory BookingCustomerInfo.fromJson(Map<String, dynamic> json) {
    return BookingCustomerInfo(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
    );
  }
}

class BookingTechnicianInfo {
  final String id;
  final String name;
  final String phone;
  final String categoryName;
  final int experienceYears;
  final double ratingAvg;
  final int ratingCount;
  final bool isVerified;

  BookingTechnicianInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.categoryName,
    required this.experienceYears,
    required this.ratingAvg,
    required this.ratingCount,
    required this.isVerified,
  });

  factory BookingTechnicianInfo.fromJson(Map<String, dynamic> json) {
    return BookingTechnicianInfo(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      categoryName: (json['category_name'] as String?) ?? '',
      experienceYears: json['experience_years'] as int? ?? 0,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}

class BookingAddressInfo {
  final String label;
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String pincode;

  BookingAddressInfo({
    required this.label,
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.pincode,
  });

  String get formatted => [line1, if (line2.isNotEmpty) line2, city, state, pincode]
      .where((s) => s.isNotEmpty)
      .join(', ');

  factory BookingAddressInfo.fromJson(Map<String, dynamic> json) {
    return BookingAddressInfo(
      label: (json['label'] as String?) ?? '',
      line1: (json['line1'] as String?) ?? '',
      line2: (json['line2'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      state: (json['state'] as String?) ?? '',
      pincode: (json['pincode'] as String?) ?? '',
    );
  }
}

class Booking {
  final String id;
  final String customerId;
  final String? technicianId;
  final String categoryId;
  final String addressId;
  final String status; // requested, accepted, in_progress, completed, cancelled
  final String problemDescription;
  final DateTime? scheduledAt;
  final double? estimatedPrice;
  final double? finalPrice;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String categoryName;
  final BookingAddressInfo? address;
  final BookingCustomerInfo? customer;
  final BookingTechnicianInfo? technician;

  Booking({
    required this.id,
    required this.customerId,
    this.technicianId,
    required this.categoryId,
    required this.addressId,
    required this.status,
    required this.problemDescription,
    this.scheduledAt,
    this.estimatedPrice,
    this.finalPrice,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName = '',
    this.address,
    this.customer,
    this.technician,
  });

  /// Price to display: final price once the job is done, otherwise the estimate.
  double? get displayPrice => finalPrice ?? estimatedPrice;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      technicianId: json['technician_id'] as String?,
      categoryId: json['category_id'] as String,
      addressId: json['address_id'] as String? ?? '',
      status: json['status'] as String,
      problemDescription: (json['problem_description'] as String?) ?? '',
      scheduledAt: json['scheduled_at'] != null ? DateTime.tryParse(json['scheduled_at'] as String) : null,
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble(),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      categoryName: (json['category_name'] as String?) ?? '',
      address: json['address'] != null
          ? BookingAddressInfo.fromJson(json['address'] as Map<String, dynamic>)
          : null,
      customer: json['customer'] != null
          ? BookingCustomerInfo.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      technician: json['technician'] != null
          ? BookingTechnicianInfo.fromJson(json['technician'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// A single chat message between the customer and technician on a booking —
/// mirrors homefix_backend/internal/models/booking.go BookingMessage exactly.
class BookingMessage {
  final String id;
  final String bookingId;
  final String senderId;
  final String senderRole; // "customer" | "technician"
  final String content;
  final DateTime createdAt;

  BookingMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    required this.createdAt,
  });

  factory BookingMessage.fromJson(Map<String, dynamic> json) {
    return BookingMessage(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: (json['sender_role'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class BookingStatusHistory {
  final String id;
  final String bookingId;
  final String status;
  final String note;
  final DateTime createdAt;

  BookingStatusHistory({
    required this.id,
    required this.bookingId,
    required this.status,
    required this.note,
    required this.createdAt,
  });

  factory BookingStatusHistory.fromJson(Map<String, dynamic> json) {
    return BookingStatusHistory(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      status: json['status'] as String,
      note: (json['note'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Technician {
  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final int experienceYears;
  final double ratingAvg;
  final int ratingCount;
  final bool isVerified;
  final bool isAvailable;
  final DateTime createdAt;

  Technician({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.experienceYears,
    required this.ratingAvg,
    required this.ratingCount,
    required this.isVerified,
    required this.isAvailable,
    required this.createdAt,
  });

  factory Technician.fromJson(Map<String, dynamic> json) {
    return Technician(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      categoryId: (json['category_id'] as String?) ?? '',
      categoryName: (json['category_name'] as String?) ?? '',
      experienceYears: json['experience_years'] as int? ?? 0,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'category_name': categoryName,
      'experience_years': experienceYears,
      'rating_avg': ratingAvg,
      'rating_count': ratingCount,
      'is_verified': isVerified,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// TechnicianNearby is returned by GET /technicians/available — like [Technician] but
/// carries live lat/lng and a distance_km (only present when the request included the
/// customer's own lat/lng). Powers the nearby-technicians map/tracking screen.
class TechnicianNearby {
  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final int experienceYears;
  final double ratingAvg;
  final int ratingCount;
  final bool isAvailable;
  final double? currentLat;
  final double? currentLng;
  final double? distanceKm;

  TechnicianNearby({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.experienceYears,
    required this.ratingAvg,
    required this.ratingCount,
    required this.isAvailable,
    this.currentLat,
    this.currentLng,
    this.distanceKm,
  });

  bool get hasLocation => currentLat != null && currentLng != null;

  factory TechnicianNearby.fromJson(Map<String, dynamic> json) {
    return TechnicianNearby(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      categoryId: (json['category_id'] as String?) ?? '',
      categoryName: (json['category_name'] as String?) ?? '',
      experienceYears: json['experience_years'] as int? ?? 0,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      currentLat: (json['current_lat'] as num?)?.toDouble(),
      currentLng: (json['current_lng'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}

/// TechnicianProfile is the technician's OWN detailed profile — returned by
/// POST /technicians (register) and GET /technicians/me. Unlike [Technician]
/// (the public browse/detail shape), this includes KYC fields and the admin
/// approval status, since only the technician themself (and admin) sees these.
class TechnicianProfile {
  final String id;
  final String userId;
  final String categoryId;
  final int experienceYears;
  final String address;
  final String governmentIdUrl;
  final String profilePhotoUrl;
  final String approvalStatus; // "pending" | "approved" | "rejected"
  final String? rejectionReason;
  final double ratingAvg;
  final int ratingCount;
  final bool isVerified;
  final bool isAvailable;
  final DateTime createdAt;

  TechnicianProfile({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.experienceYears,
    required this.address,
    required this.governmentIdUrl,
    required this.profilePhotoUrl,
    required this.approvalStatus,
    this.rejectionReason,
    required this.ratingAvg,
    required this.ratingCount,
    required this.isVerified,
    required this.isAvailable,
    required this.createdAt,
  });

  bool get isPending => approvalStatus == 'pending';
  bool get isApproved => approvalStatus == 'approved';
  bool get isRejected => approvalStatus == 'rejected';

  factory TechnicianProfile.fromJson(Map<String, dynamic> json) {
    return TechnicianProfile(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? '',
      categoryId: (json['category_id'] as String?) ?? '',
      experienceYears: json['experience_years'] as int? ?? 0,
      address: (json['address'] as String?) ?? '',
      governmentIdUrl: (json['government_id_url'] as String?) ?? '',
      profilePhotoUrl: (json['profile_photo_url'] as String?) ?? '',
      approvalStatus: (json['approval_status'] as String?) ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class Category {
  final String id;
  final String name;
  final String description;
  final String? iconUrl;
  final double basePrice;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    required this.description,
    this.iconUrl,
    required this.basePrice,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      iconUrl: json['icon_url'] as String?,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'base_price': basePrice,
      'is_active': isActive,
    };
  }
}