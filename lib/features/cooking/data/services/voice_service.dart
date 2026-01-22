import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/services/ai_service.dart';

/// 语音服务 - 处理语音识别 (STT) 和语音合成 (TTS)
class VoiceService {
  final AIConfig _aiConfig;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final Dio _dio;

  String? _recordingPath;

  VoiceService({required AIConfig aiConfig})
      : _aiConfig = aiConfig,
        _dio = Dio(BaseOptions(
          baseUrl: aiConfig.baseUrl,
          headers: {
            'Authorization': 'Bearer ${aiConfig.apiKey}',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  bool get isConfigured => _aiConfig.isConfigured;

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
    if (!isConfigured) {
      throw VoiceServiceException('API 密钥未配置');
    }

    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw VoiceServiceException('录音文件不存在');
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioPath,
          filename: 'audio.m4a',
        ),
        'model': 'whisper-1',
        'language': 'zh',
      });

      final response = await _dio.post(
        '/audio/transcriptions',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      return response.data['text'] as String? ?? '';
    } on DioException catch (e) {
      throw VoiceServiceException('语音识别失败: ${_parseError(e)}');
    } finally {
      // 清理录音文件
      try {
        await File(audioPath).delete();
      } catch (_) {}
    }
  }

  /// 语音合成 (TTS) - 使用 OpenAI TTS
  Future<void> speak(String text) async {
    if (!isConfigured) {
      throw VoiceServiceException('API 密钥未配置');
    }

    if (text.isEmpty) return;

    try {
      final response = await _dio.post(
        '/audio/speech',
        data: {
          'model': 'tts-1',
          'input': text,
          'voice': 'nova', // 女声，清晰自然
          'response_format': 'mp3',
        },
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      // 保存音频到临时文件
      final dir = await getTemporaryDirectory();
      final audioPath = '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final file = File(audioPath);
      await file.writeAsBytes(response.data as Uint8List);

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
    } on DioException catch (e) {
      throw VoiceServiceException('语音合成失败: ${_parseError(e)}');
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

  String _parseError(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map && data['error'] != null) {
        final error = data['error'];
        if (error is Map && error['message'] != null) {
          return error['message'] as String;
        }
      }
    }
    return e.message ?? '网络请求失败';
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
  final aiConfig = ref.watch(aiConfigProvider);
  return VoiceService(aiConfig: aiConfig);
});
