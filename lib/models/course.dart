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

  bool get isEnrolled => enrollment?.enrolled ?? false;
  double? get progress => enrollment?.progress;
  bool get isCompleted => courseCompleted ?? enrollment?.completed ?? false;

  factory Course.fromJson(Map<String, dynamic> json) {
    CourseEnrollment? enrollment;
    if (json['enrollment'] is Map) {
      enrollment = CourseEnrollment.fromJson(
        json['enrollment'] as Map<String, dynamic>,
      );
    }

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


