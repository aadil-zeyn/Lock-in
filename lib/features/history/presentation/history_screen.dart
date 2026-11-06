import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      title: 'History',
      children: [
        EmptyState(
          icon: Icons.history_rounded,
          title: 'Nothing logged yet',
          message: 'Finished workouts appear here, newest first.',
        ),
      ],
    );
  }
}
