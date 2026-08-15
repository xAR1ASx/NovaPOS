import 'package:flutter/material.dart';
import '../services/permission_service.dart';

class PermissionGate extends StatelessWidget {
  final String permission;
  final Widget child;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (PermissionService.can(permission)) {
      return child;
    }

    return const SizedBox.shrink();
  }
}
