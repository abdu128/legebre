import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../models/vet_drug.dart';
import '../state/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/vet_drug_card.dart';
import 'add_vet_drug_screen.dart';
import 'vet_drug_detail_screen.dart';

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
        label: const Text('Add vet listing'),
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
                                'Vet care',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Verified medical supplies & pharmacists',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
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
                          hintText: 'Search vaccines, antibiotics, vitamins...',
                          suffixIcon: _searchTerm.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _applySearch('');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : IconButton(
                                  onPressed: () =>
                                      _applySearch(_searchController.text),
                                  icon: const Icon(Icons.tune_rounded),
                                ),
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
                                label: Text(option.label),
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
                              'Unable to load vet supplies',
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _refresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final drugs = snapshot.data ?? const <VetDrug>[];
                  if (drugs.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: EmptyState(
                          icon: Icons.medical_services_outlined,
                          title: 'No vet supplies yet',
                          description:
                              'Licensed pharmacists will list their products here soon.',
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Icon(Icons.monitor_heart, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(
            'Emergency hotline',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '+251 911 123 456',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.accentBlue,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.call_rounded),
            label: const Text('Call now'),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterOption {
  const _StatusFilterOption(this.value, this.label);

  final String value;
  final String label;
}
