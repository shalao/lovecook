import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/ai_service.dart';
import '../../../../core/services/realtime_voice_service.dart';
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

/// 语音输入模式
enum VoiceInputMode {
  /// 文字输入
  text,

  /// 实时语音
  realtime,
}

/// 对话状态
class MoodChatState {
  final List<ChatMessage> messages;
  final String? extractedPreference;
  final List<String>? suggestedDishes;
  final bool isConfirmed;
  final bool isLoading;
  final String? error;

  /// 语音输入模式
  final VoiceInputMode voiceMode;

  /// 实时语音连接状态
  final RealtimeSessionState realtimeState;

  /// 实时语音是否在监听
  final bool isRealtimeListening;

  /// AI 是否正在说话
  final bool isSpeaking;

  const MoodChatState({
    this.messages = const [],
    this.extractedPreference,
    this.suggestedDishes,
    this.isConfirmed = false,
    this.isLoading = false,
    this.error,
    this.voiceMode = VoiceInputMode.text,
    this.realtimeState = RealtimeSessionState.disconnected,
    this.isRealtimeListening = false,
    this.isSpeaking = false,
  });

  /// 是否使用实时语音模式
  bool get isRealtimeMode => voiceMode == VoiceInputMode.realtime;

  /// 实时语音是否已连接
  bool get isRealtimeConnected =>
      realtimeState == RealtimeSessionState.connected;

  /// 实时语音是否正在连接
  bool get isRealtimeConnecting =>
      realtimeState == RealtimeSessionState.connecting;

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
    VoiceInputMode? voiceMode,
    RealtimeSessionState? realtimeState,
    bool? isRealtimeListening,
    bool? isSpeaking,
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
      voiceMode: voiceMode ?? this.voiceMode,
      realtimeState: realtimeState ?? this.realtimeState,
      isRealtimeListening: isRealtimeListening ?? this.isRealtimeListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }

  bool get hasMessages => messages.isNotEmpty;
  bool get canConfirm => extractedPreference != null && !isConfirmed;
}

/// 对话状态管理器
class MoodChatNotifier extends StateNotifier<MoodChatState> {
  final AIService _aiService;
  final RealtimeVoiceService _realtimeService;
  final dynamic _currentFamily;
  final List<dynamic> _inventory;

  StreamSubscription<Map<String, dynamic>>? _realtimeEventSubscription;

  MoodChatNotifier({
    required AIService aiService,
    required RealtimeVoiceService realtimeService,
    required dynamic currentFamily,
    required List<dynamic> inventory,
  })  : _aiService = aiService,
        _realtimeService = realtimeService,
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

  // ==================== 实时语音模式 ====================

  /// 切换语音模式
  Future<void> setVoiceMode(VoiceInputMode mode) async {
    if (state.voiceMode == mode) return;

    // 如果从实时模式切换，先断开连接
    if (state.isRealtimeMode && mode == VoiceInputMode.text) {
      await disconnectRealtime();
    }

    state = state.copyWith(voiceMode: mode);

    // 如果切换到实时模式，自动连接
    if (mode == VoiceInputMode.realtime) {
      await connectRealtime();
    }
  }

  /// 连接实时语音
  Future<void> connectRealtime() async {
    if (state.isRealtimeConnected || state.isRealtimeConnecting) {
      return;
    }

    state = state.copyWith(
      realtimeState: RealtimeSessionState.connecting,
      clearError: true,
    );

    try {
      // 设置推荐上下文作为系统提示
      _realtimeService.updateInstructions(_buildRecommendInstructions());

      // 监听实时语音事件
      _realtimeEventSubscription?.cancel();
      _realtimeEventSubscription =
          _realtimeService.serverEvents.listen(_handleRealtimeEvent);

      // 连接
      await _realtimeService.connect();

      state = state.copyWith(
        realtimeState: RealtimeSessionState.connected,
        isRealtimeListening: true,
      );
    } catch (e) {
      state = state.copyWith(
        realtimeState: RealtimeSessionState.error,
        error: '实时语音连接失败: $e',
      );
    }
  }

  /// 断开实时语音
  Future<void> disconnectRealtime() async {
    _realtimeEventSubscription?.cancel();
    _realtimeEventSubscription = null;

    await _realtimeService.disconnect();

    state = state.copyWith(
      realtimeState: RealtimeSessionState.disconnected,
      isRealtimeListening: false,
    );
  }

  /// 静音/取消静音实时语音
  void toggleRealtimeMute() {
    final newListening = !state.isRealtimeListening;
    _realtimeService.setMuted(!newListening);
    state = state.copyWith(isRealtimeListening: newListening);
  }

  /// 处理实时语音事件
  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;

    switch (type) {
      case 'conversation.item.input_audio_transcription.completed':
        // 用户语音转录完成
        final transcript = event['transcript'] as String?;
        if (transcript != null && transcript.isNotEmpty) {
          final message = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: transcript,
            isUser: true,
            timestamp: DateTime.now(),
          );
          state = state.copyWith(messages: [...state.messages, message]);
        }
        break;

      case 'response.audio_transcript.done':
        // AI 回复转录完成
        final transcript = event['transcript'] as String?;
        if (transcript != null && transcript.isNotEmpty) {
          final message = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: transcript,
            isUser: false,
            timestamp: DateTime.now(),
          );
          state = state.copyWith(messages: [...state.messages, message]);
        }
        break;

      case 'response.audio.delta':
        // AI 正在说话
        if (!state.isSpeaking) {
          state = state.copyWith(isSpeaking: true);
        }
        break;

      case 'response.audio.done':
        // AI 说话完成
        state = state.copyWith(isSpeaking: false);
        break;

      case 'error':
        final error = event['error'] as Map<String, dynamic>?;
        final message = error?['message'] as String? ?? '实时语音错误';
        state = state.copyWith(error: message);
        break;
    }
  }

  /// 构建推荐助手的系统提示
  String _buildRecommendInstructions() {
    final familyInfo = _currentFamily != null
        ? '家庭成员: ${_currentFamily.members?.length ?? 0}人'
        : '暂无家庭信息';

    final inventoryInfo = _inventory.isNotEmpty
        ? '当前库存: ${_inventory.take(10).map((i) => i.name).join('、')}${_inventory.length > 10 ? '等${_inventory.length}种食材' : ''}'
        : '暂无库存信息';

    return '''你是一位贴心的家庭餐食顾问，正在帮助用户选择今天吃什么。

$familyInfo
$inventoryInfo

请通过自然、轻松的对话了解用户今天的：
- 心情状态（开心、疲惫、想犒劳自己等）
- 身体状况（有没有不舒服、需要清淡还是补充营养）
- 特殊需求（有客人、庆祝活动、减肥等）

然后根据对话推荐合适的菜品。回答要简洁、温暖，像朋友聊天一样。''';
  }

  @override
  void dispose() {
    _realtimeEventSubscription?.cancel();
    _realtimeService.disconnect();
    super.dispose();
  }
}

/// 对话Provider
final moodChatProvider =
    StateNotifierProvider<MoodChatNotifier, MoodChatState>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  final realtimeService = ref.watch(realtimeVoiceServiceProvider.notifier);
  final currentFamily = ref.watch(currentFamilyProvider);
  final inventoryState = ref.watch(inventoryProvider);

  return MoodChatNotifier(
    aiService: aiService,
    realtimeService: realtimeService,
    currentFamily: currentFamily,
    inventory: inventoryState.ingredients,
  );
});
