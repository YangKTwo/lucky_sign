import 'dart:typed_data';

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

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.nickname,
    this.avatarUrl,
    this.radius = 20,
    this.backgroundColor,
  });

  final String? nickname;
  final String? avatarUrl;
  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final url = imageFullUrl(avatarUrl);
    final bg = backgroundColor ?? AppColors.moss;
    final letter = Text(
      avatarLetter(nickname),
      style: TextStyle(color: Colors.white, fontSize: radius * 0.85, fontWeight: FontWeight.w800),
    );
    if (url.isEmpty) {
      return CircleAvatar(radius: radius, backgroundColor: bg, child: letter);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: ColoredBox(color: bg, child: Center(child: letter)),
          ),
        ),
      ),
    );
  }
}

class NetworkImageBox extends StatelessWidget {
  const NetworkImageBox({
    super.key,
    required this.url,
    this.height = 160,
    this.width = double.infinity,
    this.borderRadius = 12,
  });

  final String url;
  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        height: height,
        width: width,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: height,
            width: width,
            alignment: Alignment.center,
            color: const Color(0xFFF3EEE7),
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          height: height,
          width: width,
          alignment: Alignment.center,
          color: const Color(0xFFF3EEE7),
          child: const Text('图片加载失败', style: TextStyle(color: Color(0xFF8A8078), fontSize: 12)),
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry, this.hint});
  final String message;
  final VoidCallback onRetry;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFC0392B), height: 1.4)),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8A8078), height: 1.4)),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7DDD2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.moss, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF8A8078), height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB0A69C)),
            ],
          ),
        ),
      ),
    );
  }
}

class LocalImagePreview extends StatelessWidget {
  const LocalImagePreview({super.key, required this.bytes, this.height = 140});
  final Uint8List bytes;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(bytes, height: height, width: double.infinity, fit: BoxFit.cover),
    );
  }
}
