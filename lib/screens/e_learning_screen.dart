import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/course.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import 'course_content_screen.dart';

class ELearningScreen extends StatefulWidget {
  const ELearningScreen({super.key});

  @override
  State<ELearningScreen> createState() => _ELearningScreenState();
}

class _ELearningScreenState extends State<ELearningScreen> {
  late Future<List<Course>> _coursesFuture;
  late Future<List<Course>> _enrollmentsFuture;
  int? _enrollingId;

  @override
  void initState() {
    super.initState();
    _coursesFuture = _loadCourses();
    _enrollmentsFuture = _loadEnrollments();
  }

  Future<List<Course>> _loadCourses() async {
    final api = context.read<AppState>().api;
    return api.getCourses();
  }

  Future<List<Course>> _loadEnrollments() async {
    try {
      final api = context.read<AppState>().api;
      return api.getUserEnrollments();
    } catch (_) {
      return const <Course>[];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _coursesFuture = _loadCourses();
      _enrollmentsFuture = _loadEnrollments();
    });
    await Future.wait([_coursesFuture, _enrollmentsFuture]);
  }

  Future<void> _enroll(int courseId, String title) async {
    if (_enrollingId != null) return;
    setState(() => _enrollingId = courseId);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().api.enrollInCourse(courseId);
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Enrolled successfully'))),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CourseContentScreen(courseId: courseId, courseTitle: title),
        ),
      );
      // Refresh enrollments after returning from course
      if (mounted) {
        setState(() {
          _enrollmentsFuture = _loadEnrollments();
        });
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('Unable to enroll right now'))),
      );
    } finally {
      if (mounted) setState(() => _enrollingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minWidth: double.infinity),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accentPurple,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('E-Learning'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('Grow your farming skills with quick lessons.'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<Course>>(
                  future: _coursesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 80),
                          Center(child: CircularProgressIndicator()),
                        ],
                      );
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          const Center(child: Icon(Icons.cloud_off, size: 48)),
                          const SizedBox(height: 12),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  context.tr('Unable to load courses'),
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _refresh,
                                  child: Text(context.tr('Retry')),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    final courses = snapshot.data ?? const <Course>[];
                    if (courses.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          EmptyState(
                            icon: Icons.school_rounded,
                            title: context.tr('No courses yet'),
                            description: context.tr(
                              'Trainers will publish livestock lessons here soon.',
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      itemCount: courses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, index) {
                        final course = courses[index];
                        // Backend now includes enrollment status in course data
                        final isEnrolled = course.isEnrolled;
                        final progress = course.progress;
                        final isCompleted = course.isCompleted;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .05),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (course.thumbnailUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        course.thumbnailUrl!,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.menu_book_rounded,
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                course.title,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            if (course.difficulty != null)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.background,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  course.difficulty!,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        letterSpacing: .2,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          course.instructorName ??
                                              context.tr('Community trainer'),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                course.description ??
                                    context.tr(
                                      'No description provided by instructor.',
                                    ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isEnrolled)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isCompleted
                                                ? Icons.celebration
                                                : Icons.check_circle,
                                            size: 16,
                                            color: isCompleted
                                                ? Colors.orange.shade700
                                                : Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isCompleted
                                                ? context.tr('Course completed')
                                                : context.tr(
                                                    'Already taking this course',
                                                  ),
                                            style: TextStyle(
                                              color: isCompleted
                                                  ? Colors.orange.shade700
                                                  : Colors.green.shade700,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isCompleted
                                            ? context.tr(
                                                'Great job! Revisit the lessons anytime.',
                                              )
                                            : context.tr(
                                                'Pick up where you left off.',
                                              ),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (progress != null && !isCompleted)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${context.tr('Progress')}: ${(progress * 100).toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              LinearProgressIndicator(
                                                value: progress,
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(
                                                      theme.colorScheme.primary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: isEnrolled
                                    ? OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context)
                                              .push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      CourseContentScreen(
                                                        courseId: course.id,
                                                        courseTitle:
                                                            course.title,
                                                      ),
                                                ),
                                              )
                                              .then((_) {
                                                if (mounted) {
                                                  setState(() {
                                                    _enrollmentsFuture =
                                                        _loadEnrollments();
                                                  });
                                                }
                                              });
                                        },
                                        icon: const Icon(
                                          Icons.visibility_rounded,
                                        ),
                                        label: Text(context.tr('See course')),
                                      )
                                    : ElevatedButton(
                                        onPressed: _enrollingId == course.id
                                            ? null
                                            : () => _enroll(
                                                course.id,
                                                course.title,
                                              ),
                                        child: _enrollingId == course.id
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : Text(context.tr('Take course')),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
