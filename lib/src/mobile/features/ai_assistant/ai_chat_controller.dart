import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/credit_card_model.dart';
import '../../../services/ai_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<CreditCard> recommendedCards;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.recommendedCards = const [],
  });
}

class AIChatState {
  final List<ChatMessage> messages;
  final bool isLoading;

  AIChatState({
    this.messages = const [],
    this.isLoading = false,
  });

  AIChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return AIChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final aiChatControllerProvider = NotifierProvider<AIChatController, AIChatState>(() {
  return AIChatController();
});

class AIChatController extends Notifier<AIChatState> {
  late final AIService _aiService;

  @override
  AIChatState build() {
    _aiService = ref.watch(aiServiceProvider);
    return AIChatState(messages: [
      ChatMessage(
        text: 'Chào bạn! Mình là Finy AI, trợ lý tài chính thông minh của bạn. Bạn muốn tìm thẻ tín dụng để đi du lịch, đi siêu thị, hay mua sắm online hôm nay?',
        isUser: false,
      ),
    ]);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Thêm tin nhắn của User
    final userMessage = ChatMessage(text: text, isUser: true);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    // Gửi lên Gemini
    final response = await _aiService.sendMessage(text);
    final recommendedCards = _aiService.lastRecommendedCards;

    // Thêm tin nhắn của AI (cùng với thẻ nếu có)
    final aiMessage = ChatMessage(
      text: response,
      isUser: false,
      recommendedCards: List.from(recommendedCards),
    );

    state = state.copyWith(
      messages: [...state.messages, aiMessage],
      isLoading: false,
    );
  }

  void resetChat() {
    _aiService.resetSession();
    state = AIChatState(messages: [
      ChatMessage(
        text: 'Chào bạn! Mình là Finy AI, trợ lý tài chính thông minh của bạn. Bạn muốn tìm thẻ tín dụng để đi du lịch, đi siêu thị, hay mua sắm online hôm nay?',
        isUser: false,
      ),
    ]);
  }
}
