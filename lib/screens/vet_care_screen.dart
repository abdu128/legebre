import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/vet_drug.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/vet_drug_card.dart';
import 'add_vet_drug_screen.dart';
import 'vet_drug_detail_screen.dart';
import '../utils/seller_guard.dart';

class VetCareScreen extends StatefulWidget {
  const VetCareScreen({super.key});

  @override
  State<VetCareScreen> createState() => _VetCareScreenState();
}

class _VetCareScreenState extends State<VetCareScreen> {
  late Future<List<VetDrug>> _drugsFuture;
  final _searchController = TextEditingController();
  String _searchTerm = '';
  String _statusFilter = 'ALL';

  static const _statusOptions = [
    _StatusFilterOption('ALL', 'All supplies'),
    _StatusFilterOption('AVAILABLE', 'Available'),
    _StatusFilterOption('LOW_STOCK', 'Low stock'),
    _StatusFilterOption('OUT_OF_STOCK', 'Out of stock'),
  ];

  @override
  void initState() {
    super.initState();
    _drugsFuture = _loadDrugs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<VetDrug>> _loadDrugs() async {
    final api = context.read<AppState>().api;
    final filters = <String, dynamic>{};
    if (_searchTerm.isNotEmpty) filters['q'] = _searchTerm;
    if (_statusFilter != 'ALL') filters['status'] = _statusFilter;
    return api.getVetDrugs(filters: filters);
  }

  Future<void> _refresh() async {
    setState(() {
      _drugsFuture = _loadDrugs();
    });
    await _drugsFuture;
  }

  void _applySearch(String value) {
    setState(() {
      _searchTerm = value.trim();
      _drugsFuture = _loadDrugs();
    });
  }

  Future<void> _openAddListing() async {
    final allowed = await SellerGuard.ensureSeller(context);
    if (!allowed) return;
    final shouldRefresh = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddVetDrugScreen()));
    if (shouldRefresh == true && mounted) {
      _refresh();
    }
  }

  void _openDetail(VetDrug drug) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => VetDrugDetailScreen(item: drug)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddListing,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('Add vet listing')),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Vet Care'),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          // const Spacer(),
                          // IconButton(
                          //   tooltip: context.tr('Refresh'),
                          //   onPressed: _refresh,
                          //   icon: const Icon(Icons.refresh_rounded),
                          // ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _EmergencyCard(theme: theme),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _searchController,
                        onSubmitted: _applySearch,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: context.tr(
                            'Search vaccines, antibiotics, vitamins...',
                          ),
                          suffixIcon: _searchTerm.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _applySearch('');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _statusOptions.map((option) {
                            final isSelected = _statusFilter == option.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(context.tr(option.label)),
                                selected: isSelected,
                                onSelected: (_) {
                                  setState(() {
                                    _statusFilter = option.value;
                                    _drugsFuture = _loadDrugs();
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              FutureBuilder<List<VetDrug>>(
                future: _drugsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('Unable to load vet supplies'),
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
                    );
                  }
                  final drugs = snapshot.data ?? const <VetDrug>[];
                  if (drugs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: EmptyState(
                          icon: Icons.medical_services_outlined,
                          title: context.tr('No vet supplies yet'),
                          description: context.tr(
                            'Licensed pharmacists will list their products here soon.',
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 320,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: .72,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = drugs[index];
                        return VetDrugCard(
                          item: item,
                          onTap: () => _openDetail(item),
                        );
                      }, childCount: drugs.length),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.theme});

  final ThemeData theme;
  static const _hotlineNumber = '+251 911 123 456';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minWidth: double.infinity),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accentBlue, AppColors.accentPurple],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBlue.withValues(alpha: .25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Verified medical supplies & pharmacists'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'Licensed pharmacists will list their products here soon.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // const SizedBox(height: 20),
          // _InfoRow(
          //   icon: Icons.inventory_2_rounded,
          //   label: context.tr('Contact coming soon'),
          // ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.medical_services_rounded,
            label: context.tr('Verified sellers only'),
          ),
          // const SizedBox(height: 10),
          // Text(
          //   '${context.tr('Emergency hotline')}: ${context.tr(_hotlineNumber)}',
          //   style: theme.textTheme.bodyMedium?.copyWith(
          //     color: Colors.white,
          //     fontWeight: FontWeight.w600,
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusFilterOption {
  const _StatusFilterOption(this.value, this.label);

  final String value;
  final String label;
}
