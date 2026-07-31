import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBarHelpButton extends StatelessWidget {
  const AppBarHelpButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Kullanım Kılavuzu',
    icon: const Icon(Icons.help_outline),
    onPressed: () => context.push('/help'),
  );
}
