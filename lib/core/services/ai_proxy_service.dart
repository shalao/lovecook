import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AI Proxy 基础 URL
const _defaultAiProxyBaseUrl = 'https://lovecook-ai-proxy.lovecook.workers.dev';

/// AI Proxy 服务异常
class AiProxyException implements Exception {
  final String message;
  final int? statusCode;

  AiProxyException(this.message, {this.statusCode});

  @override
  String toString() => 'AiProxyException: $message';
}

/// Realtime Token 响应
class RealtimeTokenResponse {
  final String token;
  final DateTime expiresAt;

  RealtimeTokenResponse({required this.token, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 统一的 AI 代理服务
class AiProxyService {
  final Dio _dio;
  final String _baseUrl;

  AiProxyService({String? baseUrl})
      : _baseUrl = baseUrl ?? _defaultAiProxyBaseUrl,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
        ));

  bool get isAvailable => _baseUrl.isNotEmpty;

  /// 发送 Chat Completions 请求
  Future<Map<String, dynamic>> chatCompletions({
    required List<Map<String, dynamic>> messages,
    String model = 'gpt-4o-mini',
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        data: {
          'model': model,
          'messages': messages,
          'temperature': temperature,
          if (maxTokens != null) 'max_tokens': maxTokens,
        },
      );

      if (response.statusCode != 200) {
        throw AiProxyException(
          'Chat API 调用失败: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw AiProxyException(_parseDioError(e), statusCode: e.response?.statusCode);
    }
  }

  /// 获取 Realtime API ephemeral token
  Future<RealtimeTokenResponse> getRealtimeToken() async {
    try {
      final response = await _dio.post('$_baseUrl/realtime/token');

      if (response.statusCode != 200) {
        throw AiProxyException(
          '获取 Token 失败: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final token = data['token'] as String?;
      final expiresAt = data['expires_at'] as int?;

      if (token == null || token.isEmpty) {
        throw AiProxyException('Token 响应无效');
      }

      return RealtimeTokenResponse(
        token: token,
        expiresAt: expiresAt != null
            ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
            : DateTime.now().add(const Duration(seconds: 60)),
      );
    } on DioException catch (e) {
      throw AiProxyException(_parseDioError(e), statusCode: e.response?.statusCode);
    }
  }

  /// 健康检查
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('$_baseUrl/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 语音转文字 (STT) - Whisper API
  Future<String> audioTranscription({
    required Uint8List audioData,
    required String filename,
    String language = 'zh',
    String model = 'whisper-1',
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(audioData, filename: filename),
        'model': model,
        'language': language,
      });

      final response = await _dio.post(
        '$_baseUrl/audio/transcriptions',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      if (response.statusCode != 200) {
        throw AiProxyException(
          '语音识别失败: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return response.data['text'] as String? ?? '';
    } on DioException catch (e) {
      throw AiProxyException(_parseDioError(e), statusCode: e.response?.statusCode);
    }
  }

  /// 文字转语音 (TTS) - Speech API
  Future<Uint8List> audioSpeech({
    required String text,
    String model = 'tts-1',
    String voice = 'nova',
    String responseFormat = 'mp3',
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/audio/speech',
        data: {
          'model': model,
          'input': text,
          'voice': voice,
          'response_format': responseFormat,
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode != 200) {
        throw AiProxyException(
          '语音合成失败: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return Uint8List.fromList(response.data as List<int>);
    } on DioException catch (e) {
      throw AiProxyException(_parseDioError(e), statusCode: e.response?.statusCode);
    }
  }

  /// 图片生成 (DALL-E)
  Future<String?> imageGeneration({
    required String prompt,
    String model = 'dall-e-3',
    String size = '1024x1024',
    String quality = 'standard',
    int n = 1,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/images/generations',
        data: {
          'model': model,
          'prompt': prompt,
          'n': n,
          'size': size,
          'quality': quality,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      if (response.statusCode != 200) {
        throw AiProxyException(
          '图片生成失败: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final data = response.data['data'] as List?;
      if (data != null && data.isNotEmpty) {
        return data[0]['url'] as String?;
      }
      return null;
    } on DioException catch (e) {
      throw AiProxyException(_parseDioError(e), statusCode: e.response?.statusCode);
    }
  }

  String _parseDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送超时，请检查网络';
      case DioExceptionType.receiveTimeout:
        return '接收超时，请检查网络';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['error'] ?? '服务器错误';
        return 'HTTP $statusCode: $message';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.connectionError:
        return '网络连接错误，请检查网络';
      default:
        return e.message ?? '未知错误';
    }
  }
}

/// AI Proxy 服务 Provider
final aiProxyServiceProvider = Provider<AiProxyService>((ref) {
  return AiProxyService();
});
