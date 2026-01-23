interface Env {
  OPENAI_API_KEY: string;
  ALLOWED_ORIGIN: string;
}

const CORS_HEADERS = {
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function corsHeaders(origin: string, env: Env): Record<string, string> {
  const allowedOrigin = env.ALLOWED_ORIGIN || '*';
  return {
    ...CORS_HEADERS,
    'Access-Control-Allow-Origin': allowedOrigin === '*' ? origin || '*' : allowedOrigin,
  };
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get('Origin') || '*';
    const headers = corsHeaders(origin, env);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      if (path === '/realtime/token' && request.method === 'POST') {
        return await handleRealtimeToken(env, headers);
      }

      if (path === '/chat/completions' && request.method === 'POST') {
        return await handleChatCompletions(request, env, headers);
      }

      if (path === '/audio/transcriptions' && request.method === 'POST') {
        return await handleAudioTranscription(request, env, headers);
      }

      if (path === '/audio/speech' && request.method === 'POST') {
        return await handleAudioSpeech(request, env, headers);
      }

      if (path === '/images/generations' && request.method === 'POST') {
        return await handleImageGeneration(request, env, headers);
      }

      if (path === '/health') {
        return new Response(JSON.stringify({ status: 'ok', timestamp: Date.now() }), {
          headers: { ...headers, 'Content-Type': 'application/json' },
        });
      }

      return new Response(JSON.stringify({ error: 'Not Found' }), {
        status: 404,
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    } catch (error: any) {
      return new Response(JSON.stringify({ error: error.message || 'Internal Server Error' }), {
        status: 500,
        headers: { ...headers, 'Content-Type': 'application/json' },
      });
    }
  },
};

async function handleRealtimeToken(env: Env, headers: Record<string, string>): Promise<Response> {
  const response = await fetch('https://api.openai.com/v1/realtime/sessions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-realtime-preview-2024-12-17',
      voice: 'verse',
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    return new Response(JSON.stringify({ error: `OpenAI API error: ${error}` }), {
      status: response.status,
      headers: { ...headers, 'Content-Type': 'application/json' },
    });
  }

  const data: any = await response.json();
  return new Response(JSON.stringify({
    token: data.client_secret?.value,
    expires_at: data.expires_at,
  }), {
    headers: { ...headers, 'Content-Type': 'application/json' },
  });
}

async function handleChatCompletions(
  request: Request,
  env: Env,
  headers: Record<string, string>
): Promise<Response> {
  const body = await request.json();

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  const data = await response.json();
  return new Response(JSON.stringify(data), {
    status: response.status,
    headers: { ...headers, 'Content-Type': 'application/json' },
  });
}

async function handleAudioTranscription(
  request: Request,
  env: Env,
  headers: Record<string, string>
): Promise<Response> {
  // 获取原始请求的 form data
  const formData = await request.formData();

  // 创建新的 FormData 转发到 OpenAI
  const openaiFormData = new FormData();

  // 复制所有字段
  for (const [key, value] of formData.entries()) {
    openaiFormData.append(key, value);
  }

  // 确保 model 字段存在
  if (!formData.has('model')) {
    openaiFormData.append('model', 'whisper-1');
  }

  const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
    },
    body: openaiFormData,
  });

  const data = await response.json();
  return new Response(JSON.stringify(data), {
    status: response.status,
    headers: { ...headers, 'Content-Type': 'application/json' },
  });
}

async function handleAudioSpeech(
  request: Request,
  env: Env,
  headers: Record<string, string>
): Promise<Response> {
  const body = await request.json();

  const response = await fetch('https://api.openai.com/v1/audio/speech', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: body.model || 'tts-1',
      input: body.input,
      voice: body.voice || 'nova',
      response_format: body.response_format || 'mp3',
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    return new Response(JSON.stringify({ error: `OpenAI TTS error: ${error}` }), {
      status: response.status,
      headers: { ...headers, 'Content-Type': 'application/json' },
    });
  }

  // 返回音频二进制数据
  const audioData = await response.arrayBuffer();
  return new Response(audioData, {
    status: 200,
    headers: {
      ...headers,
      'Content-Type': 'audio/mpeg',
    },
  });
}

async function handleImageGeneration(
  request: Request,
  env: Env,
  headers: Record<string, string>
): Promise<Response> {
  const body = await request.json();

  const response = await fetch('https://api.openai.com/v1/images/generations', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: body.model || 'dall-e-3',
      prompt: body.prompt,
      n: body.n || 1,
      size: body.size || '1024x1024',
      quality: body.quality || 'standard',
    }),
  });

  const data = await response.json();
  return new Response(JSON.stringify(data), {
    status: response.status,
    headers: { ...headers, 'Content-Type': 'application/json' },
  });
}
