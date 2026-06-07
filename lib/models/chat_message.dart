enum ChatRole { user, assistant }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final bool isLoading; // true while AI is generating response

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isLoading = false,
  });

  factory ChatMessage.user(String content) => ChatMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    role: ChatRole.user,
    content: content,
    createdAt: DateTime.now(),
  );

  factory ChatMessage.loading() => ChatMessage(
    id: 'loading',
    role: ChatRole.assistant,
    content: '',
    createdAt: DateTime.now(),
    isLoading: true,
  );

  ChatMessage copyWith({String? content, bool? isLoading}) => ChatMessage(
    id: id,
    role: role,
    content: content ?? this.content,
    createdAt: createdAt,
    isLoading: isLoading ?? this.isLoading,
  );
}
