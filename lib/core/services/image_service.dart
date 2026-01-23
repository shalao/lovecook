import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'ai_proxy_service.dart';

/// 图片服务配置
class ImageServiceConfig {
  final String unsplashAccessKey;
  final bool useDallE;

  const ImageServiceConfig({
    this.unsplashAccessKey = '',
    this.useDallE = false,
  });

  bool get isUnsplashConfigured => unsplashAccessKey.isNotEmpty;
}

/// 图片服务 - 用于获取菜谱成品图
class ImageService {
  final Dio _dio;
  final ImageServiceConfig config;
  final AiProxyService _proxyService;

  ImageService({
    required this.config,
    required AiProxyService proxyService,
  })  : _proxyService = proxyService,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// 搜索美食图片 (Unsplash API)
  /// 返回图片 URL，如果搜索失败则返回 null
  Future<String?> searchFoodImage(String dishName) async {
    // 优先使用 Unsplash（免费）
    if (config.isUnsplashConfigured) {
      try {
        final response = await _dio.get(
          'https://api.unsplash.com/search/photos',
          queryParameters: {
            'query': '$dishName food chinese dish',
            'per_page': 1,
            'orientation': 'landscape',
          },
          options: Options(
            headers: {
              'Authorization': 'Client-ID ${config.unsplashAccessKey}',
            },
          ),
        );

        final results = response.data['results'] as List;
        if (results.isNotEmpty) {
          // 使用 small 尺寸以节省带宽
          return results[0]['urls']['small'] as String;
        }
      } catch (e) {
        // Unsplash 搜索失败，尝试其他方式
      }
    }

    // 如果启用了 DALL-E，使用代理服务生成图片
    if (config.useDallE) {
      return await generateFoodImage(dishName);
    }

    // 返回占位图 URL（使用菜名生成稳定的占位图）
    return _getPlaceholderImage(dishName);
  }

  /// 使用 DALL-E 生成菜品图片（通过代理服务）
  Future<String?> generateFoodImage(String dishName) async {
    try {
      return await _proxyService.imageGeneration(
        prompt: '一道精美的中式家常菜：$dishName，摆盘精致，自然光线，美食摄影风格，高清',
        model: 'dall-e-3',
        size: '1024x1024',
        quality: 'standard',
      );
    } on AiProxyException {
      // DALL-E 生成失败
      return null;
    }
  }

  /// 获取占位图（基于菜名的稳定哈希）
  String _getPlaceholderImage(String dishName) {
    // 使用 picsum.photos 作为占位图，基于菜名哈希生成稳定的图片
    final hash = dishName.hashCode.abs() % 1000;
    return 'https://picsum.photos/seed/$hash/400/300';
  }

  /// 批量为菜谱获取图片
  Future<Map<String, String?>> batchSearchImages(List<String> dishNames) async {
    final results = <String, String?>{};
    for (final name in dishNames) {
      results[name] = await searchFoodImage(name);
      // 添加小延迟避免请求过快
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return results;
  }
}

/// 图片服务配置 Provider
final imageServiceConfigProvider = StateProvider<ImageServiceConfig>((ref) {
  return const ImageServiceConfig();
});

/// 图片服务 Provider
final imageServiceProvider = Provider<ImageService>((ref) {
  final config = ref.watch(imageServiceConfigProvider);
  final proxyService = ref.watch(aiProxyServiceProvider);
  return ImageService(config: config, proxyService: proxyService);
});
