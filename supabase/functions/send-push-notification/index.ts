import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from 'npm:google-auth-library@10'

type NotificationRecord = {
  user_id?: string
  title?: string
  body?: string
  entity_type?: string
  entity_id?: number | string
  data_json?: Record<string, unknown>
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })
  if (req.headers.get('x-push-webhook-secret') !== Deno.env.get('PUSH_WEBHOOK_SECRET')) {
    return new Response('Unauthorized', { status: 401 })
  }
  try {
    const payload = await req.json()
    const record = (payload.record ?? payload) as NotificationRecord
    if (!record.user_id) throw new Error('notification user_id is required')

    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )
    const { data: setting } = await admin
      .from('user_settings')
      .select('notification_enabled')
      .eq('user_id', record.user_id)
      .maybeSingle()
    if (setting?.notification_enabled === false) return Response.json({ sent: 0, disabled: true })

    const { data: devices, error } = await admin
      .from('user_devices')
      .select('push_token')
      .eq('user_id', record.user_id)
      .not('push_token', 'is', null)
    if (error) throw error
    const tokens = [...new Set((devices ?? []).map((device) => device.push_token).filter(Boolean))]
    if (tokens.length === 0) return Response.json({ sent: 0 })

    const credentials = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ?? '')
    const auth = new GoogleAuth({
      credentials,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })
    const accessToken = await auth.getAccessToken()
    if (!accessToken) throw new Error('Tidak dapat membuat akses FCM.')
    const data = {
      entity_type: String(record.entity_type ?? ''),
      entity_id: String(record.entity_id ?? ''),
      ...Object.fromEntries(Object.entries(record.data_json ?? {}).map(([key, value]) => [key, String(value)])),
    }
    const results = await Promise.all(tokens.map(async (token: string) => {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${credentials.project_id}/messages:send`,
        {
          method: 'POST',
          headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: {
              token,
              notification: { title: record.title ?? 'ChaTatan', body: record.body ?? '' },
              data,
              android: { priority: 'high', notification: { channel_id: 'chatatan_messages' } },
            },
          }),
        },
      )
      return response.ok
    }))
    return Response.json({ sent: results.filter(Boolean).length })
  } catch (error) {
    return Response.json({ error: error.message }, { status: 400 })
  }
})
