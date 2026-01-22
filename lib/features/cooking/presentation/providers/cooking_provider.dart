import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ai_service.dart';
import '../../../recipe/data/models/recipe_model.dart';
import '../../data/services/voice_service.dart';

/// 对话消息类型
enum MessageType {
  user,
  assistant,
}

/// 对话消息
class ChatMessage {
  final String content;
  final MessageType type;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 烹饪模式状态
class CookingState {
  final RecipeModel recipe;
  final int currentStep;
  final List<ChatMessage> messages;
  final bool isRecording;
  final bool isProcessing;
  final bool isSpeaking;
  final String? error;
  final int? timerSeconds;

  const CookingState({
    required this.recipe,
    this.currentStep = 0,
    this.messages = const [],
    this.isRecording = false,
    this.isProcessing = false,
    this.isSpeaking = false,
    this.error,
    this.timerSeconds,
  });

  CookingState copyWith({
    RecipeModel? recipe,
    int? currentStep,
    List<ChatMessage>? messages,
    bool? isRecording,
    bool? isProcessing,
    bool? isSpeaking,
    String? error,
    int? timerSeconds,
    bool clearError = false,
    bool clearTimer = false,
  }) {
    return CookingState(
      recipe: recipe ?? this.recipe,
      currentStep: currentStep ?? this.currentStep,
      messages: messages ?? this.messages,
      isRecording: isRecording ?? this.isRecording,
      isProcessing: isProcessing ?? this.isProcessing,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      error: clearError ? null : (error ?? this.error),
      timerSeconds: clearTimer ? null : (timerSeconds ?? this.timerSeconds),
    );
  }

  String get currentStepText {
    if (currentStep >= 0 && currentStep < recipe.steps.length) {
      return recipe.steps[currentStep];
    }
    return '';
  }

  bool get isFirstStep => currentStep == 0;
  bool get isLastStep => currentStep == recipe.steps.length - 1;
  int get totalSteps => recipe.steps.length;
}

/// 烹饪模式通知器
class CookingNotifier extends StateNotifier<CookingState> {
  final VoiceService _voiceService;
  final AIService _aiService;

  CookingNotifier({
    required RecipeModel recipe,
    required VoiceService voiceService,
    required AIService aiService,
  })  : _voiceService = voiceService,
        _aiService = aiService,
        super(CookingState(recipe: recipe));

  /// 下一步
  void nextStep() {
    if (!state.isLastStep) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  /// 上一步
  void previousStep() {
    if (!state.isFirstStep) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  /// 跳转到指定步骤
  void goToStep(int step) {
    if (step >= 0 && step < state.totalSteps) {
      state = state.copyWith(currentStep: step);
    }
  }

  /// 朗读当前步骤
  Future<void> speakCurrentStep() async {
    if (!_voiceService.isConfigured) {
      state = state.copyWith(error: 'API 密钥未配置');
      return;
    }

    state = state.copyWith(isSpeaking: true, clearError: true);
    try {
      await _voiceService.speak(state.currentStepText);
    } on VoiceServiceException catch (e) {
      state = state.copyWith(error: e.message);
    } finally {
      state = state.copyWith(isSpeaking: false);
    }
  }

  /// 停止朗读
  Future<void> stopSpeaking() async {
    await _voiceService.stopSpeaking();
    state = state.copyWith(isSpeaking: false);
  }

  /// 开始录音
  Future<void> startRecording() async {
    if (!_voiceService.isConfigured) {
      state = state.copyWith(error: 'API 密钥未配置');
      return;
    }

    try {
      final hasPermission = await _voiceService.checkPermission();
      if (!hasPermission) {
        state = state.copyWith(error: '请允许使用麦克风');
        return;
      }

      await _voiceService.startRecording();
      state = state.copyWith(isRecording: true, clearError: true);
    } on VoiceServiceException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  /// 停止录音并处理
  Future<void> stopRecordingAndProcess() async {
    if (!state.isRecording) return;

    state = state.copyWith(isRecording: false, isProcessing: true);

    try {
      // 停止录音
      final audioPath = await _voiceService.stopRecording();
      if (audioPath == null) {
        state = state.copyWith(isProcessing: false, error: '录音失败');
        return;
      }

      // 语音识别
      final userText = await _voiceService.transcribe(audioPath);
      if (userText.isEmpty) {
        state = state.copyWith(isProcessing: false, error: '未识别到语音');
        return;
      }

      // 添加用户消息
      final userMessage = ChatMessage(content: userText, type: MessageType.user);
      state = state.copyWith(
        messages: [...state.messages, userMessage],
      );

      // AI 回复
      final response = await _getCookingAssistantResponse(userText);

      // 添加助手消息
      final assistantMessage = ChatMessage(
        content: response,
        type: MessageType.assistant,
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isProcessing: false,
      );

      // 朗读回复
      state = state.copyWith(isSpeaking: true);
      await _voiceService.speak(response);
      state = state.copyWith(isSpeaking: false);
    } on VoiceServiceException catch (e) {
      state = state.copyWith(isProcessing: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: '处理失败: $e');
    }
  }

  /// 取消录音
  Future<void> cancelRecording() async {
    await _voiceService.cancelRecording();
    state = state.copyWith(isRecording: false);
  }

  /// 获取烹饪助手 AI 回复
  Future<String> _getCookingAssistantResponse(String userQuestion) async {
    final recipe = state.recipe;
    final currentStep = state.currentStepText;

    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': '''你是一位专业、友好的烹饪助手，正在帮助用户制作"${recipe.name}"。
当前步骤：第${state.currentStep + 1}步（共${recipe.steps.length}步）
步骤内容：$currentStep

食材清单：
${recipe.ingredients.map((i) => '- ${i.formatted}').join('\n')}

${recipe.tips != null ? '烹饪技巧：${recipe.tips}' : ''}

请用简短、清晰、自然的语言回答用户的问题。回答要实用、具体，像一位有经验的厨师在旁边指导一样。'''
      },
      // 添加对话历史（最近5条）
      ...state.messages.skip(state.messages.length > 5 ? state.messages.length - 5 : 0).map((m) => {
            'role': m.type == MessageType.user ? 'user' : 'assistant',
            'content': m.content,
          }),
      {
        'role': 'user',
        'content': userQuestion,
      },
    ];

    try {
      return await _aiService.chatCompletion(messages: messages);
    } on AIServiceException catch (e) {
      throw VoiceServiceException('AI 回复失败: ${e.message}');
    }
  }

  /// 设置计时器
  void setTimer(int seconds) {
    state = state.copyWith(timerSeconds: seconds);
  }

  /// 清除计时器
  void clearTimer() {
    state = state.copyWith(clearTimer: true);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }
}

/// 烹饪模式 Provider
final cookingProvider =
    StateNotifierProvider.autoDispose.family<CookingNotifier, CookingState, RecipeModel>(
  (ref, recipe) {
    final voiceService = ref.watch(voiceServiceProvider);
    final aiService = ref.watch(aiServiceProvider);
    return CookingNotifier(
      recipe: recipe,
      voiceService: voiceService,
      aiService: aiService,
    );
  },
);
