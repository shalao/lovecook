# 实时语音对话功能 - 开发者部署指南

本文档介绍如何部署实时语音对话服务。最终用户无需任何配置。

## 架构说明

```
┌─────────────────────────────────────────┐
│         Flutter App                      │
│   （内置 Worker URL，用户零配置）        │
└───────────────┬─────────────────────────┘
                │ 请求 Token
                ↓
┌─────────────────────────────────────────┐
│     Cloudflare Worker（开发者部署）      │
│   （环境变量配置 OPENAI_API_KEY）        │
└───────────────┬─────────────────────────┘
                │
                ↓
┌─────────────────────────────────────────┐
│        OpenAI Realtime API              │
└─────────────────────────────────────────┘
```

## 部署 Cloudflare Worker

### 1. 安装 Wrangler CLI

```bash
npm install -g wrangler
```

### 2. 登录 Cloudflare

```bash
wrangler login
```

### 3. 进入 Worker 目录

```bash
cd cloudflare-worker/realtime-token
```

### 4. 安装依赖

```bash
npm install
```

### 5. 设置 OpenAI API Key

```bash
wrangler secret put OPENAI_API_KEY
# 输入你的 OpenAI API Key
```

### 6. 部署

```bash
npm run deploy
```

部署成功后会返回 Worker URL，例如：
```
https://lovecook-realtime-token.your-subdomain.workers.dev
```

### 7. 更新 Flutter 代码

在 `lib/core/services/realtime_token_service.dart` 中更新 URL：

```dart
const _defaultRealtimeTokenEndpoint =
    'https://lovecook-realtime-token.your-subdomain.workers.dev';
```

## 本地测试

```bash
# 启动本地 Worker
cd cloudflare-worker/realtime-token
npm run dev

# 测试请求
curl -X POST http://localhost:8787
```

## 成本说明

### Cloudflare Workers
- 免费套餐：每天 100,000 次请求
- 对于个人使用完全足够

### OpenAI Realtime API（gpt-realtime-mini）
| 类型 | 价格/百万 tokens |
|------|------------------|
| 文本输入 | $0.60 |
| 文本输出 | $2.40 |
| 音频输入 | $10.00 |
| 音频输出 | $20.00 |

预估使用成本：
- 烹饪对话（3-5分钟）：¥3-8 元
- 推荐对话（1-2分钟）：¥1-3 元

## 故障排除

### Worker 部署失败
- 检查 Wrangler 是否已登录：`wrangler whoami`
- 检查 wrangler.toml 配置是否正确

### Token 获取失败
- 检查 OPENAI_API_KEY 是否已设置：`wrangler secret list`
- 查看 Worker 日志：`wrangler tail`
- 确保 API Key 有 Realtime API 权限

### 语音无法使用
- 确保使用 HTTPS（WebRTC 要求）
- 检查浏览器麦克风权限

## 相关文件

| 文件 | 说明 |
|------|------|
| `cloudflare-worker/realtime-token/` | Cloudflare Worker 源码 |
| `lib/core/services/realtime_token_service.dart` | Token 服务（内置 URL）|
| `lib/core/services/realtime_voice_service.dart` | WebRTC 语音服务 |
