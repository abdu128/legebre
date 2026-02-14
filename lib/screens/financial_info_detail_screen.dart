import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/financial_info.dart';
import '../state/app_state.dart';

class FinancialInfoDetailScreen extends StatefulWidget {
  const FinancialInfoDetailScreen({
    super.key,
    required this.infoId,
    this.initial,
  });

  final int infoId;
  final FinancialInfo? initial;

  @override
  State<FinancialInfoDetailScreen> createState() =>
      _FinancialInfoDetailScreenState();
}

class _FinancialInfoDetailScreenState extends State<FinancialInfoDetailScreen> {
  late Future<FinancialInfo> _detailFuture;
  FinancialInfo? _cached;

  @override
  void initState() {
    super.initState();
    _cached = widget.initial;
    _detailFuture = _loadDetail();
  }

  Future<FinancialInfo> _loadDetail() async {
    final api = context.read<AppState>().api;
    final detail = await api.getFinancialInfo(widget.infoId);
    setState(() => _cached = detail);
    return detail;
  }

  Future<void> _refresh() async {
    setState(() {
      _detailFuture = _loadDetail();
    });
    await _detailFuture;
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Finance information'))),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<FinancialInfo>(
            future: _detailFuture,
            initialData: _cached,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: CircularProgressIndicator()),
                    ],
                  );
                }
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off, size: 48),
                          const SizedBox(height: 12),
                          Text(context.tr('Unable to load this update')),
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
              final info = snapshot.data!;
              final dateText = DateFormat.yMMMMd().add_jm().format(
                info.createdAt,
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    info.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryGreen.withValues(
                          alpha: .15,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              info.publisher,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              dateText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    info.content,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  if (info.attachmentUrl != null &&
                      info.attachmentUrl!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      context.tr('Attachment'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openAttachment(info.attachmentUrl!),
                      icon: const Icon(Icons.attach_file),
                      label: Text(context.tr('Open document')),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
