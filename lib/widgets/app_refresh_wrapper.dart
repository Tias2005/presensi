import 'package:flutter/material.dart';
import '../shared/theme.dart';

class AppRefreshWrapper extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;

  const AppRefreshWrapper({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: color ?? AppColors.primary,
      backgroundColor: Colors.white,
      onRefresh: onRefresh,
      child: child,
    );
  }
}