// VoiceService 测试文件
// 测试语音合成和播放功能
// 运行: NO_PROXY=localhost,127.0.0.1 flutter test test/features/cooking/data/services/voice_service_test.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:love_cook/core/services/ai_proxy_service.dart';
import 'package:love_cook/features/cooking/data/services/voice_service.dart';

@GenerateMocks([AiProxyService])
import 'voice_service_test.mocks.dart';

void main() {
  // 初始化 Flutter 测试绑定
  TestWidgetsFlutterBinding.ensureInitialized();

  // 模拟平台通道
  setUpAll(() {
    // Mock record plugin
    const MethodChannel recordChannel = MethodChannel('com.llfbandit.record/messages');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'create':
          return null;
        case 'dispose':
          return null;
        case 'hasPermission':
          return true;
        default:
          return null;
      }
    });

    // Mock just_audio plugin
    const MethodChannel audioChannel = MethodChannel('com.ryanheise.just_audio.methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, (MethodCall methodCall) async {
      return null;
    });

    // Mock audio_session plugin
    const MethodChannel sessionChannel = MethodChannel('com.ryanheise.audio_session');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sessionChannel, (MethodCall methodCall) async {
      return null;
    });
  });

  late MockAiProxyService mockProxyService;
  late VoiceService voiceService;

  setUp(() {
    mockProxyService = MockAiProxyService();
    voiceService = VoiceService(proxyService: mockProxyService);
  });

  tearDown(() async {
    await voiceService.dispose();
  });

  group('VoiceService', () {
    group('isConfigured', () {
      test('should return true because using server proxy', () {
        expect(voiceService.isConfigured, true);
      });
    });

    group('speak', () {
      test('should return immediately for empty text', () async {
        // 空文本应该直接返回，不调用 API
        await voiceService.speak('');

        verifyNever(mockProxyService.audioSpeech(
          text: anyNamed('text'),
          model: anyNamed('model'),
          voice: anyNamed('voice'),
          responseFormat: anyNamed('responseFormat'),
        ));
      });

      test('should call audioSpeech API with correct parameters', () async {
        // 模拟 API 返回音频数据
        final fakeAudioData = Uint8List.fromList([0x00, 0x01, 0x02]);
        when(mockProxyService.audioSpeech(
          text: anyNamed('text'),
          model: anyNamed('model'),
          voice: anyNamed('voice'),
          responseFormat: anyNamed('responseFormat'),
        )).thenAnswer((_) async => fakeAudioData);

        // 由于 just_audio 在测试环境中不能正常工作，我们只验证 API 调用
        // 实际播放逻辑需要在集成测试中验证
        try {
          await voiceService.speak('测试文本');
        } catch (_) {
          // 预期在测试环境中播放可能失败
        }

        verify(mockProxyService.audioSpeech(
          text: '测试文本',
          model: 'tts-1',
          voice: 'nova',
          responseFormat: 'mp3',
        )).called(1);
      });

      test('should throw VoiceServiceException on API error', () async {
        when(mockProxyService.audioSpeech(
          text: anyNamed('text'),
          model: anyNamed('model'),
          voice: anyNamed('voice'),
          responseFormat: anyNamed('responseFormat'),
        )).thenThrow(AiProxyException('网络错误'));

        expect(
          () => voiceService.speak('测试'),
          throwsA(isA<VoiceServiceException>().having(
            (e) => e.message,
            'message',
            contains('语音合成失败'),
          )),
        );
      });
    });

    group('stopSpeaking', () {
      test('should not throw when called without speaking', () async {
        // 没有播放时调用 stopSpeaking 不应该抛出异常
        await expectLater(voiceService.stopSpeaking(), completes);
      });
    });

    group('isPlaying', () {
      test('should return false initially', () {
        expect(voiceService.isPlaying, false);
      });
    });
  });

  group('VoiceServiceException', () {
    test('should store message correctly', () {
      final exception = VoiceServiceException('测试错误');
      expect(exception.message, '测试错误');
    });

    test('toString should return message', () {
      final exception = VoiceServiceException('语音合成失败');
      expect(exception.toString(), '语音合成失败');
    });
  });
}
