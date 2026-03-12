-- Ensure every reservation_change_requests row has a matching notification so the
-- Notifications page (which only queries the notifications table) shows change requests.
-- 1) Trigger: on INSERT into reservation_change_requests, insert into notifications.
-- 2) Backfill: insert notifications for existing PENDING change requests that have no notification.

create or replace function public.notify_on_change_request_insert()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_court_name text;
  v_message text;
begin
  select c.name
  into v_court_name
  from public.reservations r
  join public.courts c on c.id = r.court_id
  where r.id = NEW.reservation_id;

  v_message := case
    when NEW.message is not null and trim(NEW.message) <> ''
    then 'Admin requested a new schedule. Message: ' || NEW.message
    else 'Admin requested to change your reservation schedule.'
  end;

  insert into public.notifications (
    user_id,
    title,
    message,
    is_read,
    type,
    reservation_id,
    change_request_id,
    court_name
  ) values (
    NEW.player_id,
    'Reservation Change Request',
    v_message,
    false,
    'reservation_change_request',
    NEW.reservation_id,
    NEW.id,
    v_court_name
  );

  return NEW;
end;
$$;

drop trigger if exists trigger_notify_on_change_request_insert on public.reservation_change_requests;

create trigger trigger_notify_on_change_request_insert
  after insert on public.reservation_change_requests
  for each row
  execute function public.notify_on_change_request_insert();

-- Backfill: add a notification for each PENDING change request that has no notification yet.
insert into public.notifications (
  user_id,
  title,
  message,
  is_read,
  type,
  reservation_id,
  change_request_id,
  court_name
)
select
  rcr.player_id,
  'Reservation Change Request',
  case
    when rcr.message is not null and trim(rcr.message) <> ''
    then 'Admin requested a new schedule. Message: ' || rcr.message
    else 'Admin requested to change your reservation schedule.'
  end,
  false,
  'reservation_change_request',
  rcr.reservation_id,
  rcr.id,
  (select c.name from public.reservations r join public.courts c on c.id = r.court_id where r.id = rcr.reservation_id)
from public.reservation_change_requests rcr
where rcr.status = 'PENDING'
  and not exists (
    select 1 from public.notifications n
    where n.change_request_id = rcr.id
  );
