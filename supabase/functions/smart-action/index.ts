import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  let client: ReturnType<typeof createClient> | undefined
  let chargedCost = 0
  let userId = ''
  try {
    const authorization = req.headers.get('Authorization')
    if (!authorization) throw new Error('Tidak terautentikasi.')
    client = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authorization } } },
    )
    const { data: { user } } = await client.auth.getUser()
    if (!user) throw new Error('Sesi pengguna tidak valid.')
    userId = user.id

    const { message, history = [], attachments = [], model = 'standard' } = await req.json()
    if (typeof message !== 'string' || !message.trim()) throw new Error('Pesan wajib diisi.')
    if (model !== 'standard' && model !== 'advanced') throw new Error('Model AI tidak valid.')
    const image = Array.isArray(attachments)
      ? attachments.find((item) => String(item?.mime_type ?? '').startsWith('image/'))
      : null
    const hasAttachment = Array.isArray(attachments) && attachments.length > 0

    // Hanya endpoint AI chat ini yang memanggil RPC pengurang token.
    // Scan kamera dan kurasi Forum memakai endpoint lain sehingga bebas token.
    const { data: tokenStatus, error: tokenError } = await client.rpc('consume_ai_tokens', {
      p_model: model,
      p_has_attachment: hasAttachment,
    })
    if (tokenError) throw new Error(tokenError.message)
    chargedCost = Number(tokenStatus?.cost ?? 0)

    const key = Deno.env.get('GROQ_API_KEY')
    if (!key) throw new Error('GROQ_API_KEY belum diatur.')
    const content = [
      { type: 'text', text: message.trim() },
      ...(image?.url ? [{ type: 'image_url', image_url: { url: image.url } }] : []),
    ]
    // Standard hemat untuk teks, Pro terbuka setelah streak 100 hari.
    // Qwen dipilih bila ada gambar karena mendukung vision; PDF/DOCX tetap
    // dipreview di aplikasi, namun model tidak mengklaim dapat membaca file biner.
    const selectedModel = image
      ? 'qwen/qwen3.6-27b'
      : model === 'advanced'
      ? 'openai/gpt-oss-120b'
      : 'openai/gpt-oss-20b'
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: selectedModel,
        temperature: .4,
        max_tokens: 700,
        messages: [
          {
            role: 'system',
            content: 'Kamu asisten belajar ChaTatan. Jawab jelas dalam bahasa Indonesia. Jika lampiran berupa PDF atau dokumen yang tidak dapat kamu baca langsung, jelaskan keterbatasan itu dan minta pengguna menyalin teks atau mengirim gambar halaman.',
          },
          ...(Array.isArray(history) ? history.slice(-8) : []),
          { role: 'user', content },
        ],
      }),
    })
    if (!response.ok) throw new Error(`Groq tidak tersedia: ${await response.text()}`)
    const data = await response.json()
    return Response.json({
      answer: data.choices?.[0]?.message?.content ?? 'AI tidak memberi jawaban.',
      provider: 'groq',
      model: selectedModel,
      token_status: tokenStatus,
    }, { headers: corsHeaders })
  } catch (error) {
    // Jangan merugikan pengguna jika provider AI/API gagal setelah token dipesan.
    if (chargedCost > 0 && client) {
      const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
      if (serviceKey && userId) {
        const admin = createClient(Deno.env.get('SUPABASE_URL') ?? '', serviceKey)
        await admin.rpc('refund_ai_tokens_for_user', {
          p_user_id: userId,
          p_cost: chargedCost,
        })
      }
    }
    return Response.json(
      { error: error instanceof Error ? error.message : 'AI gagal.' },
      { status: 400, headers: corsHeaders },
    )
  }
})
