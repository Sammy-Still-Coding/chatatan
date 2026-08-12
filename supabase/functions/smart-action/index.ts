import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const authorization = req.headers.get('Authorization')
    if (!authorization) throw new Error('Tidak terautentikasi.')
    const client = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '', { global: { headers: { Authorization: authorization } } })
    const { data: { user } } = await client.auth.getUser()
    if (!user) throw new Error('Sesi pengguna tidak valid.')
    const { message, history = [], attachments = [] } = await req.json()
    if (typeof message !== 'string' || !message.trim()) throw new Error('Pesan wajib diisi.')
    const key = Deno.env.get('GROQ_API_KEY')
    if (!key) throw new Error('GROQ_API_KEY belum diatur.')
    const image = Array.isArray(attachments) ? attachments.find((item) => String(item?.mime_type ?? '').startsWith('image/')) : null
    const content = [
      { type: 'text', text: message.trim() },
      ...(image?.url ? [{ type: 'image_url', image_url: { url: image.url } }] : []),
    ]
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST', headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: image ? 'llama-3.2-11b-vision-preview' : 'llama-3.1-8b-instant',
        temperature: .4, max_tokens: 700,
        messages: [
          { role: 'system', content: 'Kamu asisten belajar ChaTatan. Jawab jelas dalam bahasa Indonesia. Untuk dokumen yang tidak dapat dibaca langsung, katakan pengguna perlu menyalin teks atau mengunggah gambar halaman.' },
          ...(Array.isArray(history) ? history.slice(-8) : []),
          { role: 'user', content },
        ],
      }),
    })
    if (!response.ok) throw new Error(`Groq tidak tersedia: ${await response.text()}`)
    const data = await response.json()
    return Response.json({ answer: data.choices?.[0]?.message?.content ?? 'AI tidak memberi jawaban.', provider: 'groq' }, { headers: corsHeaders })
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : 'AI gagal.' }, { status: 400, headers: corsHeaders })
  }
})
