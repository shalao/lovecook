# LoveCook Realtime Token Service

Cloudflare Worker 服务，用于生成 OpenAI Realtime API 的 ephemeral token。

## 快速部署

```bash
# 1. 安装 Wrangler
npm install -g wrangler

# 2. 登录 Cloudflare
wrangler login

# 3. 进入目录并安装依赖
cd cloudflare-worker/realtime-token
npm install

# 4. 设置 OpenAI API Key
wrangler secret put OPENAI_API_KEY

# 5. 部署
npm run deploy
```

## 本地测试

```bash
npm run dev
curl -X POST http://localhost:8787
```

## API 说明

### POST /

生成 ephemeral token。

**请求体（可选）：**
```json
{
  "model": "gpt-realtime-mini-2025-12-15"
}
```

**响应：**
```json
{
  "token": "ek_xxx...",
  "model": "gpt-realtime-mini-2025-12-15",
  "expires_at": "2024-01-01T00:00:00Z"
}
```

## 费用

- Cloudflare Workers 免费套餐：每天 100,000 次请求
- OpenAI Realtime API：按使用量计费


Success! It may take a few minutes for DNS records to update.
Visit https://dash.cloudflare.com/7bcbfab813a9566962577a9135a2d02c/workers/subdomain to edit your workers.dev subdomain
Deployed lovecook-realtime-token triggers (61.90 sec)
  https://lovecook-realtime-token.lovecook.workers.dev
Current Version ID: dd41c552-8f5c-4868-b54e-99feb4e3b106
