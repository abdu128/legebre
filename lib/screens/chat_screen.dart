import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/animal.dart';
import '../services/api_exception.dart';
import '../state/app_state.dart';
import 'auth_screen.dart';
import 'listing_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.asSheet = false});

  /// Compact bottom-sheet style instead of a full page.
  final bool asSheet;

  static Future<void> openSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .35),
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: height * 0.72,
                maxWidth: 560,
              ),
              child: const Material(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                clipBehavior: Clip.antiAlias,
                child: ChatScreen(asSheet: true),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  _ChatMessage({
    required this.role,
    required this.text,
    this.listings = const [],
  });

  final String role; // user | assistant
  final String text;
  final List<Animal> listings;
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;
  bool _welcomeReady = false;

  static const _quickReplies = [
    'Find sheep in Addis',
    'Goats under 15,000 ETB',
    'Cattle near Hawassa',
    'Ox under 50,000 ETB',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(role: 'assistant', text: ''));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_welcomeReady && _messages.isNotEmpty) {
      _welcomeReady = true;
      _messages[0] = _ChatMessage(
        role: 'assistant',
        text: context.tr(
          'Hi! I can help you find livestock on Legebere. Try “Find sheep in Addis”, “Goats under 15,000 ETB”, or tell me what you need.',
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasUserMessages =>
      _messages.any((message) => message.role == 'user');

  List<Map<String, String>> _historyPayload() {
    return _messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .skip(1)
        .map(
          (m) => {
            'role': m.role == 'assistant' ? 'model' : 'user',
            'content': m.text,
          },
        )
        .toList();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;

    final appState = context.read<AppState>();
    if (!appState.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please log in to continue'))),
      );
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _sending = true;
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final history = _historyPayload();
      final prior = history.length > 1
          ? history.sublist(0, history.length - 1)
          : <Map<String, String>>[];

      final result = await appState.api.aiChat(
        message: text,
        history: prior,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            text: result.reply.isNotEmpty
                ? result.reply
                : 'I could not find matching listings.',
            listings: result.listings,
          ),
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            text: e.message.isNotEmpty
                ? e.message
                : 'Something went wrong. Please try again.',
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            text: 'Something went wrong. Please try again.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openListing(Animal item) async {
    final api = context.read<AppState>().api;
    final nav = Navigator.of(context, rootNavigator: true);
    final asSheet = widget.asSheet;

    if (asSheet && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    try {
      final animal = await api.getAnimal(item.id);
      await nav.push(
        MaterialPageRoute(builder: (_) => ListingDetailScreen(item: animal)),
      );
    } catch (_) {
      await nav.push(
        MaterialPageRoute(builder: (_) => ListingDetailScreen(item: item)),
      );
    }
  }

  Widget _buildHeader() {
    if (widget.asSheet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  Icons.smart_toy_rounded,
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('Ask Legebere'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepBrown,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.black.withValues(alpha: .06)),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildChatBody() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, index) {
              if (_sending && index == _messages.length) {
                return const _TypingIndicator();
              }
              final message = _messages[index];
              return _MessageBubble(
                message: message,
                onListingTap: _openListing,
              );
            },
          ),
        ),
        if (!_sending && !_hasUserMessages)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickReplies.map((label) {
                  return ActionChip(
                    label: Text(context.tr(label)),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: AppColors.primaryGreen.withValues(alpha: .25),
                    ),
                    onPressed: () => _send(context.tr(label)),
                  );
                }).toList(),
              ),
            ),
          ),
        Material(
          color: Colors.white,
          elevation: widget.asSheet ? 0 : 8,
          shadowColor: Colors.black.withValues(alpha: .06),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              10,
              12,
              widget.asSheet ? 12 : 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_sending,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 3,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: context.tr('Ask about livestock...'),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : () => _send(_controller.text),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primaryGreen.withValues(alpha: .4),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asSheet) {
      return SafeArea(
        top: false,
        child: _buildChatBody(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.tr('Ask Legebere')),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.deepBrown,
        elevation: 0.5,
      ),
      body: SafeArea(
        top: false,
        child: _buildChatBody(),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onListingTap,
  });

  final _ChatMessage message;
  final ValueChanged<Animal> onListingTap;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isUser ? AppColors.primaryGreen : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isUser ? Colors.white : AppColors.deepBrown,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (message.listings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...message.listings.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ListingResultCard(
                  item: item,
                  onTap: () => onListingTap(item),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListingResultCard extends StatelessWidget {
  const _ListingResultCard({
    required this.item,
    required this.onTap,
  });

  final Animal item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = NumberFormat.compactCurrency(
      locale: context.l10n.localeTag,
      decimalDigits: 0,
      symbol: 'ETB ',
    ).format(item.price);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: .06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item.coverPhoto,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: AppColors.background,
                    child: const Icon(Icons.image_not_supported_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.breed?.isNotEmpty == true
                          ? item.breed!
                          : item.animalType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepBrown,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.animalType,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.location != null &&
                        item.location!.trim().isNotEmpty)
                      Text(
                        item.location!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }
}
