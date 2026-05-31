import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  StreamSubscription? _connectivitySubscription;

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
    _initConnectivityListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // Automatically handle internet connection changes
  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final bool currentlyOnline = !results.contains(ConnectivityResult.none);
      
      if (currentlyOnline != _isOnline) {
        if (mounted) {
          setState(() {
            _isOnline = currentlyOnline;
            if (!currentlyOnline) {
              // Requirement: Clear external data when offline
              _externalTips = [];
              _isLoadingExternal = false;
            }
          });
        }
        
        if (currentlyOnline) {
          // Requirement: Automatically reload when internet returns
          _loadExternalJson();
        }
      }
    });
  }

  Future<void> _loadBothSources() async {
    final online = await _apiService.isOnline();
    if (mounted) {
      setState(() {
        _isOnline = online;
        if (!online) {
          _externalTips = [];
          _isLoadingExternal = false;
        }
      });
    }

    if (online) {
      _loadExternalJson();
    }
    _loadLocalJson();
  }

  Future<void> _loadExternalJson() async {
    if (!_isOnline) return;
    
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

  // Load from Internal Local JSON file (Practical Tips)
  Future<void> _loadLocalJson() async {
    setState(() => _isLoadingLocal = true);
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/json/app_data.json',
      );
      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> tipsData = data['tips'] as List<dynamic>? ?? [];

      final tips = tipsData.map((tip) {
        return {
          'id': tip['id']?.toString() ?? '',
          'title': tip['title']?.toString() ?? '',
          'description': tip['description']?.toString() ?? '',
          'source': 'local',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _localTips = tips;
          _isLoadingLocal = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Fallback static data if file read fails
          _localTips = [
            {
              'id': '1',
              'title': '50/30/20 Rule',
              'description': 'Spend 50% on needs, 30% on wants and save 20% every month.',
              'source': 'local',
            },
            {
              'id': '2',
              'title': 'Track Daily Spending',
              'description': 'Record every expense no matter how small to spot bad habits.',
              'source': 'local',
            },
          ];
          _isLoadingLocal = false;
        });
      }
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
    return Column(
      children: [
        // ── MAD Requirement Demonstration Banners ──
        if (isExternal) 
          _isOnline 
            ? _buildInfoBanner(
                icon: Icons.public,
                title: '🌐 External JSON Data',
                subtitle: 'Loaded from Internet API',
                color: Colors.green,
              )
            : _buildInfoBanner(
                icon: Icons.cloud_off,
                title: '⚠️ No Internet Connection',
                subtitle: 'External JSON unavailable\nSwitch to Practical Tips to view local JSON data',
                color: Colors.orange,
              )
        else 
          _buildInfoBanner(
            icon: Icons.storage,
            title: '📱 Local JSON File',
            subtitle: 'Source: assets/json/app_data.json\nWorks Offline',
            color: Colors.blue,
          ),

        Expanded(
          child: (isExternal && !_isOnline)
              ? _buildExternalOfflineEmptyState()
              : isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : tips.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
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
                        ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExternalOfflineEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'No External Data Available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Connect to the internet to load\nMarket Insights from the external JSON API.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildEmptyState() {
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
              const SizedBox(height: 20),
              
              // ── Source Label ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isExternal ? Colors.green : Colors.blue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isExternal ? "Source: External JSON API" : "Source: Local JSON File",
                  style: TextStyle(
                    color: isExternal ? Colors.green : Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
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
