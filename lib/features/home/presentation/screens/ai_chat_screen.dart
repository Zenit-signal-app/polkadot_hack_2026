import 'package:flutter/material.dart';

import '../widgets/section_placeholder.dart';

class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionPlaceholder(
      title: 'Ai Chat',
      subtitle: 'Start a conversation with the assistant.',
      icon: Icons.chat_bubble,
    );
  }
}
