-- BeeKas 0002: final campus list, major list, and required major for students.
-- Run in the SQL Editor after 0001. Safe to re-run: every constraint is
-- dropped if it exists and then added again.
--
-- Single-step migration (no expand/contract): beekas-dev is used by the team
-- only, and the pre-check found no profile outside the new lists. From Fase 7
-- on, constraint changes use two migrations (docs/workflow.md section 7).

-- ---------------------------------------------------------------------------
-- 1. Campus: final list
-- ---------------------------------------------------------------------------
-- Must match CAMPUSES in src/lib/domain/profile.ts.
-- A Vitest parity test parses the quoted codes between the BEGIN/END markers.
alter table public.profiles drop constraint if exists profiles_campus_check;
alter table public.profiles add constraint profiles_campus_check
  check (campus is null or campus in (
    -- BEGIN CAMPUSES
    'kemanggisan', 'senayan', 'alam_sutera', 'base', 'bekasi',
    'bandung', 'malang', 'semarang', 'online'
    -- END CAMPUSES
  ));

-- ---------------------------------------------------------------------------
-- 2. Major: value list
-- ---------------------------------------------------------------------------
-- Must match every code in MAJOR_GROUPS plus OTHER_MAJOR in
-- src/lib/domain/profile.ts. A Vitest parity test parses the quoted codes
-- between the BEGIN/END markers.
alter table public.profiles drop constraint if exists profiles_major_check;
alter table public.profiles add constraint profiles_major_check
  check (major is null or major in (
    -- BEGIN MAJORS
    'computer_science', 'mobile_application_technology', 'mathematics_computer_science',
    'statistics_computer_science', 'game_application_technology', 'cyber_security',
    'data_science', 'software_engineering', 'artificial_intelligence',
    'information_systems', 'business_information_technology', 'business_analytics',
    'digital_business_innovation',
    'visual_communication_design', 'interior_design', 'film', 'fashion',
    'architecture', 'civil_engineering', 'industrial_engineering', 'computer_engineering',
    'food_technology', 'biotechnology',
    'automotive_robotics_engineering', 'product_design_engineering', 'business_engineering',
    'global_business_chinese', 'creative_digital_english', 'japanese_popular_culture',
    'psychology', 'digital_psychology', 'business_law', 'international_relations',
    'primary_teacher_education',
    'accounting', 'finance', 'taxation',
    'hotel_management', 'business_hotel_management', 'tourism', 'marketing_communication',
    'mass_communication', 'creative_communication',
    'management', 'global_business_marketing', 'international_business_management',
    'business_creation', 'business_management', 'international_business',
    'business_management_marketing', 'digital_business', 'creativepreneurship',
    'entrepreneurship_business_creation', 'international_trade',
    'intl_computer_science', 'intl_business_information_systems',
    'intl_graphic_design_new_media', 'intl_communication',
    'intl_creative_digital_communication',
    'online_computer_science', 'online_information_systems', 'online_business_management',
    'online_finance', 'online_industrial_engineering', 'online_data_science',
    'online_business_analytics', 'online_digital_business_management',
    'other'
    -- END MAJORS
  ));

-- ---------------------------------------------------------------------------
-- 3. Students: major required (PRD F2.3)
-- ---------------------------------------------------------------------------
-- The profile row is created empty at sign-up (0001), so "required" cannot mean
-- "never null". A student must set major and binusian together: a row with
-- binusian but no major (or the reverse) is rejected. The app requires both
-- for students, so a completed student profile always has a major.
alter table public.profiles drop constraint if exists profiles_student_fields_check;
alter table public.profiles add constraint profiles_student_fields_check
  check (user_type <> 'student' or ((major is null) = (binusian is null)));

-- Staff: no major or binusian (unchanged from 0001, re-added for completeness).
alter table public.profiles drop constraint if exists profiles_staff_fields_check;
alter table public.profiles add constraint profiles_staff_fields_check
  check (user_type <> 'staff' or (major is null and binusian is null));
