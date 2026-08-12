type AiResult = {
  provider: 'groq' | 'cloudflare';
  content: string;
};

export async function requestAi({
  system,
  user,
  maxTokens = 600,
}: {
  system: string;
  user: string;
  maxTokens?: number;
}): Promise<AiResult> {
  const groqKey = Deno.env.get('GROQ_API_KEY');
  if (groqKey) {
    const response = await fetch(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          Authorization: 'Bearer ' + groqKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'llama-3.3-70b-versatile',
          temperature: 0.2,
          max_tokens: maxTokens,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: user },
          ],
        }),
      },
    );
    if (response.ok) {
      const data = await response.json();
      const content = data.choices?.[0]?.message?.content;
      if (typeof content === 'string' && content.length > 0) {
        return { provider: 'groq', content };
      }
    }
  }

  const accountId = Deno.env.get('CLOUDFLARE_ACCOUNT_ID');
  const token = Deno.env.get('CLOUDFLARE_API_TOKEN');
  if (!accountId || !token) {
    throw new Error('Tidak ada provider AI yang tersedia.');
  }
  const response = await fetch(
    'https://api.cloudflare.com/client/v4/accounts/' +
      accountId +
      '/ai/run/@cf/meta/llama-3.1-8b-instruct-fp8-fast',
    {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + token,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user },
        ],
        max_tokens: maxTokens,
      }),
    },
  );
  if (!response.ok) {
    throw new Error('Cloudflare AI tidak tersedia.');
  }
  const data = await response.json();
  const content = data.result?.response;
  if (typeof content !== 'string' || content.length === 0) {
    throw new Error('Respons AI kosong.');
  }
  return { provider: 'cloudflare', content };
}
