# AI Edge Functions

Simpan key sebagai Supabase Edge Function secrets, bukan di Flutter.

PowerShell:

    supabase secrets set GROQ_API_KEY=...
    supabase secrets set CLOUDFLARE_ACCOUNT_ID=...
    supabase secrets set CLOUDFLARE_API_TOKEN=...

Deploy setelah login dan link project:

    supabase functions deploy curate-forum-attachment
    supabase functions deploy ai-chat

Kurasi menggunakan Groq lebih dulu, lalu Cloudflare Workers AI sebagai fallback.
Jika keduanya limit atau gagal, attachment tetap PENDING.
