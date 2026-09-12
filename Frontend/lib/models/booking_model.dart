// Booking-related models.
//
// IMPORTANT: these field names are kept in exact sync with the backend JSON
// (see homefix_backend/internal/models/booking.go — BookingDetail). The
// customer-facing "My Bookings" screen and the technician-facing "My Jobs"
// screen both use the same [Booking] shape: `customer` is always present,
// `technician` is null until one is assigned.

import 'dart:convert';
import '../utils/working_hours.dart';

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
  final String status; // requested, accepted, on_the_way, arrived, in_progress, completed, cancelled
  final String paymentStatus; // pending, paid, refunded
  final String problemDescription;
  // Guided-questions answers (When did it start? / Continuous or occasional? /
  // Repaired before? / Unusual sound-smell-leak? / Emergency?) formatted as a
  // readable text block by IssueDetailsScreen — this IS the "Job Brief" data
  // the technician sees before accepting. Maps to the backend's free-form
  // `notes` column (see migration 006_booking_notes_images.sql), so no schema
  // change was needed — HomeFix already had a place to put this.
  final String? notes;
  // Photo/video URLs the customer attached while describing the issue.
  final List<String> images;
  final DateTime? scheduledAt;
  final double? estimatedPrice;
  final double? finalPrice;
  // otpCode is the arrival OTP the customer reads out to the technician —
  // only ever present in the CUSTOMER's own view of the booking (the backend
  // strips it for the technician), and only while status == 'arrived'.
  final String? otpCode;
  final DateTime? otpVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String categoryName;
  final BookingAddressInfo? address;
  final BookingCustomerInfo? customer;
  final BookingTechnicianInfo? technician;
  // --- Warranty (technician-controlled — see migration
  // 032_warranty_description.sql on the backend) ---
  // Set once, at completion, by the technician's optional "Warranty: Yes"
  // choice; warrantyDays is any positive number of days the technician
  // types — there's no admin-configured whitelist any more.
  final bool warrantyEnabled;
  final int? warrantyDays;
  final DateTime? warrantyExpiresAt;
  // Free text the technician writes describing what the warranty actually
  // covers (e.g. "Compressor and gas refill only") — separate from how long
  // it lasts.
  final String? warrantyDescription;
  // True if this booking is itself a warranty claim raised against an
  // earlier, completed booking (see [warrantyClaimOf]).
  final bool isWarrantyClaim;
  final String? warrantyClaimOf;
  final String? warrantyClaimOfServiceCode;
  // How this booking originated — 'pool' (open request), 'book_now'
  // (customer picked this technician directly from their profile), or
  // 'video_call' (created after an audio/video consultation call). Powers
  // the technician job screen's filter chips — see backend migration
  // 031_booking_source.sql.
  final String source;
  // Number of chat messages on this booking the current user hasn't read
  // yet — powers the unread badge on ConsultScreen's booking-chat list.
  final int unreadMessageCount;

  Booking({
    required this.id,
    required this.customerId,
    this.technicianId,
    required this.categoryId,
    required this.addressId,
    required this.status,
    this.paymentStatus = 'pending',
    required this.problemDescription,
    this.notes,
    this.images = const [],
    this.scheduledAt,
    this.estimatedPrice,
    this.finalPrice,
    this.otpCode,
    this.otpVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName = '',
    this.address,
    this.customer,
    this.technician,
    this.warrantyEnabled = false,
    this.warrantyDays,
    this.warrantyExpiresAt,
    this.warrantyDescription,
    this.isWarrantyClaim = false,
    this.warrantyClaimOf,
    this.warrantyClaimOfServiceCode,
    this.source = 'pool',
    this.unreadMessageCount = 0,
  });

  /// Price to display: final price once the job is done, otherwise the estimate.
  double? get displayPrice => finalPrice ?? estimatedPrice;

  /// True once the technician has submitted final_price (the invoice) via
  /// Complete — this is what should trigger a "Pay Now" prompt, and
  /// [paymentStatus] is what should hide it again once actually paid.
  bool get isInvoiced => status == 'completed' && finalPrice != null;
  bool get isPaid => paymentStatus == 'paid';

  /// True while the technician has submitted a cost estimate that the
  /// customer still needs to approve/decline (Physical Inspection ->
  /// Estimate -> Approval flow).
  bool get isAwaitingEstimateApproval => status == 'awaiting_estimate_approval';

  /// True if this completed booking is currently covered by a warranty the
  /// technician chose to offer at completion — the single source of truth
  /// for whether to show the "Claim Warranty" action.
  bool get isUnderWarranty =>
      warrantyEnabled && warrantyExpiresAt != null && DateTime.now().isBefore(warrantyExpiresAt!) && !isWarrantyClaim;

  /// Alias for [isUnderWarranty] — same check, named to match how
  /// ServiceHistoryScreen reads it ("can the customer claim this now").
  bool get canClaimWarranty => isUnderWarranty;

  /// True once a booking has been completed and the technician made *some*
  /// explicit warranty choice (yes or no) — used to decide whether to show
  /// the warranty section on the invoice/service-details screen at all.
  bool get hasWarrantyDecision => status == 'completed';

  /// True if this booking came from the customer tapping "Book Now" on a
  /// specific technician's profile (as opposed to the open request pool or a
  /// video-call consultation).
  bool get isBookNowSource => source == 'book_now';

  /// True if this booking was created after an audio/video consultation call.
  bool get isVideoCallSource => source == 'video_call';

  /// True if the customer picked a future date/time slot rather than ASAP.
  bool get isScheduledForLater => scheduledAt != null && scheduledAt!.isAfter(DateTime.now());

  // ---------------------------------------------------------------------
  // Job Brief
  //
  // IssueDetailsScreen / AIDiagnosisScreen / PostCallScreen collect guided-
  // question answers, AI diagnosis text, and consultation notes into a
  // [JobBrief], which BookTechnicianScreen encodes into this booking's
  // `notes` field at creation time (see JobBrief.encode/.decode below) — no
  // backend schema change needed, `notes` already existed as a free-form
  // column. [jobBrief] is the single place that decodes it back out, used
  // by both JobBriefCard (job detail) and jobBriefPreviewLine (job list).
  JobBrief? get jobBrief => JobBrief.decode(notes);

  /// True if the customer flagged this as an emergency in the guided
  /// questions — drives the 🚨 Urgent badge technicians see before accepting.
  bool get isUrgent => jobBrief?.isEmergency == true;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      technicianId: json['technician_id'] as String?,
      categoryId: json['category_id'] as String,
      addressId: json['address_id'] as String? ?? '',
      status: json['status'] as String,
      paymentStatus: (json['payment_status'] as String?) ?? 'pending',
      problemDescription: (json['problem_description'] as String?) ?? '',
      notes: json['notes'] as String?,
      images: (json['images'] as List?)?.map((e) => e as String).toList() ?? const [],
      scheduledAt: json['scheduled_at'] != null ? DateTime.tryParse(json['scheduled_at'] as String) : null,
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble(),
      finalPrice: (json['final_price'] as num?)?.toDouble(),
      otpCode: json['otp_code'] as String?,
      otpVerifiedAt: json['otp_verified_at'] != null ? DateTime.tryParse(json['otp_verified_at'] as String) : null,
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
      warrantyEnabled: json['warranty_enabled'] as bool? ?? false,
      warrantyDays: json['warranty_days'] as int?,
      warrantyExpiresAt:
          json['warranty_expires_at'] != null ? DateTime.tryParse(json['warranty_expires_at'] as String) : null,
      warrantyDescription: json['warranty_description'] as String?,
      isWarrantyClaim: json['is_warranty_claim'] as bool? ?? false,
      warrantyClaimOf: json['warranty_claim_of'] as String?,
      warrantyClaimOfServiceCode: json['warranty_claim_of_service_code'] as String?,
      source: (json['source'] as String?) ?? 'pool',
      unreadMessageCount: (json['unread_message_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Everything HomeFix collects about the problem before a technician ever
/// gets involved — guided-question answers, an AI diagnosis, and/or live
/// video consultation notes — bundled so the technician can read it all
/// before tapping Accept, instead of learning the details on-site.
///
/// Built up gradually across several screens (see BookingProvider's
/// pendingJobBrief / updatePendingJobBrief) and only actually persisted once
/// [encode]d into a booking's free-form `notes` field at creation time —
/// there's no dedicated backend column for it. [decode] is the inverse,
/// used by [Booking.jobBrief] to read it back out on the technician's side.
class JobBrief {
  final String? startedWhen;
  final bool? isContinuous;
  final bool? previousRepair;
  final bool? isEmergency;
  final String? unusualSigns;
  final bool hasVideo;
  final String? videoUrl;
  final String? aiDiagnosis;
  final String? consultationNotes;
  final Map<String, String>? categoryAnswers;

  const JobBrief({
    this.startedWhen,
    this.isContinuous,
    this.previousRepair,
    this.isEmergency,
    this.unusualSigns,
    this.hasVideo = false,
    this.videoUrl,
    this.aiDiagnosis,
    this.consultationNotes,
    this.categoryAnswers,
  });

  /// True if the customer actually answered any of the guided questions —
  /// distinct from [hasVideo]/[aiDiagnosis] having content, since a booking
  /// can carry AI/consultation notes without any guided answers (or vice
  /// versa). Drives whether JobBriefCard shows the "Customer answers"
  /// section vs. its empty-state message.
  bool get hasGuidedAnswers =>
      startedWhen != null || isContinuous != null || previousRepair != null || isEmergency != null ||
      (unusualSigns != null && unusualSigns!.isNotEmpty);

  JobBrief copyWith({
    String? startedWhen,
    bool? isContinuous,
    bool? previousRepair,
    bool? isEmergency,
    String? unusualSigns,
    bool? hasVideo,
    String? videoUrl,
    String? aiDiagnosis,
    String? consultationNotes,
    Map<String, String>? categoryAnswers,
  }) {
    return JobBrief(
      startedWhen: startedWhen ?? this.startedWhen,
      isContinuous: isContinuous ?? this.isContinuous,
      previousRepair: previousRepair ?? this.previousRepair,
      isEmergency: isEmergency ?? this.isEmergency,
      unusualSigns: unusualSigns ?? this.unusualSigns,
      hasVideo: hasVideo ?? this.hasVideo,
      videoUrl: videoUrl ?? this.videoUrl,
      aiDiagnosis: aiDiagnosis ?? this.aiDiagnosis,
      consultationNotes: consultationNotes ?? this.consultationNotes,
      categoryAnswers: categoryAnswers ?? this.categoryAnswers,
    );
  }

  // A short marker prefix (kept from the original plain-text format) lets
  // [decode] tell a real Job Brief apart from any other free-form text a
  // technician or an older client version might have put in `notes`,
  // without needing a new booking field. Everything after the marker is
  // just compact JSON — far more robust than hand-parsed "Label: value"
  // lines once multi-line fields like [aiDiagnosis] are involved.
  static const _marker = '[JobBrief]';

  String encode() {
    final map = {
      if (startedWhen != null) 'startedWhen': startedWhen,
      if (isContinuous != null) 'isContinuous': isContinuous,
      if (previousRepair != null) 'previousRepair': previousRepair,
      if (isEmergency != null) 'isEmergency': isEmergency,
      if (unusualSigns != null && unusualSigns!.isNotEmpty) 'unusualSigns': unusualSigns,
      if (hasVideo) 'hasVideo': hasVideo,
      if (videoUrl != null && videoUrl!.isNotEmpty) 'videoUrl': videoUrl,
      if (aiDiagnosis != null && aiDiagnosis!.isNotEmpty) 'aiDiagnosis': aiDiagnosis,
      if (consultationNotes != null && consultationNotes!.isNotEmpty) 'consultationNotes': consultationNotes,
      if (categoryAnswers != null && categoryAnswers!.isNotEmpty) 'categoryAnswers': categoryAnswers,
    };
    return '$_marker${jsonEncode(map)}';
  }

  /// Returns null if [notes] doesn't contain an encoded Job Brief at all —
  /// e.g. it's null, empty, plain free-form text, or (defensively) malformed
  /// JSON left over from a future format change.
  static JobBrief? decode(String? notes) {
    if (notes == null || !notes.contains(_marker)) return null;
    try {
      final jsonPart = notes.substring(notes.indexOf(_marker) + _marker.length);
      final map = jsonDecode(jsonPart) as Map<String, dynamic>;
      return JobBrief(
        startedWhen: map['startedWhen'] as String?,
        isContinuous: map['isContinuous'] as bool?,
        previousRepair: map['previousRepair'] as bool?,
        isEmergency: map['isEmergency'] as bool?,
        unusualSigns: map['unusualSigns'] as String?,
        hasVideo: map['hasVideo'] as bool? ?? false,
        videoUrl: map['videoUrl'] as String?,
        aiDiagnosis: map['aiDiagnosis'] as String?,
        consultationNotes: map['consultationNotes'] as String?,
        categoryAnswers: (map['categoryAnswers'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, value as String)),
      );
    } catch (_) {
      return null;
    }
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

// BookingJobPhoto is a "before" or "after" proof photo the technician
// attaches on-site — separate from Booking.images, which is the customer's
// own upload of the problem at booking time.
// Matches backend internal/models/booking.go -> BookingJobPhoto.
class BookingJobPhoto {
  final String id;
  final String bookingId;
  final String technicianId;
  final String photoType; // "before" | "after"
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;

  BookingJobPhoto({
    required this.id,
    required this.bookingId,
    required this.technicianId,
    required this.photoType,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
  });

  bool get isBefore => photoType == 'before';
  bool get isAfter => photoType == 'after';

  factory BookingJobPhoto.fromJson(Map<String, dynamic> json) {
    return BookingJobPhoto(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      technicianId: json['technician_id'] as String,
      photoType: (json['photo_type'] as String?) ?? '',
      imageUrl: (json['image_url'] as String?) ?? '',
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// --- Physical Inspection -> Estimate -> Approval ---
//
// Matches backend internal/models/booking.go -> BookingEstimateItem /
// BookingEstimate exactly. A technician submits one of these after
// physically inspecting the job on-site; the customer must approve or
// decline it before the job can be completed and invoiced.

class BookingEstimateItem {
  final String id;
  final String estimateId;
  final String itemType; // "labour" | "part"
  final String name;
  final double quantity;
  final double unitPrice;
  final double amount;

  BookingEstimateItem({
    required this.id,
    required this.estimateId,
    required this.itemType,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });

  bool get isLabour => itemType == 'labour';

  factory BookingEstimateItem.fromJson(Map<String, dynamic> json) {
    return BookingEstimateItem(
      id: (json['id'] as String?) ?? '',
      estimateId: (json['estimate_id'] as String?) ?? '',
      itemType: (json['item_type'] as String?) ?? 'part',
      name: (json['name'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Body shape expected by POST /bookings/:id/estimate's `items` array.
  Map<String, dynamic> toRequestJson() {
    return {
      'item_type': itemType,
      'name': name,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}

class BookingEstimate {
  final String id;
  final String bookingId;
  final String technicianId;
  final String status; // "pending" | "approved" | "declined"
  final double labourAmount;
  final double partsAmount;
  final double totalAmount;
  final String? note;
  final String? customerNote;
  final List<BookingEstimateItem> items;
  final DateTime createdAt;
  final DateTime? decidedAt;

  BookingEstimate({
    required this.id,
    required this.bookingId,
    required this.technicianId,
    required this.status,
    required this.labourAmount,
    required this.partsAmount,
    required this.totalAmount,
    this.note,
    this.customerNote,
    required this.items,
    required this.createdAt,
    this.decidedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDeclined => status == 'declined';

  List<BookingEstimateItem> get labourItems => items.where((i) => i.isLabour).toList();
  List<BookingEstimateItem> get partItems => items.where((i) => !i.isLabour).toList();

  factory BookingEstimate.fromJson(Map<String, dynamic> json) {
    return BookingEstimate(
      id: (json['id'] as String?) ?? '',
      bookingId: (json['booking_id'] as String?) ?? '',
      technicianId: (json['technician_id'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      labourAmount: (json['labour_amount'] as num?)?.toDouble() ?? 0,
      partsAmount: (json['parts_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
      customerNote: json['customer_note'] as String?,
      items: (json['items'] as List? ?? [])
          .map((e) => BookingEstimateItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      decidedAt: json['decided_at'] != null ? DateTime.tryParse(json['decided_at'] as String) : null,
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
  final Map<String, DayHours?> workingHours;
  // Used by home_screen.dart's "My Technicians" card, technician_detail_screen.dart
  // and technician_list_screen.dart avatars — same 'profile_photo_url' key the
  // KYC/admin endpoints already use elsewhere.
  final String? profilePhotoUrl;

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
    this.workingHours = const {},
    this.profilePhotoUrl,
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
      workingHours: parseWorkingHours(json['working_hours']),
      profilePhotoUrl: json['profile_photo_url'] as String?,
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
      'working_hours': workingHours.map((k, v) => MapEntry(k, v?.toJson())),
      'profile_photo_url': profilePhotoUrl,
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
  // Same avatar field as [Technician] — technician_list_screen.dart's
  // recommended-technician card reads this off TechnicianNearby directly.
  final String? profilePhotoUrl;

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
    this.profilePhotoUrl,
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
      profilePhotoUrl: json['profile_photo_url'] as String?,
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
  final Map<String, DayHours?> workingHours;

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
    this.workingHours = const {},
  });

  bool get isPending => approvalStatus == 'pending';
  bool get isApproved => approvalStatus == 'approved';
  bool get isRejected => approvalStatus == 'rejected';

  TechnicianProfile copyWith({
    bool? isAvailable,
    Map<String, DayHours?>? workingHours,
    String? profilePhotoUrl,
  }) {
    return TechnicianProfile(
      id: id,
      userId: userId,
      categoryId: categoryId,
      experienceYears: experienceYears,
      address: address,
      governmentIdUrl: governmentIdUrl,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      approvalStatus: approvalStatus,
      rejectionReason: rejectionReason,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      isVerified: isVerified,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt,
      workingHours: workingHours ?? this.workingHours,
    );
  }

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
      workingHours: parseWorkingHours(json['working_hours']),
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
  // Admin-configured whitelist of warranty durations (days) a technician may
  // offer at job completion for this category — e.g. [7, 15, 30, 90]. The
  // technician-facing completion screen must only ever offer these values;
  // it's also enforced server-side (see BookingService.Complete on the
  // backend), so this is purely for building the picker UI.
  final List<int> warrantyOptions;

  Category({
    required this.id,
    required this.name,
    required this.description,
    this.iconUrl,
    required this.basePrice,
    required this.isActive,
    this.warrantyOptions = const [7, 15, 30, 90],
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      iconUrl: json['icon_url'] as String?,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      warrantyOptions: (json['warranty_options'] as List?)?.map((e) => (e as num).toInt()).toList() ??
          const [7, 15, 30, 90],
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
      'warranty_options': warrantyOptions,
    };
  }
}

// ServiceHistoryPayment — pricing/tier info for one paid booking. Matches backend
// internal/models/booking.go -> ServiceHistoryPayment.
class ServiceHistoryPayment {
  final double amount;
  final String status;
  final bool isRepeatCustomer;
  final double? repeatDiscountPercent;
  final double? repeatDiscountAmount;

  ServiceHistoryPayment({
    required this.amount,
    required this.status,
    required this.isRepeatCustomer,
    this.repeatDiscountPercent,
    this.repeatDiscountAmount,
  });

  factory ServiceHistoryPayment.fromJson(Map<String, dynamic> json) {
    return ServiceHistoryPayment(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] as String?) ?? '',
      isRepeatCustomer: json['is_repeat_customer'] as bool? ?? false,
      repeatDiscountPercent: (json['repeat_discount_percent'] as num?)?.toDouble(),
      repeatDiscountAmount: (json['repeat_discount_amount'] as num?)?.toDouble(),
    );
  }
}

// ServiceHistoryEntry — one past booking between a specific customer and
// technician, with its payment/pricing-tier info attached (null if never paid).
// Matches backend internal/models/booking.go -> ServiceHistoryEntry. Reuses
// [Booking.fromJson] for the embedded booking fields since the backend embeds
// BookingDetail the same way as the other detailed booking endpoints.
class ServiceHistoryEntry {
  final Booking booking;
  final ServiceHistoryPayment? payment;

  ServiceHistoryEntry({required this.booking, this.payment});

  factory ServiceHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ServiceHistoryEntry(
      booking: Booking.fromJson(json),
      payment: json['payment'] != null
          ? ServiceHistoryPayment.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
    );
  }
}

// RepeatCustomer — a customer who has booked a given technician more than once.
// Matches backend internal/models/technician.go -> RepeatCustomer.
class RepeatCustomer {
  final String customerId;
  final String name;
  final String phone;
  final int totalBookings;
  final DateTime lastBookingAt;

  RepeatCustomer({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.totalBookings,
    required this.lastBookingAt,
  });

  factory RepeatCustomer.fromJson(Map<String, dynamic> json) {
    return RepeatCustomer(
      customerId: json['customer_id'] as String? ?? '',
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      totalBookings: (json['total_bookings'] as num?)?.toInt() ?? 0,
      lastBookingAt: DateTime.tryParse(json['last_booking_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// RepeatTechnician — customer-side mirror of RepeatCustomer: a technician the
// logged-in customer has booked more than once.
// Matches backend internal/models/technician.go -> RepeatTechnician.
class RepeatTechnician {
  final String technicianId;
  final String name;
  final String phone;
  final String categoryName;
  final String profilePhotoUrl;
  final double ratingAvg;
  final int totalBookings;
  final DateTime lastBookingAt;

  RepeatTechnician({
    required this.technicianId,
    required this.name,
    required this.phone,
    required this.categoryName,
    required this.profilePhotoUrl,
    required this.ratingAvg,
    required this.totalBookings,
    required this.lastBookingAt,
  });

  factory RepeatTechnician.fromJson(Map<String, dynamic> json) {
    return RepeatTechnician(
      technicianId: json['technician_id'] as String? ?? '',
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      categoryName: (json['category_name'] as String?) ?? '',
      profilePhotoUrl: (json['profile_photo_url'] as String?) ?? '',
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
      totalBookings: (json['total_bookings'] as num?)?.toInt() ?? 0,
      lastBookingAt: DateTime.tryParse(json['last_booking_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
// Review — a customer's rating + comment for a completed booking. Matches
// backend internal/models/payment.go -> Review.
class Review {
  final String id;
  final String bookingId;
  final String customerId;
  final String technicianId;
  final int rating;
  final String comment;
  final DateTime createdAt;
  // Only populated on the technician-facing "My Reviews" list (see
  // ReviewRepository.ListByTechnician on the backend) — who left this
  // review, so it isn't just an anonymous rating + comment.
  final String customerName;

  Review({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.technicianId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.customerName = '',
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['id'] as String?) ?? '',
      bookingId: (json['booking_id'] as String?) ?? '',
      customerId: (json['customer_id'] as String?) ?? '',
      technicianId: (json['technician_id'] as String?) ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: (json['comment'] as String?) ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      customerName: (json['customer_name'] as String?) ?? '',
    );
  }
}

/// Response shape from GET /bookings/:id/call and POST
/// /bookings/:id/call/initiate — everything needed to join the WebRTC
/// signaling room for a booking's audio call (technician "Audio Call"
/// button). See CallHandler.Signal on the backend for the actual relay.
class BookingCallInfo {
  final String roomId;
  final List<Map<String, dynamic>> iceServers;
  final String? technicianName;
  final String? customerName;

  BookingCallInfo({
    required this.roomId,
    required this.iceServers,
    this.technicianName,
    this.customerName,
  });

  factory BookingCallInfo.fromJson(Map<String, dynamic> json) {
    final booking = json['booking'] as Map<String, dynamic>?;
    final tech = booking?['technician'] as Map<String, dynamic>?;
    final cust = booking?['customer'] as Map<String, dynamic>?;
    return BookingCallInfo(
      roomId: json['room_id'] as String,
      iceServers: (json['ice_servers'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      technicianName: tech?['name'] as String?,
      customerName: cust?['name'] as String?,
    );
  }
}  