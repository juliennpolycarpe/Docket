-- Canvas through its calendar feed link: no API token or school approval needed.
-- Assignments go to To Do, course calendar events go to Upcoming.
alter type public.provider add value if not exists 'canvas_feed';
