import 'package:firbird/app/app_config.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String currentRoute = GoRouterState.of(context).uri.path;

    return Drawer(
      child: Column(
        children: [
          // ── Drawer Header ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/logo/firbird_logo.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FirBird',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          AppConfig.fullVersion,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Aktif Paket: Türkiye 0.1.0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Menu List Items ──────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                _DrawerTile(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  title: 'Ana Sayfa',
                  isSelected: currentRoute == '/',
                  onTap: () => _navigate(context, '/'),
                ),
                _DrawerTile(
                  icon: Icons.mic_none_outlined,
                  activeIcon: Icons.mic,
                  title: 'Canlı Ses Tespiti',
                  isSelected: currentRoute == '/live_audio',
                  onTap: () => _navigate(context, '/live_audio'),
                ),
                _DrawerTile(
                  icon: Icons.music_note_outlined,
                  activeIcon: Icons.music_note,
                  title: 'Ses oynatıcı',
                  isSelected: currentRoute == '/player',
                  onTap: () => _navigate(context, '/player'),
                ),
                _DrawerTile(
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  title: 'Son Tanımlamalar',
                  isSelected: currentRoute == '/history',
                  onTap: () => _navigate(context, '/history'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(height: 1),
                ),
                _DrawerTile(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2,
                  title: 'Bölge Paketleri',
                  isSelected: currentRoute == '/packages',
                  onTap: () => _navigate(context, '/packages'),
                ),
                _DrawerTile(
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map,
                  title: 'Yakınımdaki Kuşlar',
                  isSelected: currentRoute == '/explore',
                  onTap: () => _navigate(context, '/explore'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(height: 1),
                ),
                _DrawerTile(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  title: 'Ayarlar',
                  isSelected: currentRoute == '/settings',
                  onTap: () => _navigate(context, '/settings'),
                ),
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'FirBird · Yapay Zeka Kuş Gözlemcisi',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String path) {
    Navigator.pop(context); // Close drawer
    final String current = GoRouterState.of(context).uri.path;
    if (current != path) {
      if (path == '/') {
        context.go('/');
      } else {
        context.push(path);
      }
    }
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.activeIcon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        selected: isSelected,
        selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
