-- An admin releases an account's phone when its real owner asks through Bantuan (D-04, #40).
-- The log keeps who, by whom, when and why, but never the number itself (D-26).
create table public.phone_releases (
  id bigint generated always as identity primary key,
  profile_id uuid references public.profiles on delete set null,
  released_by uuid references public.profiles on delete set null,
  released_at timestamptz not null default now(),
  note text not null check (btrim(note) <> '')
);

-- Written only by release_phone; admins read it, members do not.
alter table public.phone_releases enable row level security;
revoke all on public.phone_releases from anon, authenticated;
grant select on public.phone_releases to authenticated;
create policy "phone releases: admin reads"
  on public.phone_releases for select to authenticated
  using ((select public.is_admin()));

create function public.release_phone(p_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  note text := nullif(btrim(p_note), '');
begin
  if not public.is_admin() then
    raise exception 'not_admin' using errcode = 'insufficient_privilege';
  end if;
  if note is null then
    raise exception 'note_missing' using errcode = 'check_violation';
  end if;
  update public.profiles set phone = null where id = p_id and phone is not null;
  if not found then
    raise exception 'no_phone' using errcode = 'check_violation';
  end if;
  insert into public.phone_releases (profile_id, released_by, note)
  values (p_id, auth.uid(), note);
end;
$$;

revoke execute on function public.release_phone(uuid, text) from public, anon;
grant execute on function public.release_phone(uuid, text) to authenticated;
