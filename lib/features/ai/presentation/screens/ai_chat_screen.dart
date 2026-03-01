import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/widgets/layout/bottom_nav_bar.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/openai_repository.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_message_bubble.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final OpenAIRepository _openAIRepository = OpenAIRepository();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String _streamingContent = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.insert(0, userMessage);
      _isLoading = true;
      _streamingContent = '';
    });

    _scrollToBottom();

    try {
      // Get conversation history (last 10 messages for context)
      final history = _messages.reversed.take(10).toList();

      // Send message with streaming
      final assistantMessage = await _openAIRepository.streamMessage(
        message: text,
        conversationHistory: history,
        onChunk: (chunk) {
          setState(() {
            _streamingContent = chunk;
          });
        },
      );

      setState(() {
        _messages.insert(0, assistantMessage);
        _streamingContent = '';
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      final errorMessage = ChatMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        content: 'Sorry, I encountered an error: ${e.toString()}',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        isError: true,
      );

      setState(() {
        _messages.insert(0, errorMessage);
        _streamingContent = '';
        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.only(
                        top: 16,
                        bottom: 16,
                        left: 20,
                        right: 20,
                      ),
                      itemCount: _messages.length +
                          (_isLoading && _streamingContent.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 0 &&
                            _isLoading &&
                            _streamingContent.isNotEmpty) {
                          return ChatMessageBubble(
                            message: ChatMessage(
                              id: 'streaming',
                              content: _streamingContent,
                              role: MessageRole.assistant,
                              timestamp: DateTime.now(),
                            ),
                          );
                        }

                        final messageIndex =
                            _isLoading && _streamingContent.isNotEmpty
                                ? index - 1
                                : index;

                        return ChatMessageBubble(
                          message: _messages[messageIndex],
                        );
                      },
                    ),
            ),
            ChatInput(
              onSend: _handleSendMessage,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          if (index == 3) return;

          switch (index) {
            case 0:
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.home,
                (route) => false,
              );
              break;
            case 1:
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.analysis,
                (route) => false,
              );
              break;
            case 2:
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.news,
                (route) => false,
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.home,
                (route) => false,
              );
            },
            icon: const Icon(HugeIcons.strokeRoundedMenu02),
            color: AppColors.white,
          ),
          const SizedBox(width: 4),
          const Text(
            'AI Chatbot',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 30 / 2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.search);
            },
            icon: const Icon(HugeIcons.strokeRoundedSearch01),
            color: AppColors.white,
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: _messages.isEmpty ? null : _clearChat,
                icon: const Icon(HugeIcons.strokeRoundedNotification03),
                color: AppColors.white,
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE02424),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(32, 90, 32, 0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          'Let\'s start with Zenit AI\nby asking a question\nabout the market today',
          style: TextStyle(
            color: Color(0xFFB9BDC7),
            fontSize: 44 / 2,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
