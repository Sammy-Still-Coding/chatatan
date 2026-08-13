# Push notification deployment

1. Run the accompanying SQL migration in the Supabase SQL Editor.
2. Deploy: `supabase functions deploy send-push-notification --no-verify-jwt`
3. Set secrets (never put these in Flutter):
   - `PUSH_WEBHOOK_SECRET`: a long random value.
   - `FIREBASE_SERVICE_ACCOUNT_JSON`: the complete one-line JSON of a Firebase
     service account with Firebase Cloud Messaging permission.
4. Run `20260814_push_notification_trigger.sql`. Before it runs, store the
   same secret in Supabase Vault under `chatatan_push_webhook_secret`. The
   migration installs a database trigger for every `INSERT` in
   `public.notifications`; no Dashboard Database Webhook is required.
5. Configure Firebase for the Flutter app using `flutterfire configure` and
   ensure Android's application id is registered in the Firebase project.

The Edge Function sends only to the target user's FCM tokens stored in
`public.user_devices`. In-app notifications continue working independently.
