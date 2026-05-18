import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _tips = [];
  bool _isLoading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    setState(() => _isLoading = true);
    final online = await _apiService.isOnline();
    final tips = await _apiService.getTipsFromApi();
    if (mounted) {
      setState(() {
        _tips = tips;
        _isOnline = online;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Tips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTips,
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Online/Offline Banner ────────────────────────
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.orange,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Offline — Showing local data',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // ── Source Banner ────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            color: _isOnline
                ? AppTheme.primaryGreen.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  _isOnline ? Icons.cloud_done : Icons.storage,
                  size: 16,
                  color: _isOnline
                      ? AppTheme.primaryGreen
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  _isOnline
                      ? 'Data loaded from external JSON API'
                      : 'Data loaded from local JSON file',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isOnline
                        ? AppTheme.primaryGreen
                        : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ── Tips List ────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
              ),
            )
                : _tips.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadTips,
              color: AppTheme.primaryGreen,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tips.length,
                itemBuilder: (context, index) {
                  return _TipCard(
                    tip: _tips[index],
                    index: index,
                    onTap: () => _showDetail(
                      context,
                      _tips[index],
                    ),
                  )
                      .animate()
                      .fadeIn(
                    delay: Duration(
                      milliseconds: index * 80,
                    ),
                  )
                      .slideX(begin: 0.2, end: 0);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Master/Detail Bottom Sheet ───────────────────────────────
  void _showDetail(BuildContext context, Map<String, dynamic> tip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb,
                    color: AppTheme.primaryGreen,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  tip['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Source badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tip['source'] == 'online'
                        ? '🌐 From External JSON API'
                        : '📱 From Local JSON File',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Description
                Text(
                  tip['description'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No tips available',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ── Tip Card Widget ──────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final Map<String, dynamic> tip;
  final int index;
  final VoidCallback onTap;

  const _TipCard({
    required this.tip,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Number badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip['title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tip['description'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Arrow
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}