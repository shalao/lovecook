/**
 * LoveCook Realtime Token Service
 * Cloudflare Worker for generating OpenAI Realtime API ephemeral tokens
 *
 * 开发者部署时配置 OPENAI_API_KEY 环境变量
 * 最终用户无需任何配置
 */

/**
 * 处理 CORS 预检请求
 */
function handleOptions() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Max-Age': '86400',
    },
  });
}

/**
 * 添加 CORS 头到响应
 */
function addCorsHeaders(response) {
  const newHeaders = new Headers(response.headers);
  newHeaders.set('Access-Control-Allow-Origin', '*');
  newHeaders.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  newHeaders.set('Access-Control-Allow-Headers', 'Content-Type');

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: newHeaders,
  });
}

/**
 * 创建错误响应
 */
function errorResponse(message, status = 500) {
  return addCorsHeaders(
    new Response(JSON.stringify({ error: message }), {
      status,
      headers: { 'Content-Type': 'application/json' },
    })
  );
}

/**
 * 主处理函数
 */
export default {
  async fetch(request, env) {
    // 处理 CORS 预检请求
    if (request.method === 'OPTIONS') {
      return handleOptions();
    }

    // 只允许 POST 请求
    if (request.method !== 'POST') {
      return errorResponse('Method not allowed. Use POST.', 405);
    }

    // 检查环境变量
    if (!env.OPENAI_API_KEY) {
      console.error('OPENAI_API_KEY not configured');
      return errorResponse('Service not configured', 500);
    }

    try {
      // 解析请求体（可选，用于自定义模型）
      let model = 'gpt-realtime-mini-2025-12-15';
      try {
        const body = await request.json();
        if (body.model) {
          model = body.model;
        }
      } catch {
        // 忽略解析错误，使用默认模型
      }

      // 调用 OpenAI API 创建 Realtime session
      const response = await fetch('https://api.openai.com/v1/realtime/sessions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ model }),
      });

      // 检查 OpenAI 响应
      if (!response.ok) {
        const errorText = await response.text();
        console.error('OpenAI API error:', response.status, errorText);
        return errorResponse(`OpenAI API error: ${response.status}`, response.status);
      }

      const data = await response.json();

      // 提取 client_secret
      const token = data.client_secret?.value;
      if (!token) {
        console.error('Invalid OpenAI response:', JSON.stringify(data));
        return errorResponse('Invalid response from OpenAI', 500);
      }

      // 返回 token
      return addCorsHeaders(
        new Response(
          JSON.stringify({
            token,
            model,
            expires_at: data.expires_at,
          }),
          {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      );
    } catch (error) {
      console.error('Worker error:', error);
      return errorResponse(`Internal error: ${error.message}`, 500);
    }
  },
};
