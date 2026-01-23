import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/services/ai_proxy_service.dart';

/// 语音服务 - 处理语音识别 (STT) 和语音合成 (TTS)
class VoiceService {
  final AiProxyService _proxyService;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  String? _recordingPath;

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

    try {
      final audioData = await _proxyService.audioSpeech(
        text: text,
        model: 'tts-1',
        voice: 'nova', // 女声，清晰自然
        responseFormat: 'mp3',
      );

      // 保存音频到临时文件
      final dir = await getTemporaryDirectory();
      final audioPath = '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final file = File(audioPath);
      await file.writeAsBytes(audioData);

      // 播放音频
      await _player.setFilePath(audioPath);
      await _player.play();

      // 等待播放完成后删除文件
      _player.playerStateStream.listen((state) async {
        if (state.processingState == ProcessingState.completed) {
          try {
            await file.delete();
          } catch (_) {}
        }
      });
    } on AiProxyException catch (e) {
      throw VoiceServiceException('语音合成失败: ${e.message}');
    }
  }

  /// 停止播放
  Future<void> stopSpeaking() async {
    await _player.stop();
  }

  /// 是否正在播放
  bool get isPlaying => _player.playing;

  /// 是否正在录音
  Future<bool> get isRecording => _recorder.isRecording();

  /// 释放资源
  Future<void> dispose() async {
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
