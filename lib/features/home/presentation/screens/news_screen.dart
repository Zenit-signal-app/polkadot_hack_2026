import 'package:flutter/material.dart';

import '../widgets/section_placeholder.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionPlaceholder(
      title: 'News',
      subtitle: 'Latest updates and signals coverage.',
      icon: Icons.article,
    );
  }
}
