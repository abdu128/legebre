import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/course.dart';
import '../services/api_exception.dart';
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

  String _friendlyErrorMessage(
    Object error, {
    required String fallbackKey,
  }) {
    if (error is ApiException) {
      final status = error.statusCode;
      final rawMessage = error.message.trim();
      final normalized = rawMessage.toLowerCase();

      final isAuthError =
          status == 401 ||
          status == 403 ||
          normalized.contains('log in') ||
          normalized.contains('unauthor') ||
          normalized.contains('token');

      if (isAuthError) {
        return context.tr('Please log in to continue');
      }

      if (status == 409 || normalized.contains('already')) {
        return context.tr('Already taking this course');
      }

      if (status == 404 || normalized.contains('not found')) {
        return context.tr('This course is no longer available.');
      }

      final isNetworkLike =
          normalized.contains('socket') ||
          normalized.contains('failed host lookup') ||
          normalized.contains('network') ||
          normalized.contains('timed out') ||
          normalized.contains('connection');

      if (isNetworkLike) {
        return context.tr('Please check your internet connection and try again.');
      }

      if (rawMessage.isNotEmpty && !normalized.startsWith('unexpected error')) {
        return rawMessage;
      }
    }

    final generic = error.toString().toLowerCase();
    if (generic.contains('socket') ||
        generic.contains('failed host lookup') ||
        generic.contains('network') ||
        generic.contains('timed out') ||
        generic.contains('connection')) {
      return context.tr('Please check your internet connection and try again.');
    }

    return context.tr(fallbackKey);
  }

  String? _normalizeMediaUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

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
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _friendlyErrorMessage(
              error,
              fallbackKey: 'Unable to enroll right now',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _enrollingId = null);
    }
  }

  Future<void> _showPaymentSheet(Course course) async {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final payerNameController = TextEditingController();
    final refController = TextEditingController();
    final picker = ImagePicker();
    XFile? selectedPhoto;
    bool requireOtp = true;
    bool isSubmittingProof = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickProofPhoto() async {
              final image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                setModalState(() {
                  selectedPhoto = image;
                });
              }
            }

            Future<void> submitProof() async {
              if (!formKey.currentState!.validate()) return;
              if (selectedPhoto == null && refController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr('Please upload a proof image or enter a transaction reference'),
                    ),
                  ),
                );
                return;
              }

              setModalState(() => isSubmittingProof = true);
              final messenger = ScaffoldMessenger.of(context);
              final api = context.read<AppState>().api;

              try {
                await api.submitCourseAccessRequest(
                  course.id,
                  payerName: payerNameController.text.trim(),
                  transactionReference: refController.text.trim(),
                  paymentProof: selectedPhoto,
                  requireOtp: requireOtp,
                );
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr('Payment proof submitted successfully'),
                    ),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
                Navigator.of(context).pop();
                _refresh();
              } on ApiException catch (error) {
                messenger.showSnackBar(SnackBar(content: Text(error.message)));
              } catch (_) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr('Failed to submit payment proof'),
                    ),
                  ),
                );
              } finally {
                setModalState(() => isSubmittingProof = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              context.tr('Unlock Course'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryGreen.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Bank Payment Details'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                            ),
                            const SizedBox(height: 8),
                            if (course.bankName != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('${context.tr('Bank Name')}: ${course.bankName}'),
                              ),
                            if (course.bankAccountName != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('${context.tr('Account Name')}: ${course.bankAccountName}'),
                              ),
                            if (course.bankAccountNumber != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${context.tr('Account Number')}: ${course.bankAccountNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (course.paymentInstructions != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  course.paymentInstructions!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: payerNameController,
                        decoration: InputDecoration(
                          hintText: context.tr('Payer Name *'),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('Payer name is required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: refController,
                        decoration: InputDecoration(
                          hintText: context.tr('Transaction Reference'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: pickProofPhoto,
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.primaryGreen.withValues(alpha: 0.2),
                            ),
                            color: AppColors.background,
                          ),
                          child: selectedPhoto == null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.add_a_photo_rounded,
                                        color: AppColors.primaryGreen,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        context.tr('Upload Payment Receipt'),
                                        style: const TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Image.file(
                                        File(selectedPhoto!.path),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            selectedPhoto = null;
                                          });
                                        },
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.black87,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: Text(
                          context.tr('Receive Access Code via SMS'),
                          style: const TextStyle(fontSize: 14),
                        ),
                        value: requireOtp,
                        activeColor: AppColors.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setModalState(() {
                            requireOtp = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isSubmittingProof ? null : submitProof,
                        child: isSubmittingProof
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(context.tr('Submit Payment Proof')),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showOtpDialog(Course course) async {
    final otpController = TextEditingController();
    bool isVerifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> verifyOtp() async {
              final otp = otpController.text.trim();
              if (otp.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('Please enter 6-digit code')),
                  ),
                );
                return;
              }

              setDialogState(() => isVerifying = true);
              final messenger = ScaffoldMessenger.of(context);
              final api = context.read<AppState>().api;

              try {
                await api.verifyCourseAccessOtp(course.id, otp: otp);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(context.tr('Course unlocked successfully')),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
                Navigator.of(context).pop();
                _refresh();
              } on ApiException catch (error) {
                messenger.showSnackBar(SnackBar(content: Text(error.message)));
              } catch (_) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr('Failed to verify access code'),
                    ),
                  ),
                );
              } finally {
                setDialogState(() => isVerifying = false);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                context.tr('Enter Access Code'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr(
                      'Please enter the 6-digit access code sent to your phone number.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '******',
                      hintStyle: TextStyle(letterSpacing: 8),
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    context.tr('Cancel'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: isVerifying ? null : verifyOtp,
                  child: isVerifying
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          context.tr('Verify'),
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
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
                      final loadMessage = _friendlyErrorMessage(
                        snapshot.error!,
                        fallbackKey: 'Unable to load courses',
                      );
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
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Text(
                                    loadMessage,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
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
                        final isPremium = course.isPremium;
                        final isLocked = course.isLocked;
                        final hasPendingRequest = course.access?.hasPendingRequest ?? false;
                        final requiresOtp = course.access?.requiresOtp ?? false;

                        final thumbnailUrl =
                            _normalizeMediaUrl(course.thumbnailUrl);

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
                                  if (thumbnailUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        thumbnailUrl,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loading) {
                                          if (loading == null) return child;
                                          return Container(
                                            width: 64,
                                            height: 64,
                                            alignment: Alignment.center,
                                            color: AppColors.background,
                                            child: const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              color: AppColors.background,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Icon(Icons.menu_book_rounded),
                                          );
                                        },
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
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    course.title,
                                                    style: theme
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  if (isPremium && course.price != null)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4),
                                                      child: Text(
                                                        '${course.price} ${course.currency ?? 'ETB'}',
                                                        style: theme.textTheme.titleSmall?.copyWith(
                                                          color: AppColors.primaryGreen,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (isPremium)
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
                                                  color: Colors.amber.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.amber.shade400,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  context.tr('PREMIUM'),
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.amber.shade900,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: .2,
                                                      ),
                                                ),
                                              )
                                            else if (course.difficulty != null)
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
                                )
                              else if (isPremium && isLocked)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            hasPendingRequest
                                                ? Icons.hourglass_empty_rounded
                                                : requiresOtp
                                                    ? Icons.lock_open_rounded
                                                    : Icons.lock_rounded,
                                            size: 16,
                                            color: hasPendingRequest
                                                ? AppColors.accentOrange
                                                : requiresOtp
                                                    ? AppColors.accentPurple
                                                    : AppColors.accentRed,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            hasPendingRequest
                                                ? context.tr('Payment pending verification')
                                                : requiresOtp
                                                    ? context.tr('Payment approved, verification needed')
                                                    : context.tr('Premium course'),
                                            style: TextStyle(
                                              color: hasPendingRequest
                                                  ? AppColors.accentOrange
                                                  : requiresOtp
                                                      ? AppColors.accentPurple
                                                      : AppColors.accentRed,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        hasPendingRequest
                                            ? context.tr('Admin is verifying your transaction proof.')
                                            : requiresOtp
                                                ? context.tr('Your payment is approved! Enter the code to start.')
                                                : context.tr('Unlock full access to this course.'),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
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
                                    : (isPremium && isLocked)
                                        ? ElevatedButton(
                                            onPressed: hasPendingRequest
                                                ? null
                                                : () {
                                                    if (requiresOtp) {
                                                      _showOtpDialog(course);
                                                    } else {
                                                      _showPaymentSheet(course);
                                                    }
                                                  },
                                            child: Text(
                                              hasPendingRequest
                                                  ? context.tr('Pending Approval')
                                                  : requiresOtp
                                                      ? context.tr('Enter Access Code')
                                                      : context.tr('Unlock Course'),
                                            ),
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
