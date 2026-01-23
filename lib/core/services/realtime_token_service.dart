import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_proxy_service.dart';

/// Realtime Token 服务异常
class RealtimeTokenException implements Exception {
  final String message;
  final int? statusCode;

  RealtimeTokenException(this.message, {this.statusCode});

  @override
  String toString() => 'RealtimeTokenException: $message';
}

/// Realtime Token 服务
/// 负责获取 OpenAI Realtime API 的 ephemeral token
class RealtimeTokenService {
  final AiProxyService _aiProxyService;

  /// 缓存的 token
  RealtimeTokenResponse? _cachedToken;

  /// Token 提前刷新时间（秒）
  static const int _tokenRefreshBuffer = 30;

  RealtimeTokenService(this._aiProxyService);

  /// 服务是否可用
  bool get isAvailable => _aiProxyService.isAvailable;

  /// 获取 ephemeral token
  /// 如果缓存的 token 仍然有效，直接返回缓存
  Future<String> getToken() async {
    if (!isAvailable) {
      throw RealtimeTokenException('实时语音服务未配置');
    }

    // 检查缓存
    if (_cachedToken != null && !_isTokenExpiringSoon(_cachedToken!)) {
      return _cachedToken!.token;
    }

    // 获取新 token
    try {
      _cachedToken = await _aiProxyService.getRealtimeToken();
      return _cachedToken!.token;
    } on AiProxyException catch (e) {
      throw RealtimeTokenException(e.message, statusCode: e.statusCode);
    }
  }

  /// 检查 token 是否即将过期
  bool _isTokenExpiringSoon(RealtimeTokenResponse token) {
    final expiresAt = token.expiresAt.subtract(const Duration(seconds: _tokenRefreshBuffer));
    return DateTime.now().isAfter(expiresAt);
  }

  /// 清除缓存的 token
  void clearCache() {
    _cachedToken = null;
  }
}

/// Realtime Token 服务 Provider
final realtimeTokenServiceProvider = Provider<RealtimeTokenService>((ref) {
  final aiProxyService = ref.watch(aiProxyServiceProvider);
  return RealtimeTokenService(aiProxyService);
});
