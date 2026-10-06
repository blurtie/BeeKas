-- After OTP the app must tell a finished account (already registered) from a new or
-- abandoned sign-up (afterOtp, #27). encrypted_password cannot tell: GoTrue stores a random
-- hash when an OTP sign-up creates the user. The hash is written at INSERT, so only a later
-- UPDATE means the member chose a password (L6, and later Lupa kata sandi).

-- Members can read it with their profile but not write it (only status and phone are granted).
alter table public.profiles add column password_set_at timestamptz;

create function public.mark_password_set()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- No profile row yet just updates nothing; this must never fail an auth request.
  update public.profiles set password_set_at = now() where id = new.id;
  return null;
end;
$$;

create trigger on_auth_user_password_set
  after update of encrypted_password on auth.users
  for each row
  when (old.encrypted_password is distinct from new.encrypted_password)
  execute function public.mark_password_set();

-- Only the caller's own flag is returned, never a column of auth.users.
create function public.has_password()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select password_set_at is not null from public.profiles where id = auth.uid()), false);
$$;

revoke execute on function public.mark_password_set() from public, anon, authenticated;
revoke execute on function public.has_password() from public, anon;
grant execute on function public.has_password() to authenticated;
