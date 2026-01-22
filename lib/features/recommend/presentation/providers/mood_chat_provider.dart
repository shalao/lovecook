import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ai_service.dart';
import '../../../family/data/repositories/family_repository.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';

/// 聊天消息模型
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isLoading = false,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 对话状态
class MoodChatState {
  final List<ChatMessage> messages;
  final String? extractedPreference;
  final List<String>? suggestedDishes;
  final bool isConfirmed;
  final bool isLoading;
  final String? error;

  const MoodChatState({
    this.messages = const [],
    this.extractedPreference,
    this.suggestedDishes,
    this.isConfirmed = false,
    this.isLoading = false,
    this.error,
  });

  MoodChatState copyWith({
    List<ChatMessage>? messages,
    String? extractedPreference,
    List<String>? suggestedDishes,
    bool? isConfirmed,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearExtractedPreference = false,
    bool clearSuggestedDishes = false,
  }) {
    return MoodChatState(
      messages: messages ?? this.messages,
      extractedPreference: clearExtractedPreference
          ? null
          : (extractedPreference ?? this.extractedPreference),
      suggestedDishes: clearSuggestedDishes
          ? null
          : (suggestedDishes ?? this.suggestedDishes),
      isConfirmed: isConfirmed ?? this.isConfirmed,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get hasMessages => messages.isNotEmpty;
  bool get canConfirm => extractedPreference != null && !isConfirmed;
}

/// 对话状态管理器
class MoodChatNotifier extends StateNotifier<MoodChatState> {
  final AIService _aiService;
  final dynamic _currentFamily;
  final List<dynamic> _inventory;

  MoodChatNotifier({
    required AIService aiService,
    required dynamic currentFamily,
    required List<dynamic> inventory,
  })  : _aiService = aiService,
        _currentFamily = currentFamily,
        _inventory = inventory,
        super(const MoodChatState());

  /// 发送欢迎消息
  void sendWelcomeMessage() {
    if (state.messages.isEmpty) {
      final welcomeMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: '你好！今天想吃点什么？有什么特别的想法吗？',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(messages: [welcomeMessage]);
    }
  }

  /// 发送用户消息
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // 添加用户消息
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    // 添加AI加载消息
    final loadingMessage = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_loading',
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, loadingMessage],
      isLoading: true,
      clearError: true,
    );

    try {
      // 调用AI获取回复
      final response = await _aiService.chatForMoodExtraction(
        messages: state.messages.where((m) => !m.isLoading).toList(),
        family: _currentFamily,
        inventory: _inventory,
      );

      // 移除加载消息，添加AI回复
      final updatedMessages = state.messages
          .where((m) => !m.isLoading)
          .toList();

      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: response.reply,
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...updatedMessages, aiMessage],
        extractedPreference: response.extractedPreference,
        suggestedDishes: response.suggestedDishes,
        isLoading: false,
      );
    } on AIServiceException catch (e) {
      // 移除加载消息
      final updatedMessages = state.messages
          .where((m) => !m.isLoading)
          .toList();

      state = state.copyWith(
        messages: updatedMessages,
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      // 移除加载消息
      final updatedMessages = state.messages
          .where((m) => !m.isLoading)
          .toList();

      state = state.copyWith(
        messages: updatedMessages,
        isLoading: false,
        error: '发送消息失败: $e',
      );
    }
  }

  /// 确认偏好
  void confirmPreference() {
    state = state.copyWith(isConfirmed: true);
  }

  /// 重置对话
  void resetChat() {
    state = const MoodChatState();
    sendWelcomeMessage();
  }

  /// 获取最终的偏好描述
  String? getFinalPreference() {
    if (state.extractedPreference != null) {
      return state.extractedPreference;
    }

    // 从用户消息中提取
    final userMessages = state.messages
        .where((m) => m.isUser)
        .map((m) => m.content)
        .join('；');

    return userMessages.isNotEmpty ? userMessages : null;
  }
}

/// 对话Provider
final moodChatProvider =
    StateNotifierProvider<MoodChatNotifier, MoodChatState>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final currentFamily = ref.watch(currentFamilyProvider);
  final inventoryState = ref.watch(inventoryProvider);

  return MoodChatNotifier(
    aiService: aiService,
    currentFamily: currentFamily,
    inventory: inventoryState.ingredients,
  );
});
