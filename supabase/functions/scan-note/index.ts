import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const authorization = req.headers.get('Authorization')
    if (!authorization) throw new Error('Tidak terautentikasi.')
    const client = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '', { global: { headers: { Authorization: authorization } } })
    const { data: { user } } = await client.auth.getUser()
    if (!user) throw new Error('Sesi pengguna tidak valid.')
    const { image_url } = await req.json()
    if (typeof image_url !== 'string' || !image_url.startsWith('data:image/')) throw new Error('Gambar scan wajib dikirim.')
    const key = Deno.env.get('GROQ_API_KEY')
    if (!key) throw new Error('GROQ_API_KEY belum diatur.')
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST', headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'qwen/qwen3.6-27b', temperature: 0, max_tokens: 1800,
        messages: [{ role: 'system', content: 'Kamu adalah mesin OCR, bukan asisten percakapan. Salin teks yang TERLIHAT apa adanya. DILARANG memberi analisis, daftar Identify, catatan, koreksi, penjelasan, atau reasoning. Balasan wajib memakai format persis berikut: [[OCR_START]] teks hasil OCR [[OCR_END]].' }, { role: 'user', content: [{ type: 'text', text: 'Transkripsikan teks gambar ini.' }, { type: 'image_url', image_url: { url: image_url } }] }],
      }),
    })
    if (!response.ok) throw new Error(`Groq tidak tersedia: ${await response.text()}`)
    const data = await response.json()
    const raw = data.choices?.[0]?.message?.content ?? ''
    const match = raw.match(/\[\[OCR_START\]\]([\s\S]*?)\[\[OCR_END\]\]/i)
    const text = (match?.[1] ?? raw)
      .replace(/<think>[\s\S]*?<\/think>/gi, '')
      .replace(/<\/?think>/gi, '')
      .trim()
    return Response.json({ text }, { headers: cors })
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : 'Scan gagal.' }, { status: 400, headers: cors })
  }
})
