import 'package:flutter/material.dart';

import '../services/chat_inbox.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'rank_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Widget _communityIcon({required bool selected}) {
    return ValueListenableBuilder<List<int>>(
      valueListenable: ChatInbox.instance.unreadIds,
      builder: (_, ids, __) {
        final count = ids.length;
        final icon = Icon(
          selected ? Icons.forum : Icons.forum_outlined,
          color: selected ? AppColors.accent : null,
        );
        if (count <= 0) return icon;
        final label = count > 99 ? '99+' : '$count';
        return Badge(
          label: Text(label),
          child: icon,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const TodayScreen(),
          ChatScreen(isActive: _index == 1),
          const RankScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.auto_awesome),
            selectedIcon: Icon(Icons.auto_awesome, color: AppColors.accent),
            label: '今日',
          ),
          NavigationDestination(
            icon: _communityIcon(selected: false),
            selectedIcon: _communityIcon(selected: true),
            label: '社区',
          ),
          const NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events, color: AppColors.accent),
            label: '排行',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.accent),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
