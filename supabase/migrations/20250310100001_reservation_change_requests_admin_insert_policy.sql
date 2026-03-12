-- Fix admin policy: allow insert when user is in public.users with role 'admin' (case-insensitive).
-- Ensures admin_id = auth.uid() so only the logged-in user can set themselves as admin.
-- Run migrations so this applies after 20250310100000.

drop policy if exists "reservation_change_requests_admin_insert" on public.reservation_change_requests;

create policy "reservation_change_requests_admin_insert"
  on public.reservation_change_requests for insert
  with check (
    auth.uid() is not null
    and admin_id = auth.uid()
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and lower(trim(u.role)) = 'admin'
    )
  );

-- Also fix select so admin can see all requests when role is stored as 'ADMIN' etc.
drop policy if exists "reservation_change_requests_select" on public.reservation_change_requests;

create policy "reservation_change_requests_select"
  on public.reservation_change_requests for select
  using (
    player_id = auth.uid()
    or exists (
      select 1 from public.users u
      where u.id = auth.uid() and lower(trim(u.role)) = 'admin'
    )
  );
