import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/vehicle.dart';
import '../services/ai_chat_service.dart';

/// Manages the AI chat conversation state.
///
/// Injected via ChangeNotifierProvider in the widget tree.
/// AiChatService is provided through the constructor (ServiceLocator pattern).
class AiChatProvider with ChangeNotifier {
  final AiChatService _service;

  AiChatProvider({required AiChatService service}) : _service = service;

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Returns true when no messages have been sent yet (first open state).
  bool get isEmpty => _messages.isEmpty;

  /// Build a human-readable vehicle context string for the system prompt.
  String _buildVehicleContext(Vehicle? vehicle) {
    if (vehicle == null) return '車両情報なし';
    final parts = <String>[
      '${vehicle.maker} ${vehicle.model}',
      '${vehicle.year}年式',
      '走行距離${vehicle.mileage}km',
    ];
    if (vehicle.fuelType != null) {
      parts.add(vehicle.fuelType!.displayName);
    }
    return parts.join(' / ');
  }

  /// Send [text] to the AI and append the response to [_messages].
  ///
  /// Adds a loading placeholder immediately so the UI can show a typing indicator.
  Future<void> sendMessage(String text, {Vehicle? vehicle}) async {
    if (text.trim().isEmpty || _isLoading) {
      return;
    }

    final userMsg = ChatMessage.user(text.trim());
    _messages.add(userMsg);
    _messages.add(ChatMessage.loading());
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _service.ask(
      userMessage: text.trim(),
      vehicleContext: _buildVehicleContext(vehicle),
      // Pass only non-loading messages as conversation history
      history: _messages.where((m) => !m.isLoading).toList(),
    );

    // Remove the loading placeholder before adding the real response
    _messages.removeWhere((m) => m.isLoading);

    result.when(
      success: (reply) {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: ChatRole.assistant,
          content: reply,
          createdAt: DateTime.now(),
        ));
      },
      failure: (error) {
        _error = error.userMessage;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Clear the entire conversation history and any error state.
  void clearHistory() {
    _messages.clear();
    _error = null;
    notifyListeners();
  }
}
