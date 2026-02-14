import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'quiz_screen.dart';

class CourseContentScreen extends StatefulWidget {
  const CourseContentScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  final int courseId;
  final String courseTitle;

  @override
  State<CourseContentScreen> createState() => _CourseContentScreenState();
}

class _CourseContentScreenState extends State<CourseContentScreen>
    with SingleTickerProviderStateMixin {
  late Future<void> _loadFuture;
  List<Map<String, dynamic>> _videos = const [];
  List<Map<String, dynamic>> _textLessons = const [];
  List<Map<String, dynamic>> _quizzes = const [];
  int? _playingVideoIndex;
  Set<int> _completedQuizzes = {};
  bool _isCourseCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadContent();
  }

  List<Map<String, dynamic>> _listFrom(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _preferList(
    Map<String, dynamic>? primary,
    Map<String, dynamic>? secondary,
    List<String> keys,
  ) {
    for (final source in [primary, secondary]) {
      if (source == null) continue;
      for (final key in keys) {
        final value = source[key];
        final list = _listFrom(value);
        if (list.isNotEmpty) return list;
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> _loadContent() async {
    final api = context.read<AppState>().api;
    Map<String, dynamic>? courseProgress;
    try {
      courseProgress = await api.getCourseProgress(widget.courseId);
    } catch (_) {
      courseProgress = null;
    }

    final courseData =
        courseProgress != null &&
            courseProgress['course'] is Map<String, dynamic>
        ? courseProgress['course'] as Map<String, dynamic>
        : courseProgress;

    var videos = _preferList(courseData, courseProgress, const ['videos']);
    if (videos.isEmpty) {
      videos = await api.getCourseVideos(widget.courseId);
    }

    var lessons = _preferList(courseData, courseProgress, const [
      'textLessons',
      'lessons',
    ]);
    if (lessons.isEmpty) {
      lessons = await api.getTextLessons(widget.courseId);
    }

    var quizzes = _preferList(courseData, courseProgress, const ['quizzes']);
    if (quizzes.isEmpty) {
      quizzes = await api.getQuizzes(widget.courseId);
    }

    final completedQuizzes = <int>{};
    bool courseCompleted =
        courseData?['courseCompleted'] as bool? ??
        courseData?['course_completed'] as bool? ??
        courseProgress?['courseCompleted'] as bool? ??
        courseProgress?['course_completed'] as bool? ??
        false;

    for (final quiz in quizzes) {
      final quizId = quiz['id'];
      final completed = quiz['completed'] as bool? ?? false;
      if (quizId is int && completed) {
        completedQuizzes.add(quizId);
      }
    }

    if (!courseCompleted && quizzes.isNotEmpty) {
      courseCompleted = quizzes.every((quiz) => quiz['completed'] == true);
    }

    if (!mounted) return;
    setState(() {
      _videos = videos;
      _textLessons = lessons;
      _quizzes = quizzes;
      _completedQuizzes = completedQuizzes;
      _isCourseCompleted = courseCompleted;
    });
  }

  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtube.com')) {
        return uri.queryParameters['v'];
      } else if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
    } catch (_) {}
    return null;
  }

  void _toggleVideo(int index) {
    setState(() {
      if (_playingVideoIndex == index) {
        _playingVideoIndex = null;
      } else {
        _playingVideoIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.courseTitle)),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 12),
                  Text(context.tr('Unable to load course content')),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _loadFuture = _loadContent();
                      });
                    },
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('Lessons'), style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (_textLessons.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(context.tr('No lessons yet')),
                  )
                else
                  ..._textLessons.asMap().entries.map((entry) {
                    final index = entry.key;
                    final lesson = entry.value;
                    final title =
                        (lesson['title'] ??
                                lesson['name'] ??
                                context.tr('Lesson'))
                            .toString();
                    final description =
                        (lesson['description'] ??
                                lesson['content'] ??
                                lesson['text'])
                            ?.toString();
                    final duration =
                        (lesson['readTime'] ??
                                lesson['duration'] ??
                                lesson['estimatedTime'])
                            ?.toString();

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(title, style: theme.textTheme.titleMedium),
                      subtitle: description != null && description.isNotEmpty
                          ? Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: duration != null && duration.isNotEmpty
                          ? Text(duration, style: theme.textTheme.bodySmall)
                          : null,
                    );
                  }),
                const SizedBox(height: 16),
                Text(context.tr('Videos'), style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (_videos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(context.tr('No videos yet')),
                  )
                else
                  ..._videos.asMap().entries.map((entry) {
                    final index = entry.key;
                    final video = entry.value;
                    final title =
                        (video['title'] ?? video['name'] ?? context.tr('Video'))
                            .toString();
                    final duration = video['duration']?.toString();
                    var url =
                        (video['video_url'] ??
                                video['url'] ??
                                video['youtubeUrl'] ??
                                video['youtube_link'] ??
                                video['link'])
                            ?.toString();
                    if (url != null &&
                        !url.startsWith('http://') &&
                        !url.startsWith('https://')) {
                      url = 'https://$url';
                    }
                    final videoId = url != null ? _extractVideoId(url) : null;
                    final isPlaying = _playingVideoIndex == index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: isPlaying && videoId != null
                                ? AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: YoutubePlayer(
                                      controller: YoutubePlayerController(
                                        initialVideoId: videoId,
                                        flags: const YoutubePlayerFlags(
                                          autoPlay: true,
                                          mute: false,
                                        ),
                                      ),
                                      showVideoProgressIndicator: true,
                                      progressIndicatorColor:
                                          theme.colorScheme.primary,
                                    ),
                                  )
                                : InkWell(
                                    onTap: () => _toggleVideo(index),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  theme.colorScheme.primary
                                                      .withOpacity(0.6),
                                                  theme
                                                      .colorScheme
                                                      .secondaryContainer
                                                      .withOpacity(0.6),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black45,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (duration != null &&
                                            duration.isNotEmpty)
                                          Positioned(
                                            right: 8,
                                            bottom: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black87,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                duration,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: theme.textTheme.titleMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPlaying)
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => _toggleVideo(index),
                                  tooltip: context.tr('Close player'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                Text(context.tr('Quizzes'), style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (_quizzes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(context.tr('No quizzes yet')),
                  )
                else
                  ..._quizzes.map((quiz) {
                    final title =
                        (quiz['title'] ?? quiz['name'] ?? context.tr('Quiz'))
                            .toString();
                    final quizId = quiz['id'] as int;
                    final isCompleted =
                        quiz['completed'] as bool? ??
                        _completedQuizzes.contains(quizId);
                    final bestScore = quiz['bestScore'] as num?;
                    final canRetake = quiz['canRetake'] as bool? ?? true;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isCompleted ? Icons.check_circle : Icons.quiz_rounded,
                        color: isCompleted ? Colors.green : null,
                      ),
                      title: Text(title, style: theme.textTheme.titleMedium),
                      subtitle: bestScore != null
                          ? Text(
                              '${context.tr('Best score')}: ${bestScore.toStringAsFixed(0)}%',
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCompleted)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Chip(
                                label: Text(context.tr('Completed')),
                                backgroundColor: Colors.green.shade50,
                                labelStyle: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          TextButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      QuizScreen(quizId: quizId, title: title),
                                ),
                              );
                              // Reload content after quiz completion
                              if (mounted) {
                                await _loadContent();
                              }
                            },
                            child: Text(
                              isCompleted && canRetake
                                  ? context.tr('Retake')
                                  : isCompleted
                                  ? context.tr('Review')
                                  : context.tr('Take quiz'),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                if (_isCourseCompleted && _quizzes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.celebration,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('Course Completed!'),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.tr(
                                      'You have successfully completed all quizzes.',
                                    ),
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
