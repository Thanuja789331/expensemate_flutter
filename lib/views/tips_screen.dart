import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<Map<String, dynamic>> _externalTips = [];
  bool _isLoadingExternal = true;

  List<Map<String, dynamic>> _localTips = [];
  bool _isLoadingLocal = true;

  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBothSources();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBothSources() async {
    final online = await _apiService.isOnline();
    if (mounted) setState(() => _isOnline = online);

    _loadExternalJson();
    _loadLocalJson();
  }

  Future<void> _loadExternalJson() async {
    setState(() => _isLoadingExternal = true);
    try {
      final tips = await _apiService.getTipsFromApi();
      if (mounted) {
        setState(() {
          _externalTips = tips;
          _isLoadingExternal = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingExternal = false);
    }
  }

  Future<void> _loadLocalJson() async {
    setState(() => _isLoadingLocal = true);
    try {
      final tips = await _apiService.getLocalTips();
      if (mounted) {
        setState(() {
          _localTips = tips;
          _isLoadingLocal = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Wisdom'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Market Insights'),
            Tab(text: 'Practical Tips'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTipsTab(_externalTips, _isLoadingExternal, true),
          _buildTipsTab(_localTips, _isLoadingLocal, false),
        ],
      ),
    );
  }

  Widget _buildTipsTab(List<Map<String, dynamic>> tips, bool isLoading, bool isExternal) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No tips available at the moment', style: TextStyle(color: Colors.grey)),
            TextButton(onPressed: _loadBothSources, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBothSources,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        itemBuilder: (context, index) {
          final tip = tips[index];
          return _TipCard(
            tip: tip,
            index: index,
            color: isExternal ? AppTheme.primaryGreen : Colors.blue,
            onTap: () => _showDetail(context, tip, isExternal),
          ).animate().fadeIn(delay: Duration(milliseconds: index * 50)).slideY(begin: 0.1, end: 0);
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> tip, bool isExternal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: (isExternal ? AppTheme.primaryGreen : Colors.blue).withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.auto_awesome, color: isExternal ? AppTheme.primaryGreen : Colors.blue, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      tip['title'] ?? 'Financial Tip',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                tip['description'] ?? '',
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final Map<String, dynamic> tip;
  final int index;
  final Color color;
  final VoidCallback onTap;

  const _TipCard({required this.tip, required this.index, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Center(
                  child: Text('${index + 1}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(tip['description'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}