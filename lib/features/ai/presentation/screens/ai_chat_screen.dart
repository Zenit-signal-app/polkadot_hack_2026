import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/store/chat_store.dart';
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
  static const _kNewChat = 'New chat';

  final OpenAIRepository _openAIRepository = OpenAIRepository();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String _streamingContent = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final chatStore = context.read<ChatStore>();

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    await chatStore.addMessage(userMessage);

    // Auto-generate category name after the first user message
    final activeIdx = chatStore.state.activeCategoryIndex;
    final activeCategory = chatStore.state.activeCategory;
    if (activeCategory != null &&
        activeCategory.name == _kNewChat &&
        activeCategory.messages
                .where((m) => m.role == MessageRole.user)
                .length ==
            1) {
      // Fire-and-forget: don't block the UI
      _openAIRepository.generateCategoryName(text).then((name) {
        if (mounted) {
          context.read<ChatStore>().renameCategory(activeIdx, name);
        }
      });
    }

    setState(() {
      _isLoading = true;
      _streamingContent = '';
    });
    _scrollToBottom();

    try {
      // Build conversation history from current category messages
      final history = List<ChatMessage>.from(
        chatStore.state.activeMessages,
      );

      final assistantMessage = await _openAIRepository.streamMessage(
        message: text,
        conversationHistory: history,
        onChunk: (chunk) {
          setState(() {
            _streamingContent = chunk;
          });
        },
      );

      await chatStore.addMessage(assistantMessage);
      setState(() {
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

      await chatStore.addMessage(errorMessage);
      setState(() {
        _streamingContent = '';
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  /// Instantly create a new "New chat" category (name auto-generated later by AI)
  Future<void> _createNewCategory() async {
    final chatStore = context.read<ChatStore>();
    // Reuse existing empty "New chat" if already present
    final existingIdx = chatStore.state.categories
        .indexWhere((c) => c.name == _kNewChat && c.messages.isEmpty);
    if (existingIdx != -1) {
      chatStore.selectCategory(existingIdx);
    } else {
      await chatStore.addCategory(_kNewChat);
    }
  }

  void _showCategoryMenu(BuildContext context, ChatState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1E35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.gray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chat history',
                  style: TextStyle(
                    color: AppColors.gray,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            ...List.generate(state.categories.length, (i) {
              final cat = state.categories[i];
              final isActive = i == state.activeCategoryIndex;
              final msgCount = cat.messages.length;
              return ListTile(
                leading: Icon(
                  HugeIcons.strokeRoundedMessage01,
                  color: isActive ? AppColors.blue : AppColors.gray,
                  size: 20,
                ),
                title: Text(
                  cat.name,
                  style: TextStyle(
                    color: isActive ? AppColors.blue : AppColors.white,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                subtitle: msgCount > 0
                    ? Text(
                        '$msgCount message${msgCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: AppColors.gray,
                          fontSize: 11,
                        ),
                      )
                    : null,
                trailing: state.categories.length > 1
                    ? IconButton(
                        icon: const Icon(
                          HugeIcons.strokeRoundedDelete01,
                          size: 18,
                          color: AppColors.gray,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.read<ChatStore>().deleteCategory(i);
                        },
                      )
                    : null,
                onTap: () {
                  context.read<ChatStore>().selectCategory(i);
                  Navigator.of(context).pop();
                },
              );
            }),
            const Divider(color: Color(0xFF1E2D45), height: 1),
            ListTile(
              leading: const Icon(
                HugeIcons.strokeRoundedAdd01,
                color: AppColors.blue,
                size: 20,
              ),
              title: const Text(
                'New chat',
                style: TextStyle(color: AppColors.blue),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _createNewCategory();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatStore, ChatState>(
      builder: (context, state) {
        final messages = state.activeMessages.reversed.toList();

        return Scaffold(
          backgroundColor: const Color(0xFF0A1628),
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, state),
                Expanded(
                  child: messages.isEmpty && !_isLoading
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
                          itemCount: messages.length +
                              (_isLoading && _streamingContent.isNotEmpty
                                  ? 1
                                  : 0),
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

                            final msgIndex =
                                _isLoading && _streamingContent.isNotEmpty
                                    ? index - 1
                                    : index;

                            return ChatMessageBubble(
                              message: messages[msgIndex],
                            );
                          },
                        ),
                ),
                ChatInput(
                  onSend: _handleSendMessage,
                  isLoading: _isLoading,
                  categoryName: state.activeCategory?.name == _kNewChat
                      ? 'Ask AI'
                      : state.activeCategory?.name,
                  onCategoryTap: () => _showCategoryMenu(context, state),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavBar(
            currentIndex: 2,
            onTap: (index) {
              if (index == 2) return;
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
                case 3:
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.news,
                    (route) => false,
                  );
                  break;
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ChatState state) {
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
              fontSize: 15,
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
          // Clear active category messages
          IconButton(
            onPressed: state.activeMessages.isEmpty
                ? null
                : () => context.read<ChatStore>().clearActiveCategory(),
            icon: const Icon(HugeIcons.strokeRoundedDelete01),
            color: state.activeMessages.isEmpty
                ? AppColors.gray
                : AppColors.white,
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
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
