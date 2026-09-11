import 'package:flutter/material.dart';
import '../services/locale_service.dart';
import '../services/permission_service.dart';

// ignore: unused_element
String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {};

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
