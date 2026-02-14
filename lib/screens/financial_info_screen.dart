import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/financial_info.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import 'financial_info_detail_screen.dart';

class FinancialInfoScreen extends StatefulWidget {
  const FinancialInfoScreen({super.key});

  @override
  State<FinancialInfoScreen> createState() => _FinancialInfoScreenState();
}

class _FinancialInfoScreenState extends State<FinancialInfoScreen> {
  late Future<List<FinancialInfo>> _infoFuture;

  @override
  void initState() {
    super.initState();
    _infoFuture = _loadInfos();
  }

  Future<List<FinancialInfo>> _loadInfos() async {
    final api = context.read<AppState>().api;
    return api.getFinancialInfos();
  }

  Future<void> _refresh() async {
    setState(() {
      _infoFuture = _loadInfos();
    });
    await _infoFuture;
  }

  void _openDetail(FinancialInfo info) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            FinancialInfoDetailScreen(infoId: info.id, initial: info),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Finance information'))),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<FinancialInfo>>(
            future: _infoFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: CircularProgressIndicator()),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('Unable to load financial updates'),
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
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
              final infos = snapshot.data ?? const <FinancialInfo>[];
              if (infos.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: context.tr('No financial news yet'),
                      description: context.tr(
                        'Savings groups and banks will publish their updates here soon.',
                      ),
                    ),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                itemCount: infos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final info = infos[index];
                  final relativeDate = DateFormat.yMMMMd().add_jm().format(
                    info.createdAt,
                  );
                  return GestureDetector(
                    onTap: () => _openDetail(info),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .04),
                            blurRadius: 20,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  info.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (info.attachmentUrl != null)
                                Icon(
                                  Icons.attach_file,
                                  color: AppColors.primaryGreen,
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            info.summary.isNotEmpty
                                ? info.summary
                                : info.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primaryGreen
                                    .withValues(alpha: .15),
                                child: const Icon(
                                  Icons.campaign_rounded,
                                  color: AppColors.primaryGreen,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      info.publisher,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      relativeDate,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                context.tr('Read update'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.primaryGreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
