-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.users (
  id uuid NOT NULL,
  username text NOT NULL UNIQUE,
  email text NOT NULL UNIQUE,
  full_name text,
  bio text,
  avatar_url text,
  university text,
  major text,
  semester smallint,
  role text NOT NULL DEFAULT 'student'::text CHECK (role = ANY (ARRAY['student'::text, 'dosen'::text, 'admin'::text])),
  status text NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'suspended'::text, 'deleted'::text])),
  last_login_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_settings (
  user_id uuid NOT NULL,
  notification_enabled boolean NOT NULL DEFAULT true,
  sound_enabled boolean NOT NULL DEFAULT true,
  theme text NOT NULL DEFAULT 'system'::text,
  language text NOT NULL DEFAULT 'id'::text,
  ai_model_id bigint,
  privacy_profile text NOT NULL DEFAULT 'public'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_settings_pkey PRIMARY KEY (user_id),
  CONSTRAINT fk_user_settings_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_user_settings_ai_model FOREIGN KEY (ai_model_id) REFERENCES public.ai_models(id)
);
CREATE TABLE public.user_devices (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  device_name text,
  platform text CHECK (platform = ANY (ARRAY['android'::text, 'ios'::text, 'web'::text])),
  push_token text,
  app_version text,
  last_active_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_devices_pkey PRIMARY KEY (id),
  CONSTRAINT fk_user_devices_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.pets (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  name text NOT NULL,
  description text,
  image_url text,
  max_level integer NOT NULL DEFAULT 1,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  min_streak integer NOT NULL DEFAULT 0,
  CONSTRAINT pets_pkey PRIMARY KEY (id)
);
CREATE TABLE public.user_gamification (
  user_id uuid NOT NULL,
  token_balance bigint NOT NULL DEFAULT 0,
  total_points bigint NOT NULL DEFAULT 0,
  current_streak integer NOT NULL DEFAULT 0,
  longest_streak integer NOT NULL DEFAULT 0,
  current_level integer NOT NULL DEFAULT 1,
  pet_id bigint,
  pet_level integer NOT NULL DEFAULT 1,
  last_streak_date date,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  ai_week_started_at date,
  ai_weekly_capacity integer NOT NULL DEFAULT 100,
  CONSTRAINT user_gamification_pkey PRIMARY KEY (user_id),
  CONSTRAINT fk_user_gamification_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_user_gamification_pet FOREIGN KEY (pet_id) REFERENCES public.pets(id)
);
CREATE TABLE public.token_transactions (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  amount bigint NOT NULL,
  balance_after bigint NOT NULL,
  transaction_type text NOT NULL,
  reference_type text,
  reference_id bigint,
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT token_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT fk_token_transactions_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.point_transactions (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  amount bigint NOT NULL,
  transaction_type text NOT NULL,
  reference_type text,
  reference_id bigint,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT point_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT fk_point_transactions_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.user_streaks (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  activity_date date NOT NULL,
  streak_count integer NOT NULL,
  token_reward bigint NOT NULL DEFAULT 0,
  point_reward bigint NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_streaks_pkey PRIMARY KEY (id),
  CONSTRAINT fk_user_streaks_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.streak_rewards (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  streak_days integer NOT NULL,
  token_reward bigint NOT NULL DEFAULT 0,
  point_reward bigint NOT NULL DEFAULT 0,
  pet_exp_reward integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT streak_rewards_pkey PRIMARY KEY (id)
);
CREATE TABLE public.user_pets (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  pet_id bigint NOT NULL,
  level integer NOT NULL DEFAULT 1,
  experience integer NOT NULL DEFAULT 0,
  total_experience bigint NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_pets_pkey PRIMARY KEY (id),
  CONSTRAINT fk_user_pets_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_user_pets_pet FOREIGN KEY (pet_id) REFERENCES public.pets(id)
);
CREATE TABLE public.pet_levels (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  pet_id bigint NOT NULL,
  level integer NOT NULL,
  required_exp bigint NOT NULL,
  token_multiplier numeric NOT NULL DEFAULT 1.0,
  ai_quota_bonus integer NOT NULL DEFAULT 0,
  title text,
  image_url text,
  CONSTRAINT pet_levels_pkey PRIMARY KEY (id),
  CONSTRAINT fk_pet_levels_pet FOREIGN KEY (pet_id) REFERENCES public.pets(id)
);
CREATE TABLE public.leaderboard_snapshots (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  period_type text NOT NULL CHECK (period_type = ANY (ARRAY['weekly'::text, 'monthly'::text, 'all_time'::text])),
  period_start date NOT NULL,
  period_end date NOT NULL,
  user_id uuid NOT NULL,
  rank integer NOT NULL,
  points bigint NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT leaderboard_snapshots_pkey PRIMARY KEY (id),
  CONSTRAINT fk_leaderboard_snapshots_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.ai_models (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  name text NOT NULL,
  provider text,
  model_code text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  is_default boolean NOT NULL DEFAULT false,
  input_token_cost numeric NOT NULL DEFAULT 0,
  output_token_cost numeric NOT NULL DEFAULT 0,
  scan_cost numeric NOT NULL DEFAULT 0,
  max_context_tokens integer,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_models_pkey PRIMARY KEY (id)
);
CREATE TABLE public.ai_model_access (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  model_id bigint NOT NULL UNIQUE,
  minimum_level integer NOT NULL DEFAULT 1,
  token_cost bigint NOT NULL DEFAULT 0,
  daily_limit integer,
  is_available boolean NOT NULL DEFAULT true,
  CONSTRAINT ai_model_access_pkey PRIMARY KEY (id),
  CONSTRAINT fk_ai_model_access_model FOREIGN KEY (model_id) REFERENCES public.ai_models(id)
);
CREATE TABLE public.ai_conversations (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  model_id bigint,
  title text,
  conversation_type text NOT NULL DEFAULT 'GENERAL'::text CHECK (conversation_type = ANY (ARRAY['GENERAL'::text, 'NOTE_SCAN'::text, 'STUDY'::text, 'QUIZ'::text])),
  total_messages integer NOT NULL DEFAULT 0,
  total_tokens_used bigint NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT ai_conversations_pkey PRIMARY KEY (id),
  CONSTRAINT fk_ai_conversations_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_ai_conversations_model FOREIGN KEY (model_id) REFERENCES public.ai_models(id)
);
CREATE TABLE public.ai_messages (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  conversation_id bigint NOT NULL,
  sender_type text NOT NULL CHECK (sender_type = ANY (ARRAY['USER'::text, 'AI'::text, 'SYSTEM'::text])),
  user_id uuid,
  content text NOT NULL,
  message_type text NOT NULL DEFAULT 'TEXT'::text CHECK (message_type = ANY (ARRAY['TEXT'::text, 'IMAGE'::text, 'FILE'::text, 'SUMMARY'::text, 'FLASHCARD'::text, 'QUIZ'::text])),
  model_id bigint,
  input_tokens integer NOT NULL DEFAULT 0,
  output_tokens integer NOT NULL DEFAULT 0,
  total_tokens integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_messages_pkey PRIMARY KEY (id),
  CONSTRAINT fk_ai_messages_conversation FOREIGN KEY (conversation_id) REFERENCES public.ai_conversations(id),
  CONSTRAINT fk_ai_messages_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_ai_messages_model FOREIGN KEY (model_id) REFERENCES public.ai_models(id)
);
CREATE TABLE public.ai_scans (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  conversation_id bigint,
  model_id bigint,
  status text NOT NULL DEFAULT 'PENDING'::text CHECK (status = ANY (ARRAY['PENDING'::text, 'PROCESSING'::text, 'COMPLETED'::text, 'FAILED'::text])),
  source_type text CHECK (source_type = ANY (ARRAY['CAMERA'::text, 'GALLERY'::text, 'UPLOAD'::text])),
  ocr_text text,
  htr_text text,
  processing_time_ms integer,
  error_message text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  completed_at timestamp with time zone,
  CONSTRAINT ai_scans_pkey PRIMARY KEY (id),
  CONSTRAINT fk_ai_scans_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_ai_scans_conversation FOREIGN KEY (conversation_id) REFERENCES public.ai_conversations(id),
  CONSTRAINT fk_ai_scans_model FOREIGN KEY (model_id) REFERENCES public.ai_models(id)
);
CREATE TABLE public.ai_scan_files (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  scan_id bigint NOT NULL,
  file_id bigint NOT NULL,
  file_type text,
  page_number integer,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_scan_files_pkey PRIMARY KEY (id),
  CONSTRAINT fk_ai_scan_files_scan FOREIGN KEY (scan_id) REFERENCES public.ai_scans(id),
  CONSTRAINT fk_ai_scan_files_file FOREIGN KEY (file_id) REFERENCES public.files(id)
);
CREATE TABLE public.ai_outputs (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  scan_id bigint NOT NULL,
  output_type text NOT NULL CHECK (output_type = ANY (ARRAY['SUMMARY'::text, 'FLASHCARD'::text, 'QUIZ'::text, 'KEY_CONCEPT'::text, 'STRUCTURED_NOTE'::text])),
  title text,
  content text,
  metadata_json jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_outputs_pkey PRIMARY KEY (id),
  CONSTRAINT fk_ai_outputs_scan FOREIGN KEY (scan_id) REFERENCES public.ai_scans(id)
);
CREATE TABLE public.ai_usage_logs (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  model_id bigint NOT NULL,
  conversation_id bigint,
  scan_id bigint,
  operation_type text NOT NULL CHECK (operation_type = ANY (ARRAY['CHAT'::text, 'OCR'::text, 'HTR'::text, 'SUMMARY'::text, 'FLASHCARD'::text, 'QUIZ'::text, 'IMAGE_ANALYSIS'::text])),
  input_tokens integer NOT NULL DEFAULT 0,
  output_tokens integer NOT NULL DEFAULT 0,
  total_tokens integer NOT NULL DEFAULT 0,
  token_cost bigint NOT NULL DEFAULT 0,
  latency_ms integer,
  status text NOT NULL DEFAULT 'SUCCESS'::text CHECK (status = ANY (ARRAY['SUCCESS'::text, 'FAILED'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_usage_logs_pkey PRIMARY KEY (id),
  CONSTRAINT fk_ai_usage_logs_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_ai_usage_logs_model FOREIGN KEY (model_id) REFERENCES public.ai_models(id),
  CONSTRAINT fk_ai_usage_logs_conversation FOREIGN KEY (conversation_id) REFERENCES public.ai_conversations(id),
  CONSTRAINT fk_ai_usage_logs_scan FOREIGN KEY (scan_id) REFERENCES public.ai_scans(id)
);
CREATE TABLE public.files (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  uploaded_by uuid NOT NULL,
  storage_provider text NOT NULL DEFAULT 'Supabase'::text,
  storage_path text NOT NULL,
  original_name text,
  mime_type text,
  extension text,
  file_size bigint,
  width integer,
  height integer,
  checksum text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT files_pkey PRIMARY KEY (id),
  CONSTRAINT fk_files_uploaded_by FOREIGN KEY (uploaded_by) REFERENCES public.users(id)
);
CREATE TABLE public.library_folders (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  parent_folder_id bigint,
  name text NOT NULL,
  description text,
  color text,
  icon text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT library_folders_pkey PRIMARY KEY (id),
  CONSTRAINT fk_library_folders_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_library_folders_parent FOREIGN KEY (parent_folder_id) REFERENCES public.library_folders(id)
);
CREATE TABLE public.library_categories (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  name text NOT NULL,
  description text,
  icon text,
  color text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT library_categories_pkey PRIMARY KEY (id)
);
CREATE TABLE public.library_items (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  folder_id bigint,
  category_id bigint,
  title text NOT NULL,
  description text,
  source_type text CHECK (source_type = ANY (ARRAY['AI_SCAN'::text, 'UPLOAD'::text, 'SHARED'::text, 'MANUAL'::text])),
  content_type text CHECK (content_type = ANY (ARRAY['PDF'::text, 'IMAGE'::text, 'DOCUMENT'::text, 'TEXT'::text, 'NOTE'::text, 'FLASHCARD'::text, 'QUIZ'::text])),
  file_id bigint,
  ai_scan_id bigint,
  visibility text NOT NULL DEFAULT 'PRIVATE'::text CHECK (visibility = ANY (ARRAY['PRIVATE'::text, 'SHARED'::text])),
  is_favorite boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT library_items_pkey PRIMARY KEY (id),
  CONSTRAINT fk_library_items_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_library_items_folder FOREIGN KEY (folder_id) REFERENCES public.library_folders(id),
  CONSTRAINT fk_library_items_category FOREIGN KEY (category_id) REFERENCES public.library_categories(id),
  CONSTRAINT fk_library_items_file FOREIGN KEY (file_id) REFERENCES public.files(id),
  CONSTRAINT fk_library_items_scan FOREIGN KEY (ai_scan_id) REFERENCES public.ai_scans(id)
);
CREATE TABLE public.library_shares (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  library_item_id bigint NOT NULL,
  shared_by uuid NOT NULL,
  target_type text NOT NULL CHECK (target_type = ANY (ARRAY['GROUP'::text, 'FORUM'::text, 'PRIVATE'::text])),
  target_id bigint NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT library_shares_pkey PRIMARY KEY (id),
  CONSTRAINT fk_library_shares_item FOREIGN KEY (library_item_id) REFERENCES public.library_items(id),
  CONSTRAINT fk_library_shares_user FOREIGN KEY (shared_by) REFERENCES public.users(id)
);
CREATE TABLE public.forum_categories (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  icon text,
  color text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT forum_categories_pkey PRIMARY KEY (id)
);
CREATE TABLE public.forum_posts (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  category_id bigint NOT NULL,
  title text NOT NULL,
  content text NOT NULL,
  status text NOT NULL DEFAULT 'ACTIVE'::text CHECK (status = ANY (ARRAY['ACTIVE'::text, 'CLOSED'::text, 'DELETED'::text])),
  views_count integer NOT NULL DEFAULT 0,
  like_count integer NOT NULL DEFAULT 0,
  dislike_count integer NOT NULL DEFAULT 0,
  reply_count integer NOT NULL DEFAULT 0,
  bookmark_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT forum_posts_pkey PRIMARY KEY (id),
  CONSTRAINT fk_forum_posts_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_forum_posts_category FOREIGN KEY (category_id) REFERENCES public.forum_categories(id)
);
CREATE TABLE public.forum_reactions (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  post_id bigint NOT NULL,
  user_id uuid NOT NULL,
  reaction text NOT NULL CHECK (reaction = ANY (ARRAY['LIKE'::text, 'DISLIKE'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT forum_reactions_pkey PRIMARY KEY (id),
  CONSTRAINT fk_forum_reactions_post FOREIGN KEY (post_id) REFERENCES public.forum_posts(id),
  CONSTRAINT fk_forum_reactions_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.forum_replies (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  post_id bigint NOT NULL,
  user_id uuid NOT NULL,
  parent_reply_id bigint,
  content text NOT NULL,
  like_count integer NOT NULL DEFAULT 0,
  dislike_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT forum_replies_pkey PRIMARY KEY (id),
  CONSTRAINT fk_forum_replies_post FOREIGN KEY (post_id) REFERENCES public.forum_posts(id),
  CONSTRAINT fk_forum_replies_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_forum_replies_parent FOREIGN KEY (parent_reply_id) REFERENCES public.forum_replies(id)
);
CREATE TABLE public.forum_reply_reactions (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  reply_id bigint NOT NULL,
  user_id uuid NOT NULL,
  reaction text NOT NULL CHECK (reaction = ANY (ARRAY['LIKE'::text, 'DISLIKE'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT forum_reply_reactions_pkey PRIMARY KEY (id),
  CONSTRAINT fk_forum_reply_reactions_reply FOREIGN KEY (reply_id) REFERENCES public.forum_replies(id),
  CONSTRAINT fk_forum_reply_reactions_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.forum_bookmarks (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  post_id bigint NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT forum_bookmarks_pkey PRIMARY KEY (id),
  CONSTRAINT fk_forum_bookmarks_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_forum_bookmarks_post FOREIGN KEY (post_id) REFERENCES public.forum_posts(id)
);
CREATE TABLE public.forum_attachments (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  post_id bigint,
  reply_id bigint,
  file_id bigint NOT NULL,
  uploaded_by uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  curation_status text NOT NULL DEFAULT 'PENDING'::text CHECK (curation_status = ANY (ARRAY['PENDING'::text, 'PASSED'::text, 'FAILED'::text])),
  curation_feedback text,
  relevance_score numeric CHECK (relevance_score IS NULL OR relevance_score >= 0::numeric AND relevance_score <= 100::numeric),
  relevance_label text,
  reviewed_at timestamp with time zone,
  CONSTRAINT forum_attachments_pkey PRIMARY KEY (id),
  CONSTRAINT fk_forum_attachments_post FOREIGN KEY (post_id) REFERENCES public.forum_posts(id),
  CONSTRAINT fk_forum_attachments_reply FOREIGN KEY (reply_id) REFERENCES public.forum_replies(id),
  CONSTRAINT fk_forum_attachments_file FOREIGN KEY (file_id) REFERENCES public.files(id),
  CONSTRAINT fk_forum_attachments_uploader FOREIGN KEY (uploaded_by) REFERENCES public.users(id)
);
CREATE TABLE public.note_validations (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  library_item_id bigint NOT NULL,
  submitted_by uuid NOT NULL,
  score numeric,
  threshold numeric,
  status text NOT NULL DEFAULT 'PENDING'::text CHECK (status = ANY (ARRAY['PENDING'::text, 'PASSED'::text, 'FAILED'::text])),
  feedback text,
  validated_at timestamp with time zone,
  CONSTRAINT note_validations_pkey PRIMARY KEY (id),
  CONSTRAINT fk_note_validations_item FOREIGN KEY (library_item_id) REFERENCES public.library_items(id),
  CONSTRAINT fk_note_validations_user FOREIGN KEY (submitted_by) REFERENCES public.users(id)
);
CREATE TABLE public.groups (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  name text NOT NULL,
  description text,
  avatar_file_id bigint,
  created_by uuid NOT NULL,
  group_type text NOT NULL DEFAULT 'GENERAL'::text CHECK (group_type = ANY (ARRAY['COURSE'::text, 'CLASS'::text, 'PROJECT'::text, 'STUDY'::text, 'GENERAL'::text])),
  privacy text NOT NULL DEFAULT 'PUBLIC'::text CHECK (privacy = ANY (ARRAY['PUBLIC'::text, 'PRIVATE'::text, 'INVITE_ONLY'::text])),
  category_id bigint,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT groups_pkey PRIMARY KEY (id),
  CONSTRAINT fk_groups_avatar_file FOREIGN KEY (avatar_file_id) REFERENCES public.files(id),
  CONSTRAINT fk_groups_created_by FOREIGN KEY (created_by) REFERENCES public.users(id)
);
CREATE TABLE public.group_members (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  group_id bigint NOT NULL,
  user_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'MEMBER'::text CHECK (role = ANY (ARRAY['OWNER'::text, 'ADMIN'::text, 'MEMBER'::text])),
  status text NOT NULL DEFAULT 'ACTIVE'::text CHECK (status = ANY (ARRAY['ACTIVE'::text, 'LEFT'::text, 'BANNED'::text])),
  joined_at timestamp with time zone NOT NULL DEFAULT now(),
  last_read_message_id bigint,
  CONSTRAINT group_members_pkey PRIMARY KEY (id),
  CONSTRAINT fk_group_members_group FOREIGN KEY (group_id) REFERENCES public.groups(id),
  CONSTRAINT fk_group_members_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_group_members_last_read FOREIGN KEY (last_read_message_id) REFERENCES public.messages(id)
);
CREATE TABLE public.group_notes (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  group_id bigint NOT NULL,
  library_item_id bigint NOT NULL,
  shared_by uuid NOT NULL,
  learning_card_title text,
  preview_text text,
  validation_status text NOT NULL DEFAULT 'PENDING'::text CHECK (validation_status = ANY (ARRAY['PENDING'::text, 'PASSED'::text, 'FAILED'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT group_notes_pkey PRIMARY KEY (id),
  CONSTRAINT fk_group_notes_group FOREIGN KEY (group_id) REFERENCES public.groups(id),
  CONSTRAINT fk_group_notes_item FOREIGN KEY (library_item_id) REFERENCES public.library_items(id),
  CONSTRAINT fk_group_notes_user FOREIGN KEY (shared_by) REFERENCES public.users(id)
);
CREATE TABLE public.conversations (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  conversation_type text NOT NULL CHECK (conversation_type = ANY (ARRAY['PRIVATE'::text, 'GROUP'::text, 'AI'::text])),
  group_id bigint,
  created_by uuid NOT NULL,
  title text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  description text,
  avatar_url text,
  CONSTRAINT conversations_pkey PRIMARY KEY (id),
  CONSTRAINT fk_conversations_group FOREIGN KEY (group_id) REFERENCES public.groups(id),
  CONSTRAINT fk_conversations_created_by FOREIGN KEY (created_by) REFERENCES public.users(id)
);
CREATE TABLE public.conversation_members (
  conversation_id bigint NOT NULL,
  user_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'MEMBER'::text CHECK (role = ANY (ARRAY['MEMBER'::text, 'ADMIN'::text])),
  joined_at timestamp with time zone NOT NULL DEFAULT now(),
  last_read_message_id bigint,
  muted_until timestamp with time zone,
  CONSTRAINT conversation_members_pkey PRIMARY KEY (conversation_id, user_id),
  CONSTRAINT fk_conversation_members_conv FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
  CONSTRAINT fk_conversation_members_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_conversation_members_last_read FOREIGN KEY (last_read_message_id) REFERENCES public.messages(id)
);
CREATE TABLE public.messages (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  conversation_id bigint NOT NULL,
  sender_id uuid,
  message_type text NOT NULL DEFAULT 'TEXT'::text CHECK (message_type = ANY (ARRAY['TEXT'::text, 'IMAGE'::text, 'FILE'::text, 'NOTE'::text, 'LEARNING_CARD'::text, 'SYSTEM'::text])),
  content text,
  reply_to_message_id bigint,
  status text NOT NULL DEFAULT 'SENT'::text CHECK (status = ANY (ARRAY['SENT'::text, 'DELIVERED'::text, 'READ'::text, 'DELETED'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT fk_messages_conversation FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
  CONSTRAINT fk_messages_sender FOREIGN KEY (sender_id) REFERENCES public.users(id),
  CONSTRAINT fk_messages_reply_to FOREIGN KEY (reply_to_message_id) REFERENCES public.messages(id)
);
CREATE TABLE public.message_attachments (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  message_id bigint NOT NULL,
  file_id bigint NOT NULL,
  attachment_type text CHECK (attachment_type = ANY (ARRAY['IMAGE'::text, 'FILE'::text, 'DOCUMENT'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT message_attachments_pkey PRIMARY KEY (id),
  CONSTRAINT fk_message_attachments_message FOREIGN KEY (message_id) REFERENCES public.messages(id),
  CONSTRAINT fk_message_attachments_file FOREIGN KEY (file_id) REFERENCES public.files(id)
);
CREATE TABLE public.message_reactions (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  message_id bigint NOT NULL,
  user_id uuid NOT NULL,
  reaction text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT message_reactions_pkey PRIMARY KEY (id),
  CONSTRAINT fk_message_reactions_message FOREIGN KEY (message_id) REFERENCES public.messages(id),
  CONSTRAINT fk_message_reactions_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.notification_types (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  default_enabled boolean NOT NULL DEFAULT true,
  CONSTRAINT notification_types_pkey PRIMARY KEY (id)
);
CREATE TABLE public.notifications (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  type text NOT NULL,
  title text NOT NULL,
  body text,
  actor_user_id uuid,
  entity_type text,
  entity_id bigint,
  data_json jsonb,
  is_read boolean NOT NULL DEFAULT false,
  read_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_notifications_actor FOREIGN KEY (actor_user_id) REFERENCES public.users(id)
);
CREATE TABLE public.user_notification_settings (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  notification_type_id bigint NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  CONSTRAINT user_notification_settings_pkey PRIMARY KEY (id),
  CONSTRAINT fk_user_notif_settings_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_user_notif_settings_type FOREIGN KEY (notification_type_id) REFERENCES public.notification_types(id)
);
CREATE TABLE public.achievements (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  icon_url text,
  category text,
  requirement_type text,
  requirement_value bigint,
  reward_token bigint NOT NULL DEFAULT 0,
  reward_points bigint NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT achievements_pkey PRIMARY KEY (id)
);
CREATE TABLE public.user_achievements (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  achievement_id bigint NOT NULL,
  progress bigint NOT NULL DEFAULT 0,
  unlocked_at timestamp with time zone,
  claimed_at timestamp with time zone,
  CONSTRAINT user_achievements_pkey PRIMARY KEY (id),
  CONSTRAINT fk_user_achievements_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_user_achievements_achievement FOREIGN KEY (achievement_id) REFERENCES public.achievements(id)
);
CREATE TABLE public.user_activity_logs (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  activity_type text NOT NULL,
  entity_type text,
  entity_id bigint,
  metadata_json jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_activity_logs_pkey PRIMARY KEY (id),
  CONSTRAINT fk_user_activity_logs_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.user_statistics (
  user_id uuid NOT NULL,
  total_ai_usage bigint NOT NULL DEFAULT 0,
  total_ai_messages bigint NOT NULL DEFAULT 0,
  total_ai_scans bigint NOT NULL DEFAULT 0,
  total_notes bigint NOT NULL DEFAULT 0,
  total_notes_shared bigint NOT NULL DEFAULT 0,
  total_forum_posts bigint NOT NULL DEFAULT 0,
  total_forum_replies bigint NOT NULL DEFAULT 0,
  total_forum_likes_given bigint NOT NULL DEFAULT 0,
  total_forum_likes_received bigint NOT NULL DEFAULT 0,
  total_forum_dislikes_given bigint NOT NULL DEFAULT 0,
  total_groups_joined bigint NOT NULL DEFAULT 0,
  total_groups_created bigint NOT NULL DEFAULT 0,
  total_private_messages bigint NOT NULL DEFAULT 0,
  total_group_messages bigint NOT NULL DEFAULT 0,
  total_files_uploaded bigint NOT NULL DEFAULT 0,
  total_learning_cards bigint NOT NULL DEFAULT 0,
  total_quizzes bigint NOT NULL DEFAULT 0,
  total_flashcards bigint NOT NULL DEFAULT 0,
  total_streak_days bigint NOT NULL DEFAULT 0,
  longest_streak bigint NOT NULL DEFAULT 0,
  total_points bigint NOT NULL DEFAULT 0,
  total_tokens_earned bigint NOT NULL DEFAULT 0,
  total_tokens_spent bigint NOT NULL DEFAULT 0,
  profile_views bigint NOT NULL DEFAULT 0,
  last_activity_at timestamp with time zone,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_statistics_pkey PRIMARY KEY (user_id),
  CONSTRAINT fk_user_statistics_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.reports (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  reporter_id uuid NOT NULL,
  target_type text NOT NULL CHECK (target_type = ANY (ARRAY['USER'::text, 'POST'::text, 'REPLY'::text, 'MESSAGE'::text, 'GROUP'::text, 'FILE'::text])),
  target_id bigint NOT NULL,
  reason text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'PENDING'::text CHECK (status = ANY (ARRAY['PENDING'::text, 'REVIEWING'::text, 'RESOLVED'::text, 'REJECTED'::text])),
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT reports_pkey PRIMARY KEY (id),
  CONSTRAINT fk_reports_reporter FOREIGN KEY (reporter_id) REFERENCES public.users(id),
  CONSTRAINT fk_reports_reviewer FOREIGN KEY (reviewed_by) REFERENCES public.users(id)
);
CREATE TABLE public.user_blocks (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  blocked_user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_blocks_pkey PRIMARY KEY (id),
  CONSTRAINT fk_user_blocks_user FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT fk_user_blocks_blocked FOREIGN KEY (blocked_user_id) REFERENCES public.users(id)
);
CREATE TABLE public.audit_logs (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id bigint,
  old_data_json jsonb,
  new_data_json jsonb,
  ip_address text,
  user_agent text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id),
  CONSTRAINT fk_audit_logs_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.search_history (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  query text NOT NULL,
  search_type text CHECK (search_type = ANY (ARRAY['LIBRARY'::text, 'FORUM'::text, 'GROUP'::text, 'CHAT'::text, 'GLOBAL'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT search_history_pkey PRIMARY KEY (id),
  CONSTRAINT fk_search_history_user FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.user_presence (
  user_id uuid NOT NULL,
  is_online boolean NOT NULL DEFAULT false,
  last_seen_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_presence_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_presence_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);
CREATE TABLE public.conversation_member_settings (
  conversation_id bigint NOT NULL,
  user_id uuid NOT NULL,
  nickname text,
  is_pinned boolean NOT NULL DEFAULT false,
  pinned_at timestamp with time zone,
  CONSTRAINT conversation_member_settings_pkey PRIMARY KEY (conversation_id, user_id),
  CONSTRAINT conversation_member_settings_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
  CONSTRAINT conversation_member_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);