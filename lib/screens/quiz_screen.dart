import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.quizId, required this.title});

  final int quizId;
  final String title;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizOption {
  const _QuizOption({required this.label, required this.value});

  final String label;
  final String value;
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<void> _loadFuture;
  List<Map<String, dynamic>> _questions = const [];
  final Map<int, int> _selectedOptions = {};
  final Map<int, String> _answerPayload = {};
  Map<String, dynamic>? _quizResults;
  Map<String, dynamic>? _quizMeta;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    final api = context.read<AppState>().api;
    Map<String, dynamic> quiz;
    List<Map<String, dynamic>> questions;
    try {
      quiz = await api.getQuiz(widget.quizId);
      questions = _mapList(quiz['questions']);
      if (questions.isEmpty) {
        final fallback = await api.getQuizQuestions(widget.quizId);
        questions = fallback;
      }
    } catch (_) {
      final fallback = await api.getQuizQuestions(widget.quizId);
      quiz = {'id': widget.quizId, 'title': widget.title};
      questions = fallback;
    }

    if (!mounted) return;
    setState(() {
      _quizMeta = quiz;
      _questions = questions;
      _quizResults = null;
      _selectedOptions.clear();
      _answerPayload.clear();
    });
  }

  List<Map<String, dynamic>> _mapList(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  List<dynamic> _normalizeOptionList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      return raw.entries
          .map((entry) => {'label': entry.key, 'value': entry.value})
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
        if (decoded is Map) {
          return decoded.entries
              .map((entry) => {'label': entry.key, 'value': entry.value})
              .toList();
        }
      } catch (_) {}
    }
    return const [];
  }

  List<_QuizOption> _parseOptions(dynamic raw) {
    final normalized = _normalizeOptionList(raw);
    final options = <_QuizOption>[];
    for (final item in normalized) {
      if (item is _QuizOption) {
        options.add(item);
        continue;
      }
      if (item is Map) {
        final value =
            item['value'] ?? item['option'] ?? item['text'] ?? item['label'];
        if (value == null) continue;
        final label = item['label'] ?? item['text'] ?? item['option'] ?? value;
        options.add(
          _QuizOption(label: label.toString(), value: value.toString()),
        );
        continue;
      }
      if (item != null) {
        final value = item.toString();
        if (value.isNotEmpty) {
          options.add(_QuizOption(label: value, value: value));
        }
      }
    }
    return options;
  }

  void _selectOption(int? questionId, int optionIndex, _QuizOption option) {
    if (questionId == null) return;
    setState(() {
      _selectedOptions[questionId] = optionIndex;
      _answerPayload[questionId] = option.value;
    });
  }

  Map<String, dynamic>? _resultForQuestion(dynamic results, int? questionId) {
    if (questionId == null || results is! List) return null;
    for (final entry in results) {
      if (entry is Map) {
        final typed = <String, dynamic>{};
        entry.forEach((key, value) {
          typed[key.toString()] = value;
        });
        final rawId = typed['questionId'] ?? typed['question_id'];
        if (rawId != null && int.tryParse(rawId.toString()) == questionId) {
          return typed;
        }
      }
    }
    return null;
  }

  bool _compareAnswers(dynamic a, dynamic b) {
    if (a == null || b == null) return false;
    return a.toString().trim().toLowerCase() ==
        b.toString().trim().toLowerCase();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Build answers payload as questionId -> selected option value.
      final answers = <String, dynamic>{};
      _answerPayload.forEach((key, value) {
        answers[key.toString()] = value;
      });
      final result = await context.read<AppState>().api.submitQuiz(
        widget.quizId,
        answers: answers,
      );
      if (!mounted) return;
      setState(() {
        _quizResults = result;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr('Unable to submit quiz')}: ${e.toString()}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
                  Text(context.tr('Unable to load quiz')),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _loadFuture = _loadQuiz();
                      });
                    },
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            );
          }

          if (_questions.isEmpty) {
            return Center(child: Text(context.tr('No questions available')));
          }

          // Show results if quiz is submitted
          if (_quizResults != null) {
            final summary = _quizResults!['summary'] as Map<String, dynamic>?;
            final totalQuestions =
                (_quizResults!['totalQuestions'] as num?)?.toInt() ??
                (summary?['totalQuestions'] as num?)?.toInt() ??
                _questions.length;
            final correctCount = (_quizResults!['correctCount'] as num?)
                ?.toInt();
            final scorePercentageRaw =
                (_quizResults!['scorePercentage'] as num?) ??
                (_quizResults!['score'] as num?) ??
                0;
            final scorePercentage = scorePercentageRaw.toDouble();
            final rawStatus = summary?['status'];
            final bool? statusPassed = rawStatus == null
                ? null
                : rawStatus.toString().toLowerCase() == 'pass';
            final isPassed =
                _quizResults!['passed'] as bool? ??
                summary?['passed'] as bool? ??
                statusPassed ??
                (scorePercentage >= 70);
            final formattedScore =
                summary?['score'] as String? ??
                (correctCount != null
                    ? '$correctCount / $totalQuestions (${scorePercentage.toStringAsFixed(0)}%)'
                    : '${scorePercentage.toStringAsFixed(0)}%');

            final results =
                _quizResults!['answerReview'] ??
                _quizResults!['results'] ??
                _quizResults!['questionResults'] ??
                <dynamic>[];

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Score summary card
                      Card(
                        color: isPassed
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                isPassed ? Icons.check_circle : Icons.cancel,
                                size: 64,
                                color: isPassed ? Colors.green : Colors.red,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isPassed
                                    ? context.tr('Quiz Passed!')
                                    : context.tr('Quiz Failed'),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isPassed ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${context.tr('Score')}: $formattedScore',
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Question results
                      Text(
                        context.tr('Review Answers'),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ..._questions.map((question) {
                        final rawId = question['id'];
                        final int? qId = rawId is int
                            ? rawId
                            : rawId is String
                            ? int.tryParse(rawId)
                            : null;
                        final options = _parseOptions(question['options']);
                        final questionResult = _resultForQuestion(results, qId);
                        final fallbackCorrect =
                            question['correctAnswer'] ??
                            question['correct_answer'] ??
                            question['answer'];
                        final fallbackUser = qId != null
                            ? _answerPayload[qId]
                            : null;
                        final displayCorrectAnswer =
                            questionResult?['correctAnswer'] ??
                            questionResult?['correct_answer'] ??
                            fallbackCorrect;
                        final displayUserAnswer =
                            questionResult?['userAnswer'] ??
                            questionResult?['user_answer'] ??
                            fallbackUser;
                        final isCorrect =
                            questionResult?['isCorrect'] as bool? ??
                            questionResult?['is_correct'] as bool? ??
                            _compareAnswers(
                              displayUserAnswer,
                              displayCorrectAnswer,
                            );
                        final pointsEarned =
                            questionResult?['pointsEarned'] ??
                            questionResult?['points_earned'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isCorrect
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isCorrect
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: isCorrect
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        (question['question'] ??
                                                question['text'] ??
                                                context.tr('Question'))
                                            .toString(),
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                    if (pointsEarned != null)
                                      Chip(
                                        label: Text(
                                          '+${pointsEarned.toString()} pts',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        backgroundColor: isCorrect
                                            ? Colors.green.shade100
                                            : Colors.red.shade100,
                                        padding: EdgeInsets.zero,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (options.isNotEmpty)
                                  ...options.asMap().entries.map((optEntry) {
                                    final option = optEntry.value;
                                    final isUserChoice =
                                        displayUserAnswer != null &&
                                        _compareAnswers(
                                          displayUserAnswer,
                                          option.value,
                                        );
                                    final isCorrectChoice =
                                        displayCorrectAnswer != null &&
                                        _compareAnswers(
                                          displayCorrectAnswer,
                                          option.value,
                                        );

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isCorrectChoice
                                                ? Icons.check_circle
                                                : isUserChoice
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_unchecked,
                                            color: isCorrectChoice
                                                ? Colors.green
                                                : isUserChoice
                                                ? Colors.blue
                                                : Colors.grey,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              option.label,
                                              style: TextStyle(
                                                color: isCorrectChoice
                                                    ? Colors.green.shade700
                                                    : isUserChoice
                                                    ? Colors.blue.shade700
                                                    : null,
                                                fontWeight: isCorrectChoice
                                                    ? FontWeight.bold
                                                    : null,
                                              ),
                                            ),
                                          ),
                                          if (isUserChoice && !isCorrectChoice)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Text(
                                                context.tr('Your answer'),
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          if (isCorrectChoice)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Text(
                                                context.tr('Correct'),
                                                style: TextStyle(
                                                  color: Colors.green.shade700,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                if (options.isEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (displayUserAnswer != null)
                                        Text(
                                          '${context.tr('Your answer')}: $displayUserAnswer',
                                          style: TextStyle(
                                            color: isCorrect
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      if (displayCorrectAnswer != null)
                                        Text(
                                          '${context.tr('Correct answer')}: '
                                          '$displayCorrectAnswer',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(context.tr('Close')),
                    ),
                  ),
                ),
              ],
            );
          }

          // Show quiz questions
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final question = _questions[index];
                    final rawId = question['id'];
                    final int? qId = rawId is int
                        ? rawId
                        : rawId is String
                        ? int.tryParse(rawId)
                        : null;
                    final options = _parseOptions(question['options']);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (question['question'] ??
                                      question['text'] ??
                                      context.tr('Question'))
                                  .toString(),
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (options.isEmpty)
                              Text(context.tr('No options provided'))
                            else
                              for (var i = 0; i < options.length; i++)
                                RadioListTile<int>(
                                  dense: true,
                                  value: i,
                                  groupValue: qId != null
                                      ? _selectedOptions[qId]
                                      : null,
                                  onChanged: qId == null || _isSubmitting
                                      ? null
                                      : (_) =>
                                            _selectOption(qId, i, options[i]),
                                  title: Text(options[i].label),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _isSubmitting ||
                            _answerPayload.length < _questions.length
                        ? null
                        : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('Submit quiz')),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
