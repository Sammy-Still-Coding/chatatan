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

    const userClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authorization } } },
    )

    const {
      data: { user },
    } = await userClient.auth.getUser()

    if (!user) throw new Error('Sesi pengguna tidak valid.')

    const { attachmentId } = await req.json()
    if (typeof attachmentId !== 'number') {
      throw new Error('attachmentId tidak valid.')
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { data: attachment, error } = await adminClient
      .from('forum_attachments')
      .select(`
        id,
        uploaded_by,
        curation_status,
        files (
          original_name,
          extension,
          mime_type,
          file_size
        ),
        forum_posts (
          title,
          content
        )
      `)
      .eq('id', attachmentId)
      .single()

    if (error || !attachment) {
      throw new Error('Attachment tidak ditemukan.')
    }

    if (attachment.uploaded_by !== user.id) {
      throw new Error('Tidak diizinkan mengkurasi attachment ini.')
    }

    if (attachment.curation_status !== 'PENDING') {
      return Response.json(
        { success: true, status: attachment.curation_status },
        { headers: corsHeaders },
      )
    }

    const file = Array.isArray(attachment.files)
      ? attachment.files[0]
      : attachment.files

    const post = Array.isArray(attachment.forum_posts)
      ? attachment.forum_posts[0]
      : attachment.forum_posts

    const systemPrompt = `
Kamu adalah AI kurator Forum ChaTatan, forum belajar mahasiswa Indonesia.

Nilai apakah file relevan dan pantas dibagikan berdasarkan konteks post dan metadata file.
Balas HANYA JSON valid dengan format berikut:

{
  "status": "PASSED" atau "FAILED",
  "relevance_score": angka 0 sampai 100,
  "relevance_label": "maksimal lima kata",
  "feedback": "maksimal 180 karakter"
}

Pilih FAILED hanya jika file jelas spam, format tidak relevan, atau tidak layak.
Jika informasinya terbatas tetapi masih tampak sebagai materi belajar, pilih PASSED dengan skor rendah/menengah.
`

    const userPrompt = JSON.stringify({
      post_title: post?.title,
      post_content: post?.content,
      file_name: file?.original_name,
      extension: file?.extension,
      mime_type: file?.mime_type,
      file_size: file?.file_size,
    })

    const groqKey = Deno.env.get('GROQ_API_KEY')
    if (!groqKey) throw new Error('GROQ_API_KEY belum diatur.')

    const groqResponse = await fetch(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${groqKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'llama-3.3-70b-versatile',
          temperature: 0.2,
          max_tokens: 220,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt },
          ],
        }),
      },
    )

    if (!groqResponse.ok) {
      const errorText = await groqResponse.text()
      throw new Error(`Groq gagal: ${errorText}`)
    }

    const groqData = await groqResponse.json()
    const aiText = groqData.choices?.[0]?.message?.content

    if (typeof aiText !== 'string') {
      throw new Error('Respons Groq kosong.')
    }

    const result = JSON.parse(aiText)
    const score = Number(result.relevance_score)

    if (
      !['PASSED', 'FAILED'].includes(result.status) ||
      !Number.isFinite(score) ||
      score < 0 ||
      score > 100
    ) {
      throw new Error('Format hasil AI tidak valid.')
    }

    const { error: updateError } = await adminClient
      .from('forum_attachments')
      .update({
        curation_status: result.status,
        relevance_score: score,
        relevance_label: String(result.relevance_label ?? '').slice(0, 80),
        curation_feedback: String(result.feedback ?? '').slice(0, 500),
        reviewed_at: new Date().toISOString(),
      })
      .eq('id', attachmentId)

    if (updateError) throw updateError

    return Response.json(
      {
        success: true,
        status: result.status,
        relevance_score: score,
        provider: 'groq',
      },
      { headers: corsHeaders },
    )
  } catch (error) {
    return Response.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Kurasi gagal.',
      },
      { status: 400, headers: corsHeaders },
    )
  }
})