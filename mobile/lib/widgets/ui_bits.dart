import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';

String avatarLetter(String? name) {
  final s = (name ?? '').trim();
  if (s.isEmpty) return '?';
  return s.characters.first;
}

String imageFullUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  return '$apiBaseUrl$path';
}

class TagChip extends StatelessWidget {
  const TagChip(this.tag, {super.key});
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final label = AppColors.tagLabel(tag);
    if (label.isEmpty) return const SizedBox.shrink();
    final dormant = tag == 'DORMANT';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dormant ? const Color(0xFF5C5C5C) : const Color(0xFFE07A3D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7DDD2)),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8A8078))),
          ],
        ),
      ),
    );
  }
}
