-- D-51 fix: as in 20261120130000, except only live donations count (is_live,
-- PRD-katalog 7.1: not removed, not withdrawn, not expired, stock left). A donation
-- whose units were all given away no longer blocks its donor for the rest of its 60 days.
create or replace function public.check_donation_limit(p_member uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('donation-listings:' || p_member::text, 0));
  if (select count(*) from public.listings l
      where l.seller_id = p_member and l.is_donation and public.is_live(l)) >= 3 then
    raise exception 'donation_listing_limit' using errcode = 'check_violation';
  end if;
end;
$$;
