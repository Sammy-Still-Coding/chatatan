import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authorization = req.headers.get('Authorization')
    if (!authorization) throw new Error('Tidak terautentikasi.')
    const client = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authorization } } },
    )
    const {
      data: { user },
    } = await client.auth.getUser()
    if (!user) throw new Error('Sesi pengguna tidak valid.')

    const { message, history = [] } = await req.json()
    if (typeof message !== 'string' || message.trim().length === 0) {
      throw new Error('Pesan wajib diisi.')
    }

    const groqKey = Deno.env.get('GROQ_API_KEY')
    if (!groqKey) throw new Error('GROQ_API_KEY belum diatur.')
    const response = await fetch(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          Authorization: 'Bearer ' + groqKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'llama-3.1-8b-instant',
          temperature: 0.4,
          max_tokens: 500,
          messages: [
            {
              role: 'system',
              content:
                'Kamu adalah asisten belajar ChaTatan. Jawab ringkas dan jelas dalam bahasa Indonesia.',
            },
            ...(Array.isArray(history) ? history.slice(-8) : []),
            { role: 'user', content: message.trim() },
          ],
        }),
      },
    )
    if (!response.ok) throw new Error('Groq tidak tersedia: ' + await response.text())

    const data = await response.json()
    const answer = data.choices?.[0]?.message?.content
    if (typeof answer !== 'string' || answer.length === 0) {
      throw new Error('Respons Groq kosong.')
    }
    return Response.json(
      { answer, provider: 'groq' },
      { headers: corsHeaders },
    )
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : 'AI gagal.' },
      { status: 400, headers: corsHeaders },
    )
  }
})
