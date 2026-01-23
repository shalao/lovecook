import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/realtime_voice_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../recipe/data/models/recipe_model.dart';
import '../providers/cooking_provider.dart';

class CookingModeScreen extends ConsumerStatefulWidget {
  final RecipeModel recipe;

  const CookingModeScreen({super.key, required this.recipe});

  @override
  ConsumerState<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends ConsumerState<CookingModeScreen> {
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _remainingSeconds = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        // 可以添加提示音
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 0);
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cookingProvider(widget.recipe));
    final notifier = ref.read(cookingProvider(widget.recipe).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.recipe.name),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        actions: [
          // 计时器按钮
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: () => _showTimerDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 步骤进度
          _buildStepProgress(state),

          // 当前步骤内容
          Expanded(
            child: _buildStepContent(state, notifier),
          ),

          // 对话历史
          if (state.messages.isNotEmpty) _buildChatHistory(state),

          // 错误提示
          if (state.error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: isDark ? Colors.red.shade400 : Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => notifier.clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // 计时器显示
          if (_remainingSeconds > 0) _buildTimerDisplay(),

          // 底部控制栏
          _buildBottomControls(state, notifier),
        ],
      ),
    );
  }

  Widget _buildStepProgress(CookingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? AppColors.surfaceDark : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '步骤 ${state.currentStep + 1}/${state.totalSteps}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? AppColors.textPrimaryDark : null,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.recipe.totalTime}分钟',
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (state.currentStep + 1) / state.totalSteps,
            backgroundColor: isDark ? AppColors.inputBackgroundDark : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.primaryDark : AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(CookingState state, CookingNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤编号
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryDark : AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '${state.currentStep + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 步骤内容
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                state.currentStepText,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.6,
                  color: isDark ? AppColors.textPrimaryDark : null,
                ),
              ),
            ),
          ),

          // 朗读按钮
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: state.isSpeaking
                    ? () => notifier.stopSpeaking()
                    : () => notifier.speakCurrentStep(),
                icon: Icon(
                  state.isSpeaking ? Icons.stop : Icons.volume_up,
                  size: 18,
                ),
                label: Text(state.isSpeaking ? '停止' : '朗读'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatHistory(CookingState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        reverse: true,
        itemCount: state.messages.length,
        itemBuilder: (context, index) {
          final message = state.messages[state.messages.length - 1 - index];
          final isUser = message.type == MessageType.user;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isUser) ...[
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.1),
                    child: Icon(
                      Icons.restaurant,
                      size: 14,
                      color: isDark ? AppColors.primaryDark : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.1)
                          : (isDark ? AppColors.inputBackgroundDark : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 13,
                        color: isUser
                            ? (isDark ? AppColors.primaryDark : AppColors.primary)
                            : (isDark ? AppColors.textPrimaryDark : Colors.grey.shade800),
                      ),
                    ),
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isDark ? AppColors.primaryDark : AppColors.primary,
                    child: const Icon(
                      Icons.person,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.orange.withOpacity(0.4) : Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: isDark ? Colors.orange.shade400 : Colors.orange.shade700),
          const SizedBox(width: 12),
          Text(
            _formatTime(_remainingSeconds),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.orange.shade400 : Colors.orange.shade700,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.stop, color: isDark ? Colors.orange.shade400 : Colors.orange.shade700),
            onPressed: _stopTimer,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(CookingState state, CookingNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 语音模式切换
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildVoiceModeChip(
                  context,
                  '按住说话',
                  Icons.touch_app,
                  state.voiceMode == VoiceMode.pushToTalk,
                  () => notifier.setVoiceMode(VoiceMode.pushToTalk),
                ),
                const SizedBox(width: 8),
                _buildVoiceModeChip(
                  context,
                  '实时对话',
                  Icons.surround_sound,
                  state.voiceMode == VoiceMode.realtime,
                  () => notifier.setVoiceMode(VoiceMode.realtime),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 主控制区
            Row(
              children: [
                // 上一步
                IconButton(
                  onPressed: state.isFirstStep ? null : () => notifier.previousStep(),
                  icon: const Icon(Icons.chevron_left),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppColors.inputBackgroundDark : Colors.grey.shade100,
                    disabledBackgroundColor: isDark ? AppColors.inputBackgroundDark.withOpacity(0.5) : Colors.grey.shade50,
                  ),
                ),

                const SizedBox(width: 8),

                // 语音按钮（根据模式显示不同 UI）
                Expanded(
                  child: state.isRealtimeMode
                      ? _buildRealtimeVoiceButton(state, notifier)
                      : _buildPushToTalkButton(state, notifier),
                ),

                const SizedBox(width: 8),

                // 下一步
                IconButton(
                  onPressed: state.isLastStep ? null : () => notifier.nextStep(),
                  icon: const Icon(Icons.chevron_right),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? AppColors.inputBackgroundDark : Colors.grey.shade100,
                    disabledBackgroundColor: isDark ? AppColors.inputBackgroundDark.withOpacity(0.5) : Colors.grey.shade50,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 语音模式选择 Chip
  Widget _buildVoiceModeChip(
    BuildContext context,
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryDark : AppColors.primary)
              : (isDark ? AppColors.inputBackgroundDark : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.textSecondaryDark : Colors.grey.shade600),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textSecondaryDark : Colors.grey.shade600),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 按住说话按钮
  Widget _buildPushToTalkButton(CookingState state, CookingNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onLongPressStart: (_) {
        if (!state.isProcessing) {
          notifier.startRecording();
        }
      },
      onLongPressEnd: (_) {
        if (state.isRecording) {
          notifier.stopRecordingAndProcess();
        }
      },
      onLongPressCancel: () {
        if (state.isRecording) {
          notifier.cancelRecording();
        }
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: state.isRecording
              ? Colors.red
              : state.isProcessing
                  ? Colors.grey
                  : (isDark ? AppColors.primaryDark : AppColors.primary),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: state.isProcessing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      state.isRecording ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.isRecording ? '松开发送' : '按住说话',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// 实时语音按钮
  Widget _buildRealtimeVoiceButton(CookingState state, CookingNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 连接中
    if (state.isRealtimeConnecting) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 8),
              Text(
                '连接中...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 已连接
    if (state.isRealtimeConnected) {
      return GestureDetector(
        onTap: () => notifier.toggleRealtimeMute(),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: state.isSpeaking
                ? Colors.green
                : state.isRealtimeListening
                    ? (isDark ? AppColors.primaryDark : AppColors.primary)
                    : Colors.grey,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 语音波形动画（简化版）
                if (state.isSpeaking) ...[
                  const Icon(Icons.graphic_eq, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'AI 正在回复...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  Icon(
                    state.isRealtimeListening ? Icons.mic : Icons.mic_off,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.isRealtimeListening ? '正在聆听...' : '已静音',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // 未连接或错误，显示连接按钮
    return GestureDetector(
      onTap: () => notifier.connectRealtime(),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: state.realtimeState == RealtimeSessionState.error
              ? Colors.red
              : (isDark ? AppColors.primaryDark : AppColors.primary),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                state.realtimeState == RealtimeSessionState.error
                    ? '重新连接'
                    : '开始实时对话',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '设置计时器',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimerChip(context, '30秒', 30),
                _buildTimerChip(context, '1分钟', 60),
                _buildTimerChip(context, '2分钟', 120),
                _buildTimerChip(context, '3分钟', 180),
                _buildTimerChip(context, '5分钟', 300),
                _buildTimerChip(context, '10分钟', 600),
                _buildTimerChip(context, '15分钟', 900),
                _buildTimerChip(context, '30分钟', 1800),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerChip(BuildContext context, String label, int seconds) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return ActionChip(
      label: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
      ),
      onPressed: () {
        Navigator.pop(context);
        _startTimer(seconds);
      },
      elevation: 0,
      pressElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? AppColors.inputBackgroundDark : AppColors.chipBackground,
      side: isDark ? BorderSide(color: AppColors.borderDark) : BorderSide.none,
    );
  }
}
