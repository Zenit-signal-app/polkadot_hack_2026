import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/chat_message_model.dart';

class OpenAIRepository {
  OpenAIRepository() {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey.contains('your_openai_api_key_here')) {
      throw StateError(
          'Please add a valid OPENAI_API_KEY to the .env file');
    }
    OpenAI.apiKey = apiKey;
  }

  Future<ChatMessage> sendMessage({
    required String message,
    List<ChatMessage>? conversationHistory,
  }) async {
    try {
      final messages = [
        if (conversationHistory != null)
          ...conversationHistory.map((msg) => OpenAIChatCompletionChoiceMessageModel(
                role: msg.role == MessageRole.user
                    ? OpenAIChatMessageRole.user
                    : OpenAIChatMessageRole.assistant,
                content: [
                  OpenAIChatCompletionChoiceMessageContentItemModel.text(
                    msg.content,
                  ),
                ],
              )),
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(message),
          ],
        ),
      ];

      final response = await OpenAI.instance.chat.create(
        model: 'gpt-3.5-turbo',
        messages: messages,
        temperature: 0.7,
        maxTokens: 1000,
      );

      final content = response.choices.first.message.content?.first.text ?? '';

      return ChatMessage(
        id: response.id,
        content: content.trim(),
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Error calling OpenAI: $e');
    }
  }

  Future<ChatMessage> streamMessage({
    required String message,
    List<ChatMessage>? conversationHistory,
    Function(String)? onChunk,
  }) async {
    try {
      final messages = [
        if (conversationHistory != null)
          ...conversationHistory.map((msg) => OpenAIChatCompletionChoiceMessageModel(
                role: msg.role == MessageRole.user
                    ? OpenAIChatMessageRole.user
                    : OpenAIChatMessageRole.assistant,
                content: [
                  OpenAIChatCompletionChoiceMessageContentItemModel.text(
                    msg.content,
                  ),
                ],
              )),
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(message),
          ],
        ),
      ];

      final stream = OpenAI.instance.chat.createStream(
        model: 'gpt-4o-mini',
        messages: messages,
        temperature: 0.7,
        maxTokens: 1000,
      );

      final buffer = StringBuffer();
      String? responseId;

      await for (final chunk in stream) {
        responseId ??= chunk.id;
        final content = chunk.choices.first.delta.content?.first?.text;
        if (content != null) {
          buffer.write(content);
          onChunk?.call(buffer.toString());
        }
      }

      if (buffer.isEmpty) {
        return await sendMessage(
          message: message,
          conversationHistory: conversationHistory,
        );
      }

      return ChatMessage(
        id: responseId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        content: buffer.toString().trim(),
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      try {
        return await sendMessage(
          message: message,
          conversationHistory: conversationHistory,
        );
      } catch (fallbackError) {
        throw Exception('Failed to connect to OpenAI. Please check your API key and internet connection. Error details: $fallbackError');
      }
    }
  }

  /// Generate a short category name (≤40 chars) from the user's first message.
  Future<String> generateCategoryName(String firstUserMessage) async {
    try {
      final response = await OpenAI.instance.chat.create(
        model: 'gpt-4o-mini',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                'You are a naming assistant. '
                'Step 1: Detect the language of the user message. '
                'Step 2: Generate a short, descriptive chat category name STRICTLY in that same detected language. '
                'Maximum 40 characters. '
                'Return ONLY the category name — no explanation, no quotes, no punctuation at the end.',
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                firstUserMessage,
              ),
            ],
          ),
        ],
        temperature: 0.5,
        maxTokens: 30,
      );

      final name =
          (response.choices.first.message.content?.first.text ?? '').trim();
      // Ensure max 40 chars
      return name.length > 40 ? name.substring(0, 40) : name;
    } catch (_) {
      // Fallback: use first 40 chars of the message itself
      final fallback = firstUserMessage.trim();
      return fallback.length > 40 ? fallback.substring(0, 40) : fallback;
    }
  }
}

