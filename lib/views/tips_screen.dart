import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  // External JSON data
  List<Map<String, dynamic>> _externalTips = [];
  bool _isLoadingExternal = true;

  // Internal/Local JSON data
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
    // Check connectivity
    final online = await _apiService.isOnline();
    if (mounted) setState(() => _isOnline = online);

    // Load external JSON from internet
    _loadExternalJson();

    // Load internal/local JSON from assets
    _loadLocalJson();
  }

  // ── Load from External JSON URL ──────────────────────────────
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

  // ── Load from Internal Local JSON file ───────────────────────
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Tips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBothSources,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(
              icon: Icon(Icons.cloud_download, size: 18),
              text: 'External JSON',
            ),
            Tab(
              icon: Icon(Icons.storage, size: 18),
              text: 'Local JSON',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: External JSON ───────────────────────────
          _buildExternalJsonTab(theme),
          // ── Tab 2: Local JSON ──────────────────────────────
          _buildLocalJsonTab(theme),
        ],
      ),
    );
  }

  // ── External JSON Tab ────────────────────────────────────────
  Widget _buildExternalJsonTab(ThemeData theme) {
    return Column(
      children: [
        // Source info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: _isOnline
              ? AppTheme.primaryGreen.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          child: Row(
            children: [
              Icon(
                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                size: 18,
                color: _isOnline
                    ? AppTheme.primaryGreen
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnline
                          ? '🌐 External JSON API'
                          : '⚠️ Offline — Cannot load external JSON',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isOnline
                            ? AppTheme.primaryGreen
                            : Colors.orange,
                      ),
                    ),
                    Text(
                      'https://jsonplaceholder.typicode.com/posts',
                      style: TextStyle(
                        fontSize: 10,
                        color: _isOnline
                            ? AppTheme.primaryGreen.withOpacity(0.7)
                            : Colors.orange.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoadingExternal
              ? const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryGreen,
            ),
          )
              : !_isOnline
              ? _buildOfflineState()
              : _externalTips.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
            onRefresh: _loadExternalJson,
            color: AppTheme.primaryGreen,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _externalTips.length,
              itemBuilder: (context, index) {
                return _TipCard(
                  tip: _externalTips[index],
                  index: index,
                  isExternal: true,
                  onTap: () => _showDetail(
                    context,
                    _externalTips[index],
                    true,
                  ),
                )
                    .animate()
                    .fadeIn(
                  delay: Duration(
                      milliseconds: index * 80),
                )
                    .slideX(begin: 0.2, end: 0);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Local JSON Tab ───────────────────────────────────────────
  Widget _buildLocalJsonTab(ThemeData theme) {
    return Column(
      children: [
        // Source info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.blue.withOpacity(0.1),
          child: Row(
            children: [
              const Icon(
                Icons.storage,
                size: 18,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📱 Internal Local JSON File',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      'assets/json/app_data.json (stored in app)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Text(
                  '✅ Works Offline',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoadingLocal
              ? const Center(
            child: CircularProgressIndicator(
              color: Colors.blue,
            ),
          )
              : _localTips.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _localTips.length,
            itemBuilder: (context, index) {
              return _TipCard(
                tip: _localTips[index],
                index: index,
                isExternal: false,
                onTap: () => _showDetail(
                  context,
                  _localTips[index],
                  false,
                ),
              )
                  .animate()
                  .fadeIn(
                delay: Duration(
                    milliseconds: index * 80),
              )
                  .slideX(begin: -0.2, end: 0);
            },
          ),
        ),
      ],
    );
  }

  // ── Master/Detail Bottom Sheet ───────────────────────────────
  void _showDetail(
      BuildContext context,
      Map<String, dynamic> tip,
      bool isExternal,
      ) {
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

                // Source badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isExternal
                        ? AppTheme.primaryGreen.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isExternal
                          ? AppTheme.primaryGreen
                          : Colors.blue,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExternal ? Icons.cloud : Icons.storage,
                        size: 14,
                        color: isExternal
                            ? AppTheme.primaryGreen
                            : Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isExternal
                            ? '🌐 External JSON API'
                            : '📱 Local JSON File',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isExternal
                              ? AppTheme.primaryGreen
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isExternal
                        ? AppTheme.primaryGreen.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lightbulb,
                    color: isExternal
                        ? AppTheme.primaryGreen
                        : Colors.blue,
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

                if (isExternal) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryGreen,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This data was fetched from an external JSON API on the internet',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.storage,
                          color: Colors.blue,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This data was read from a local JSON file stored inside the app (works offline!)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
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

  // ── Offline State ────────────────────────────────────────────
  Widget _buildOfflineState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(Icons.cloud_off, size: 64, color: Colors.orange[300]),
            const SizedBox(height: 16),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'External JSON cannot be loaded.\nSwitch to Local JSON tab to see offline data.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBothSources,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
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
            'No data available',
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
  final bool isExternal;
  final VoidCallback onTap;

  const _TipCard({
    required this.tip,
    required this.index,
    required this.isExternal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isExternal ? AppTheme.primaryGreen : Colors.blue;

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
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: color,
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
                    // Source tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isExternal
                            ? '🌐 External JSON'
                            : '📱 Local JSON',
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
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
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}