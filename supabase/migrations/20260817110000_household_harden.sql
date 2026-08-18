-- Harden household membership: no client inserts, RPCs only.

create or replace function public.create_household(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
  code text;
  tries int := 0;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  loop
    tries := tries + 1;
    code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    exit when not exists (select 1 from public.households where invite_code = code);
    if tries > 8 then
      raise exception 'CODE_GEN_FAILED';
    end if;
  end loop;

  delete from public.household_members where user_id = auth.uid();

  insert into public.households (name, invite_code)
  values (coalesce(nullif(trim(p_name), ''), 'Kitchen'), code)
  returning id into hid;

  insert into public.household_members (household_id, user_id, role)
  values (hid, auth.uid(), 'owner');

  update public.profiles set household_id = hid where id = auth.uid();
  return hid;
end;
$$;

grant execute on function public.create_household(text) to authenticated;

create or replace function public.join_household(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_code is null or length(trim(p_code)) < 6 then
    raise exception 'NOT_FOUND';
  end if;

  select id into hid
    from public.households
   where invite_code = upper(trim(p_code));
  if hid is null then
    raise exception 'NOT_FOUND';
  end if;

  -- Already in this kitchen: keep existing role (do not demote owner).
  if exists (
    select 1 from public.household_members
     where household_id = hid and user_id = auth.uid()
  ) then
    update public.profiles set household_id = hid where id = auth.uid();
    return hid;
  end if;

  delete from public.household_members where user_id = auth.uid();
  insert into public.household_members (household_id, user_id, role)
  values (hid, auth.uid(), 'member');
  update public.profiles set household_id = hid where id = auth.uid();
  return hid;
end;
$$;

create or replace function public.leave_household()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  hid uuid;
  was_owner boolean;
  other_owner uuid;
  other_member uuid;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select household_id, role = 'owner'
    into hid, was_owner
    from public.household_members
   where user_id = auth.uid()
   limit 1;

  if hid is null then
    update public.profiles set household_id = null where id = auth.uid();
    return;
  end if;

  delete from public.household_members where user_id = auth.uid();

  if was_owner then
    select user_id into other_owner
      from public.household_members
     where household_id = hid and role = 'owner'
     limit 1;
    if other_owner is null then
      select user_id into other_member
        from public.household_members
       where household_id = hid
       order by created_at
       limit 1;
      if other_member is not null then
        update public.household_members
           set role = 'owner'
         where household_id = hid and user_id = other_member;
      else
        delete from public.households where id = hid;
      end if;
    end if;
  end if;

  update public.profiles set household_id = null where id = auth.uid();
end;
$$;

grant execute on function public.leave_household() to authenticated;

drop policy if exists "Authenticated can create a household" on public.households;
drop policy if exists "Users can join a household" on public.household_members;
drop policy if exists "Users can leave a household" on public.household_members;

-- Membership writes only via SECURITY DEFINER RPCs.
create policy "No direct household member inserts"
  on public.household_members for insert to authenticated
  with check (false);

create policy "No direct household member deletes"
  on public.household_members for delete to authenticated
  using (false);
