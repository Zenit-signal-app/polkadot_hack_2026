import 'chat_message_model.dart';

/// Số lượng tin nhắn tối đa lưu trữ cho mỗi loại (user & assistant)
const int kMaxMessagesPerRole = 4;

class ChatCategory {
  final String name;
  final List<ChatMessage> messages;

  const ChatCategory({
    required this.name,
    this.messages = const [],
  });

  /// Chỉ giữ 4 tin nhắn user gần nhất + 4 tin nhắn assistant gần nhất
  List<ChatMessage> get trimmedMessages {
    final userMessages = messages
        .where((m) => m.role == MessageRole.user)
        .toList();
    final assistantMessages = messages
        .where((m) => m.role == MessageRole.assistant)
        .toList();

    final latestUser = userMessages.length > kMaxMessagesPerRole
        ? userMessages.sublist(userMessages.length - kMaxMessagesPerRole)
        : userMessages;

    final latestAssistant = assistantMessages.length > kMaxMessagesPerRole
        ? assistantMessages
            .sublist(assistantMessages.length - kMaxMessagesPerRole)
        : assistantMessages;

    // Gộp và sắp xếp theo thứ tự thời gian
    return [...latestUser, ...latestAssistant]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  ChatCategory copyWith({
    String? name,
    List<ChatMessage>? messages,
  }) {
    return ChatCategory(
      name: name ?? this.name,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'message': trimmedMessages
          .map((m) => {
                'id': m.id,
                'content': m.content,
                'role': m.role == MessageRole.user ? 'user' : 'assistant',
                'timestamp': m.timestamp.millisecondsSinceEpoch,
                'isError': m.isError,
              })
          .toList(),
    };
  }

  factory ChatCategory.fromJson(Map<String, dynamic> json) {
    final rawMessages = (json['message'] as List<dynamic>?) ?? [];
    final messages = rawMessages
        .whereType<Map>()
        .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    return ChatCategory(
      name: json['name'] as String,
      messages: messages,
    );
  }
}
