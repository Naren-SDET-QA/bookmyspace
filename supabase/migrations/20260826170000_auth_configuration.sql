insert into public.module_feature_configs (module_key, venue_id, metadata)
select 'auth', null, jsonb_build_object(
  'authentication_enabled', true,
  'signup_enabled', true,
  'phone_login_enabled', true,
  'phone_otp_enabled', true,
  'email_login_enabled', true,
  'email_otp_enabled', true,
  'password_login_enabled', true,
  'google_login_enabled', true,
  'apple_login_enabled', true
)
where not exists (
  select 1 from public.module_feature_configs
  where module_key = 'auth' and venue_id is null
);
