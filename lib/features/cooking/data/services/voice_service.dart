import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/services/ai_proxy_service.dart';
import '../../../../core/services/log_service.dart';

/// 语音服务 - 处理语音识别 (STT) 和语音合成 (TTS)
class VoiceService {
  final AiProxyService _proxyService;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  String? _recordingPath;
  StreamSubscription<PlayerState>? _playerSubscription;
  Completer<void>? _playbackCompleter;

  VoiceService({required AiProxyService proxyService})
      : _proxyService = proxyService;

  /// 始终返回 true，因为使用服务端代理
  bool get isConfigured => true;

  /// 检查麦克风权限
  Future<bool> checkPermission() async {
    return await _recorder.hasPermission();
  }

  /// 开始录音
  Future<void> startRecording() async {
    if (!await _recorder.hasPermission()) {
      throw VoiceServiceException('未获得麦克风权限');
    }

    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/voice_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _recordingPath!,
    );
  }

  /// 停止录音并返回录音文件路径
  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path;
  }

  /// 取消录音
  Future<void> cancelRecording() async {
    await _recorder.stop();
    if (_recordingPath != null) {
      try {
        await File(_recordingPath!).delete();
      } catch (_) {}
      _recordingPath = null;
    }
  }

  /// 语音识别 (STT) - 使用 OpenAI Whisper
  Future<String> transcribe(String audioPath) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw VoiceServiceException('录音文件不存在');
      }

      final audioData = await file.readAsBytes();
      final text = await _proxyService.audioTranscription(
        audioData: audioData,
        filename: 'audio.m4a',
        language: 'zh',
      );

      return text;
    } on AiProxyException catch (e) {
      throw VoiceServiceException('语音识别失败: ${e.message}');
    } finally {
      // 清理录音文件
      try {
        await File(audioPath).delete();
      } catch (_) {}
    }
  }

  /// 语音合成 (TTS) - 使用 OpenAI TTS
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    logger.info('VoiceService', 'speak', '开始语音合成', data: {'textLength': text.length});

    // 取消之前的播放监听器和 completer
    await _playerSubscription?.cancel();
    _playerSubscription = null;
    if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
      _playbackCompleter!.complete();
    }
    _playbackCompleter = null;

    File? tempFile;

    try {
      logger.info('VoiceService', 'speak', '调用 TTS API...');
      final audioData = await _proxyService.audioSpeech(
        text: text,
        model: 'tts-1',
        voice: 'nova', // 女声，清晰自然
        responseFormat: 'mp3',
      );

      logger.info('VoiceService', 'speak', 'TTS API 返回成功', data: {'audioSize': audioData.length});

      // 使用 Completer 等待播放完成
      _playbackCompleter = Completer<void>();

      // 监听播放状态
      _playerSubscription = _player.playerStateStream.listen((state) async {
        logger.info('VoiceService', 'speak', '播放状态变化', data: {
          'playing': state.playing,
          'processingState': state.processingState.toString(),
        });
        if (state.processingState == ProcessingState.completed) {
          // 清理临时文件（非 Web 平台）
          if (!kIsWeb && tempFile != null) {
            try {
              await tempFile.delete();
            } catch (_) {}
          }
          // 播放完成，完成 Completer
          if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
            logger.info('VoiceService', 'speak', '播放完成');
            _playbackCompleter!.complete();
          }
        }
      });

      // 根据平台选择播放方式
      if (kIsWeb) {
        // Web 平台：使用 Data URL
        final base64Audio = base64Encode(audioData);
        final dataUrl = 'data:audio/mp3;base64,$base64Audio';
        logger.info('VoiceService', 'speak', 'Web 平台：使用 Data URL 播放');
        await _player.setUrl(dataUrl);
      } else {
        // 非 Web 平台：保存到临时文件
        final dir = await getTemporaryDirectory();
        final audioPath = '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
        tempFile = File(audioPath);
        await tempFile.writeAsBytes(audioData);
        logger.info('VoiceService', 'speak', '非 Web 平台：保存到临时文件', data: {'path': audioPath});
        await _player.setFilePath(audioPath);
      }

      logger.info('VoiceService', 'speak', '开始播放音频');
      await _player.play();

      // 等待播放完成
      await _playbackCompleter!.future;
    } on AiProxyException catch (e) {
      logger.error('VoiceService', 'speak', '语音合成失败', error: e.message);
      throw VoiceServiceException('语音合成失败: ${e.message}');
    } catch (e, stackTrace) {
      logger.error('VoiceService', 'speak', '播放失败', error: e, stackTrace: stackTrace);
      throw VoiceServiceException('播放失败: $e');
    } finally {
      // 清理监听器
      await _playerSubscription?.cancel();
      _playerSubscription = null;
      _playbackCompleter = null;
    }
  }

  /// 停止播放
  Future<void> stopSpeaking() async {
    await _playerSubscription?.cancel();
    _playerSubscription = null;
    // 完成 completer，让 speak() 方法可以退出
    if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
      _playbackCompleter!.complete();
    }
    _playbackCompleter = null;
    await _player.stop();
  }

  /// 是否正在播放
  bool get isPlaying => _player.playing;

  /// 是否正在录音
  Future<bool> get isRecording => _recorder.isRecording();

  /// 释放资源
  Future<void> dispose() async {
    await _playerSubscription?.cancel();
    _playerSubscription = null;
    if (_playbackCompleter != null && !_playbackCompleter!.isCompleted) {
      _playbackCompleter!.complete();
    }
    _playbackCompleter = null;
    await _recorder.dispose();
    await _player.dispose();
  }
}

/// 语音服务异常
class VoiceServiceException implements Exception {
  final String message;
  VoiceServiceException(this.message);

  @override
  String toString() => message;
}

/// 语音服务 Provider
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final proxyService = ref.watch(aiProxyServiceProvider);
  return VoiceService(proxyService: proxyService);
});
