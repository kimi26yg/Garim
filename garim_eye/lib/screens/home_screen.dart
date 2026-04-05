import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/security_card.dart';
import 'dial_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _ContactsTab(),
    DialScreen(),
    _RecentsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가림-아이'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: 'Dial'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Recents'),
        ],
      ),
    );
  }
}

class _ContactsTab extends ConsumerWidget {
  const _ContactsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const SecurityCard(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('Contacts', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('View All')),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildContactTile(
                context,
                name: '강혜린',
                role: '팀장님',
                avatarColor: Colors.blueAccent,
              ),
              const SizedBox(height: 12),
              _buildContactTile(
                context,
                name: '최은선',
                role: '팀원',
                avatarColor: Colors.purpleAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile(
    BuildContext context, {
    required String name,
    required String role,
    required Color avatarColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surface.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: avatarColor.withValues(alpha: 0.2),
          child: Text(
            name[0],
            style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          role,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        trailing: ElevatedButton.icon(
          onPressed: () {
            context.go('/calling');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            foregroundColor: AppTheme.primary,
            elevation: 0,
            side: const BorderSide(color: AppTheme.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.call, size: 18),
          label: const Text('안심 통화'),
        ),
      ),
    );
  }
}

class _RecentsTab extends ConsumerWidget {
  const _RecentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(callHistoryProvider);

    if (history.isEmpty) {
      return const Center(child: Text('No recent calls'));
    }

    return ListView.builder(
      itemCount: history.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final record = history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.surface,
              child: const Icon(Icons.videocam, color: AppTheme.textSecondary),
            ),
            title: Text(
              record.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${_formatTimestamp(record.timestamp)} • ${record.role}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            trailing: record.isScanned
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'Deepfake Scanned',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            onTap: () => context.go('/calling'),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}
