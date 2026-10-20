-- Rejection with a reason, L15 (D-08, rule 9). Who rejected, when (last_rejected_at) and why
-- stay after the photos are deleted (D-07). Reasons are codes so L12 shows them in the
-- member's language; 'other' needs the note.
alter table public.profiles
  add column rejected_by uuid references public.profiles on delete set null,
  add column rejection_reasons text[],
  add column rejection_note text,
  add constraint rejection_reasons_known
    check (rejection_reasons <@ array['card', 'selfie', 'data', 'other']);

create or replace function public.guard_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status is distinct from old.status
    and old.status::text || '>' || new.status::text not in (
      'incomplete>pending', 'pending>approved', 'pending>rejected', 'rejected>pending'
    )
  then
    raise exception 'illegal_status_transition: % -> %', old.status, new.status
      using errcode = 'check_violation';
  end if;
  if new.status is distinct from old.status then
    case new.status
      when 'rejected' then
        new.last_rejected_at := now();
        new.rejected_by := auth.uid();
      when 'pending' then new.submitted_at := now();
      when 'approved' then
        new.approved_by := auth.uid();
        new.approved_at := now();
      else
    end case;
  end if;
  return new;
end;
$$;

create function public.reject_verification(p_id uuid, p_reasons text[], p_note text)
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
  -- Rule 9: at least one reason; 'other' says what in the note.
  if coalesce(cardinality(p_reasons), 0) = 0 or ('other' = any(p_reasons) and note is null) then
    raise exception 'reason_missing' using errcode = 'check_violation';
  end if;
  update public.profiles
    set status = 'rejected', rejection_reasons = p_reasons, rejection_note = note
    where id = p_id and status = 'pending';
  if not found then
    raise exception 'not_pending' using errcode = 'check_violation';
  end if;
end;
$$;

revoke execute on function public.reject_verification(uuid, text[], text) from public, anon;
grant execute on function public.reject_verification(uuid, text[], text) to authenticated;

-- Every status change now goes through a function (PR #52). Releasing a phone (#40) gets
-- its own function too.
revoke update on public.profiles from authenticated;
drop policy "profiles: admin updates" on public.profiles;
