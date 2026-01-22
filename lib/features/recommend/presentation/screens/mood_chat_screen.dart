import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/mood_chat_provider.dart';
import '../providers/recommend_provider.dart';

class MoodChatScreen extends ConsumerStatefulWidget {
  const MoodChatScreen({super.key});

  @override
  ConsumerState<MoodChatScreen> createState() => _MoodChatScreenState();
}

class _MoodChatScreenState extends ConsumerState<MoodChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 发送欢迎消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(moodChatProvider.notifier).sendWelcomeMessage();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    ref.read(moodChatProvider.notifier).sendMessage(text);
    _inputController.clear();
    _scrollToBottom();
  }

  void _confirmAndReturn() {
    final notifier = ref.read(moodChatProvider.notifier);
    final preference = notifier.getFinalPreference();

    if (preference != null) {
      // 更新推荐设置的心情输入
      ref.read(recommendProvider.notifier).updateMoodInput(preference);
      notifier.confirmPreference();
    }

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(moodChatProvider);

    // 监听消息变化，自动滚动
    ref.listen(moodChatProvider, (_, __) {
      _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('和AI聊聊'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(moodChatProvider.notifier).resetChat();
            },
            child: const Text('重新开始'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 聊天区域
          Expanded(
            child: _buildChatArea(state),
          ),

          // 提取的偏好提示
          if (state.extractedPreference != null)
            _buildPreferenceCard(state),

          // 输入区域
          _buildInputArea(state),
        ],
      ),
    );
  }

  Widget _buildChatArea(MoodChatState state) {
    if (state.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        return _ChatBubble(
          message: message,
          key: ValueKey(message.id),
        );
      },
    );
  }

  Widget _buildPreferenceCard(MoodChatState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondaryDark.withOpacity(0.15) : Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.secondaryDark : Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: isDark ? AppColors.secondaryDark : Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '已了解你的需求',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? AppColors.textPrimaryDark : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.extractedPreference!,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey[700],
            ),
          ),
          if (state.suggestedDishes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: state.suggestedDishes!.map((dish) {
                return Chip(
                  label: Text(
                    dish,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                    ),
                  ),
                  backgroundColor: isDark ? AppColors.inputBackgroundDark : Colors.white,
                  side: BorderSide(color: isDark ? AppColors.secondaryDark : Colors.green[300]!),
                  visualDensity: VisualDensity.compact,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmAndReturn,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('确认并生成推荐'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(MoodChatState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 语音输入按钮
          IconButton(
            icon: Icon(
              Icons.mic,
              color: isDark ? AppColors.textSecondaryDark : null,
            ),
            onPressed: () {
              // TODO: 实现语音输入
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('语音输入功能开发中...')),
              );
            },
            tooltip: '语音输入',
          ),
          // 文字输入框
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              style: TextStyle(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '说说今天想吃什么...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.textTertiaryDark : Colors.grey[500],
                ),
                filled: true,
                fillColor: isDark ? AppColors.inputBackgroundDark : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          // 发送按钮
          IconButton(
            icon: state.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: state.isLoading ? null : _sendMessage,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (message.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(context, isUser: false),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.inputBackgroundDark : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? AppColors.textTertiaryDark : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '正在思考...',
                    style: TextStyle(
                      color: isDark ? AppColors.textTertiaryDark : Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(context, isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).primaryColor
                    : (isDark ? AppColors.inputBackgroundDark : Colors.grey[100]),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : (isDark ? AppColors.textPrimaryDark : Colors.black87),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(context, isUser: true),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, {required bool isUser}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser
          ? (isDark ? Colors.blue[800] : Colors.blue[100])
          : (isDark ? Colors.green[800] : Colors.green[100]),
      child: Icon(
        isUser ? Icons.person : Icons.restaurant,
        size: 18,
        color: isUser
            ? (isDark ? Colors.blue[200] : Colors.blue[600])
            : (isDark ? Colors.green[200] : Colors.green[600]),
      ),
    );
  }
}
