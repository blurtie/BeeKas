-- There is no BINUS BASE campus; the campus is BINUS ASO School of Engineering (Alam
-- Sutera area). Renaming the enum value keeps every row that used it.
alter type public.campus rename value 'base' to 'aso';

-- As in 20261119120000, with the new name.
create or replace function public.campus_area(p_campus public.campus)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_campus in ('kemanggisan', 'senayan', 'alam_sutera', 'aso', 'bekasi') then 'jabodetabek'
    when p_campus = 'online' then null
    else p_campus::text
  end;
$$;
