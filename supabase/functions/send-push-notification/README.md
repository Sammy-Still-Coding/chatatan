# Push notification deployment

1. Run the accompanying SQL migration in the Supabase SQL Editor.
2. Deploy: `supabase functions deploy send-push-notification --no-verify-jwt`
3. Set secrets (never put these in Flutter):
   - `PUSH_WEBHOOK_SECRET`: a long random value.
   - `FIREBASE_SERVICE_ACCOUNT_JSON`: the complete one-line JSON of a Firebase
     service account with Firebase Cloud Messaging permission.
4. In Supabase Dashboard > Database > Webhooks, create a webhook for
   `public.notifications` on `INSERT`:
   - URL: `https://<project-ref>.supabase.co/functions/v1/send-push-notification`
   - Header: `x-push-webhook-secret: <same random value>`
   - Body: use the default database-webhook payload (it contains `record`).
5. Configure Firebase for the Flutter app using `flutterfire configure` and
   ensure Android's application id is registered in the Firebase project.

The Edge Function sends only to the target user's FCM tokens stored in
`public.user_devices`. In-app notifications continue working independently.
