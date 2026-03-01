import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/chat_message_model.dart';

class OpenAIRepository {
  OpenAIRepository() {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey.contains('your_openai_api_key_here')) {
      throw StateError(
          'Vui lòng thêm OPENAI_API_KEY hợp lệ vào file .env');
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
      throw Exception('Lỗi khi gọi OpenAI: $e');
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
        throw Exception('Không thể kết nối với OpenAI. Vui lòng kiểm tra API key và kết nối internet. Chi tiết lỗi: $fallbackError');
      }
    }
  }
}

