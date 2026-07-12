import 'package:flutter/material.dart';
import '../config/theme.dart';

class CustomHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;

  const CustomHeader({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.appBarColor,
      ),
      child: Row(
        children: [
          if (showBack) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack ?? () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
