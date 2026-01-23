import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'realtime_token_service.dart';

/// 实时语音会话状态
enum RealtimeSessionState {
  /// 未连接
  disconnected,

  /// 正在连接
  connecting,

  /// 已连接
  connected,

  /// 正在断开
  disconnecting,

  /// 错误
  error,
}

/// 对话消息类型
enum RealtimeMessageRole {
  user,
  assistant,
  system,
}

/// 对话消息
class RealtimeMessage {
  final String id;
  final RealtimeMessageRole role;
  final String content;
  final DateTime timestamp;

  RealtimeMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 实时语音服务异常
class RealtimeVoiceException implements Exception {
  final String message;
  final String? code;

  RealtimeVoiceException(this.message, {this.code});

  @override
  String toString() => 'RealtimeVoiceException: $message';
}

/// 实时语音会话配置
class RealtimeSessionConfig {
  /// 系统提示词
  final String instructions;

  /// 语音模型
  final String voice;

  /// 模型名称
  final String model;

  /// 是否启用语音活动检测
  final bool enableVAD;

  const RealtimeSessionConfig({
    this.instructions = '',
    this.voice = 'alloy',
    this.model = 'gpt-realtime-mini-2025-12-15',
    this.enableVAD = true,
  });

  RealtimeSessionConfig copyWith({
    String? instructions,
    String? voice,
    String? model,
    bool? enableVAD,
  }) {
    return RealtimeSessionConfig(
      instructions: instructions ?? this.instructions,
      voice: voice ?? this.voice,
      model: model ?? this.model,
      enableVAD: enableVAD ?? this.enableVAD,
    );
  }
}

/// 实时语音状态
class RealtimeVoiceState {
  final RealtimeSessionState sessionState;
  final List<RealtimeMessage> messages;
  final bool isSpeaking;
  final bool isListening;
  final String? error;
  final RealtimeSessionConfig config;

  const RealtimeVoiceState({
    this.sessionState = RealtimeSessionState.disconnected,
    this.messages = const [],
    this.isSpeaking = false,
    this.isListening = false,
    this.error,
    this.config = const RealtimeSessionConfig(),
  });

  bool get isConnected => sessionState == RealtimeSessionState.connected;
  bool get isConnecting => sessionState == RealtimeSessionState.connecting;

  RealtimeVoiceState copyWith({
    RealtimeSessionState? sessionState,
    List<RealtimeMessage>? messages,
    bool? isSpeaking,
    bool? isListening,
    String? error,
    bool clearError = false,
    RealtimeSessionConfig? config,
  }) {
    return RealtimeVoiceState(
      sessionState: sessionState ?? this.sessionState,
      messages: messages ?? this.messages,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isListening: isListening ?? this.isListening,
      error: clearError ? null : (error ?? this.error),
      config: config ?? this.config,
    );
  }
}

/// 实时语音服务
/// 使用 WebRTC 直接连接 OpenAI Realtime API
class RealtimeVoiceService extends StateNotifier<RealtimeVoiceState> {
  final RealtimeTokenService _tokenService;

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;

  /// 事件流控制器
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  /// 服务器事件流
  Stream<Map<String, dynamic>> get serverEvents => _eventController.stream;

  RealtimeVoiceService({
    required RealtimeTokenService tokenService,
  })  : _tokenService = tokenService,
        super(const RealtimeVoiceState());

  /// 设置会话配置
  void setConfig(RealtimeSessionConfig config) {
    state = state.copyWith(config: config);
  }

  /// 更新系统提示词
  void updateInstructions(String instructions) {
    state = state.copyWith(
      config: state.config.copyWith(instructions: instructions),
    );
  }

  /// 开始实时语音会话
  Future<void> connect() async {
    if (state.isConnected || state.isConnecting) {
      return;
    }

    state = state.copyWith(
      sessionState: RealtimeSessionState.connecting,
      clearError: true,
    );

    try {
      // 1. 获取 ephemeral token
      final token = await _tokenService.getToken();

      // 2. 创建 WebRTC 连接
      await _createPeerConnection(token);

      state = state.copyWith(
        sessionState: RealtimeSessionState.connected,
        isListening: true,
      );
    } catch (e) {
      state = state.copyWith(
        sessionState: RealtimeSessionState.error,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// 创建 WebRTC 连接
  Future<void> _createPeerConnection(String token) async {
    // WebRTC 配置
    final config = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(config);

    // 监听连接状态
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('WebRTC Connection State: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _handleDisconnect();
      }
    };

    // 监听 ICE 连接状态
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('ICE Connection State: $state');
    };

    // 创建数据通道
    _dataChannel = await _peerConnection!.createDataChannel(
      'oai-events',
      RTCDataChannelInit()..ordered = true,
    );

    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      _handleDataChannelMessage(message);
    };

    _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
      debugPrint('Data Channel State: $state');
    };

    // 监听远程音频轨道
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('Received remote track: ${event.track.kind}');
      // 音频轨道会自动播放
    };

