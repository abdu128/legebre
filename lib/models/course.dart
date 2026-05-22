class Course {
  const Course({
    required this.id,
    required this.title,
    this.description,
    this.status,
    this.difficulty,
    this.thumbnailUrl,
    this.instructorName,
    this.enrollment,
    this.courseCompleted,
    this.accessType = 'FREE',
    this.price,
    this.currency,
    this.pricePackages,
    this.bankName,
    this.bankAccountName,
    this.bankAccountNumber,
    this.paymentInstructions,
    this.access,
  });

  final int id;
  final String title;
  final String? description;
  final String? status;
  final String? difficulty;
  final String? thumbnailUrl;
  final String? instructorName;
  final CourseEnrollment? enrollment;
  final bool? courseCompleted;
  final String accessType;
  final double? price;
  final String? currency;
  final dynamic pricePackages;
  final String? bankName;
  final String? bankAccountName;
  final String? bankAccountNumber;
  final String? paymentInstructions;
  final CourseAccessState? access;

  bool get isEnrolled => enrollment?.enrolled ?? false;
  double? get progress => enrollment?.progress;
  bool get isCompleted => courseCompleted ?? enrollment?.completed ?? false;
  bool get isPremium => accessType.toUpperCase() == 'PREMIUM';
  bool get hasAccess => access?.hasAccess ?? !isPremium;
  bool get isLocked => isPremium && !hasAccess;

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    CourseEnrollment? enrollment;
    if (json['enrollment'] is Map) {
      enrollment = CourseEnrollment.fromJson(
        json['enrollment'] as Map<String, dynamic>,
      );
    }

    final accessMap = json['access'] is Map
      ? Map<String, dynamic>.from(json['access'] as Map)
      : <String, dynamic>{};
    final accessState =
      accessMap.isNotEmpty ? CourseAccessState.fromJson(accessMap) : null;
    final pricingMap = accessMap['pricing'] is Map
      ? Map<String, dynamic>.from(accessMap['pricing'] as Map)
      : <String, dynamic>{};
    final accessType = (accessMap['accessType'] ??
        accessMap['access_type'] ??
        json['access_type'] ??
        json['accessType'] ??
        'FREE')
      .toString();
    final price = _parseDouble(pricingMap['price'] ?? json['price']);
    final currency =
      (pricingMap['currency'] ?? json['currency'])?.toString();
    final pricePackages = pricingMap['pricePackages'] ??
      pricingMap['price_packages'] ??
      json['price_packages'];
    final bankName =
      (pricingMap['bankName'] ?? json['bank_name'])?.toString();
    final bankAccountName =
      (pricingMap['bankAccountName'] ?? json['bank_account_name'])
        ?.toString();
    final bankAccountNumber =
      (pricingMap['bankAccountNumber'] ?? json['bank_account_number'])
        ?.toString();
    final paymentInstructions =
      (pricingMap['paymentInstructions'] ?? json['payment_instructions'])
        ?.toString();

    return Course(
      id: json['id'] as int,
      title: json['title']?.toString() ?? 'Course',
      description: json['description']?.toString(),
      status: json['status']?.toString(),
      difficulty: json['difficulty']?.toString(),
      thumbnailUrl: json['thumbnail']?.toString() ??
          json['thumbnailUrl']?.toString() ??
          (json['media'] is List && (json['media'] as List).isNotEmpty
              ? (json['media'] as List).first.toString()
              : null),
      instructorName: json['instructor_name']?.toString() ??
          json['instructorName']?.toString(),
      enrollment: enrollment,
      courseCompleted: json['courseCompleted'] as bool? ??
          json['course_completed'] as bool?,
      accessType: accessType,
      price: price,
      currency: currency,
      pricePackages: pricePackages,
      bankName: bankName,
      bankAccountName: bankAccountName,
      bankAccountNumber: bankAccountNumber,
      paymentInstructions: paymentInstructions,
      access: accessState,
    );
  }
}

class CourseAccessState {
  const CourseAccessState({
    required this.accessType,
    required this.hasAccess,
    this.requiresPayment,
    this.hasPendingRequest,
    this.hasApprovedRequest,
    this.requiresOtp,
  });

  final String accessType;
  final bool hasAccess;
  final bool? requiresPayment;
  final bool? hasPendingRequest;
  final bool? hasApprovedRequest;
  final bool? requiresOtp;

  factory CourseAccessState.fromJson(Map<String, dynamic> json) {
    return CourseAccessState(
      accessType:
          (json['accessType'] ?? json['access_type'] ?? 'FREE').toString(),
      hasAccess: json['hasAccess'] as bool? ?? json['has_access'] as bool? ??
          false,
      requiresPayment:
          json['requiresPayment'] as bool? ?? json['requires_payment'] as bool?,
      hasPendingRequest:
          json['hasPendingRequest'] as bool? ??
              json['has_pending_request'] as bool?,
      hasApprovedRequest:
          json['hasApprovedRequest'] as bool? ??
              json['has_approved_request'] as bool?,
      requiresOtp:
          json['requiresOtp'] as bool? ?? json['requires_otp'] as bool?,
    );
  }
}

class CourseEnrollment {
  const CourseEnrollment({
    required this.enrolled,
    this.progress,
    this.completed,
  });

  final bool enrolled;
  final double? progress;
  final bool? completed;

  factory CourseEnrollment.fromJson(Map<String, dynamic> json) {
    return CourseEnrollment(
      enrolled: json['enrolled'] as bool? ?? false,
      progress: json['progress'] != null
          ? (json['progress'] is int
              ? (json['progress'] as int).toDouble()
              : json['progress'] as double?)
          : null,
      completed: json['completed'] as bool? ?? json['courseCompleted'] as bool?,
    );
  }
}