    // 获取本地音频流
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });

    // 添加本地音频轨道
    for (var track in _localStream!.getAudioTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    // 创建 SDP offer
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await _peerConnection!.setLocalDescription(offer);

    // 发送 offer 到 OpenAI 并获取 answer
    final answer = await _sendOfferToOpenAI(token, offer.sdp!);

    // 设置远程描述
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(answer, 'answer'),
    );

    // 发送初始配置
    await _sendSessionUpdate();
  }

  /// 发送 SDP offer 到 OpenAI
  Future<String> _sendOfferToOpenAI(String token, String sdp) async {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://api.openai.com/v1',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/sdp',
      },
      responseType: ResponseType.plain,
    ));

    try {
      final response = await dio.post(
        '/realtime?model=${state.config.model}',
        data: sdp,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as String;
      } else {
        throw RealtimeVoiceException(
          'WebRTC 连接失败: HTTP ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      final message = e.response?.data?.toString() ?? e.message ?? '网络错误';
      throw RealtimeVoiceException('WebRTC 连接失败: $message');
    }
  }

  /// 发送会话配置更新
  Future<void> _sendSessionUpdate() async {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      return;
    }

    final event = {
      'type': 'session.update',
      'session': {
        'modalities': ['text', 'audio'],
        'instructions': state.config.instructions,
        'voice': state.config.voice,
        'input_audio_transcription': {'model': 'whisper-1'},
        'turn_detection': state.config.enableVAD
            ? {
                'type': 'server_vad',
                'threshold': 0.5,
                'prefix_padding_ms': 300,
                'silence_duration_ms': 500,
              }
            : null,
      },
    };

    _sendEvent(event);
  }

  /// 发送事件到数据通道
  void _sendEvent(Map<String, dynamic> event) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(event)));
    }
  }

  /// 处理数据通道消息
  void _handleDataChannelMessage(RTCDataChannelMessage message) {
    try {
      final data = jsonDecode(message.text) as Map<String, dynamic>;
      final type = data['type'] as String?;

      debugPrint('Received event: $type');

      // 发送到事件流
      _eventController.add(data);

      // 处理特定事件
      switch (type) {
        case 'response.audio_transcript.done':
          _handleTranscriptDone(data);
          break;
        case 'conversation.item.input_audio_transcription.completed':
          _handleInputTranscription(data);
          break;
        case 'response.audio.delta':
          // 音频正在播放
          if (!state.isSpeaking) {
            state = state.copyWith(isSpeaking: true);
          }
          break;
        case 'response.audio.done':
          state = state.copyWith(isSpeaking: false);
          break;
        case 'error':
          _handleError(data);
          break;
      }
    } catch (e) {
      debugPrint('Error parsing data channel message: $e');
    }
  }

  /// 处理转录完成事件
  void _handleTranscriptDone(Map<String, dynamic> data) {
    final transcript = data['transcript'] as String?;
    if (transcript != null && transcript.isNotEmpty) {
      final message = RealtimeMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: RealtimeMessageRole.assistant,
        content: transcript,
      );
      state = state.copyWith(
        messages: [...state.messages, message],
      );
    }
  }

  /// 处理用户输入转录
  void _handleInputTranscription(Map<String, dynamic> data) {
    final transcript = data['transcript'] as String?;
    if (transcript != null && transcript.isNotEmpty) {
      final message = RealtimeMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: RealtimeMessageRole.user,
        content: transcript,
      );
      state = state.copyWith(
        messages: [...state.messages, message],
      );
    }
  }

  /// 处理错误
  void _handleError(Map<String, dynamic> data) {
    final error = data['error'] as Map<String, dynamic>?;
    final message = error?['message'] as String? ?? '未知错误';
    state = state.copyWith(error: message);
  }

  /// 处理断开连接
  void _handleDisconnect() {
    state = state.copyWith(
      sessionState: RealtimeSessionState.disconnected,
      isListening: false,
      isSpeaking: false,
    );
  }

  /// 发送文本消息
  Future<void> sendTextMessage(String text) async {
    if (!state.isConnected) {
      throw RealtimeVoiceException('未连接到实时语音服务');
    }

    // 添加用户消息到历史
    final message = RealtimeMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: RealtimeMessageRole.user,
      content: text,
    );
    state = state.copyWith(messages: [...state.messages, message]);

    // 发送到 OpenAI
    _sendEvent({
      'type': 'conversation.item.create',
      'item': {
        'type': 'message',
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': text}
        ],
      },
    });

    // 触发响应
    _sendEvent({'type': 'response.create'});
  }

  /// 静音/取消静音
  void setMuted(bool muted) {
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !muted;
      }
      state = state.copyWith(isListening: !muted);
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    state = state.copyWith(sessionState: RealtimeSessionState.disconnecting);

    _dataChannel?.close();
    _dataChannel = null;

    _localStream?.dispose();
    _localStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    state = state.copyWith(
      sessionState: RealtimeSessionState.disconnected,
      isListening: false,
      isSpeaking: false,
    );
  }

  /// 清除对话历史
  void clearMessages() {
    state = state.copyWith(messages: []);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    disconnect();
    _eventController.close();
    super.dispose();
  }
}

/// 实时语音服务 Provider
final realtimeVoiceServiceProvider =
    StateNotifierProvider.autoDispose<RealtimeVoiceService, RealtimeVoiceState>(
        (ref) {
  final tokenService = ref.watch(realtimeTokenServiceProvider);
  return RealtimeVoiceService(tokenService: tokenService);
});
