-- Unindexed FK helpers + wrap auth.uid() as (select auth.uid())
-- so the planner initializes JWT claims once per statement (auth_rls_initplan).

create index if not exists comments_user_idx
  on public.comments (user_id);
create index if not exists meal_plans_recipe_idx
  on public.meal_plans (recipe_id);
create index if not exists meal_plans_leftover_of_idx
  on public.meal_plans (leftover_of);
create index if not exists notifications_actor_idx
  on public.notifications (actor_id);
create index if not exists notifications_recipe_idx
  on public.notifications (recipe_id);
create index if not exists profiles_household_idx
  on public.profiles (household_id);
create index if not exists recipe_photos_user_idx
  on public.recipe_photos (user_id);
create index if not exists saves_recipe_idx
  on public.saves (recipe_id);
create index if not exists shopping_items_recipe_idx
  on public.shopping_items (recipe_id);

-- profiles ------------------------------------------------
drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles for insert
  with check ((select auth.uid()) = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- recipes -------------------------------------------------
drop policy if exists "Authenticated users can create their own recipes" on public.recipes;
create policy "Authenticated users can create their own recipes"
  on public.recipes for insert
  to authenticated
  with check ((select auth.uid()) = author_id);

drop policy if exists "Authors can update their own recipes" on public.recipes;
create policy "Authors can update their own recipes"
  on public.recipes for update
  to authenticated
  using ((select auth.uid()) = author_id)
  with check ((select auth.uid()) = author_id);

drop policy if exists "Authors can delete their own recipes" on public.recipes;
create policy "Authors can delete their own recipes"
  on public.recipes for delete
  to authenticated
  using ((select auth.uid()) = author_id);

-- user_votes ----------------------------------------------
drop policy if exists "Users can view their own votes" on public.user_votes;
create policy "Users can view their own votes"
  on public.user_votes for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can cast their own votes" on public.user_votes;
create policy "Users can cast their own votes"
  on public.user_votes for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can change their own votes" on public.user_votes;
create policy "Users can change their own votes"
  on public.user_votes for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can remove their own votes" on public.user_votes;
create policy "Users can remove their own votes"
  on public.user_votes for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- saves ---------------------------------------------------
drop policy if exists "Users can view their own saves" on public.saves;
create policy "Users can view their own saves"
  on public.saves for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can save recipes" on public.saves;
create policy "Users can save recipes"
  on public.saves for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can unsave recipes" on public.saves;
create policy "Users can unsave recipes"
  on public.saves for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- comments ------------------------------------------------
drop policy if exists "Authenticated users can comment as themselves" on public.comments;
create policy "Authenticated users can comment as themselves"
  on public.comments for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can edit their own comments" on public.comments;
create policy "Users can edit their own comments"
  on public.comments for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own comments" on public.comments;
create policy "Users can delete their own comments"
  on public.comments for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- cooks ---------------------------------------------------
drop policy if exists "Users can view their own cooks" on public.cooks;
create policy "Users can view their own cooks"
  on public.cooks for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can record their own cooks" on public.cooks;
create policy "Users can record their own cooks"
  on public.cooks for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- device_tokens -------------------------------------------
drop policy if exists "Users can view their own device tokens" on public.device_tokens;
create policy "Users can view their own device tokens"
  on public.device_tokens for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can register their own device tokens" on public.device_tokens;
create policy "Users can register their own device tokens"
  on public.device_tokens for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own device tokens" on public.device_tokens;
create policy "Users can update their own device tokens"
  on public.device_tokens for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can remove their own device tokens" on public.device_tokens;
create policy "Users can remove their own device tokens"
  on public.device_tokens for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- notifications -------------------------------------------
drop policy if exists "Users can view their own notifications" on public.notifications;
create policy "Users can view their own notifications"
  on public.notifications for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can mark their own notifications read" on public.notifications;
create policy "Users can mark their own notifications read"
  on public.notifications for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own notifications" on public.notifications;
create policy "Users can delete their own notifications"
  on public.notifications for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- follows -------------------------------------------------
drop policy if exists "Users can view their own follows" on public.follows;
create policy "Users can view their own follows"
  on public.follows for select
  to authenticated
  using ((select auth.uid()) = follower_id);

drop policy if exists "Users can follow chefs" on public.follows;
create policy "Users can follow chefs"
  on public.follows for insert
  to authenticated
  with check ((select auth.uid()) = follower_id);

drop policy if exists "Users can unfollow chefs" on public.follows;
create policy "Users can unfollow chefs"
  on public.follows for delete
  to authenticated
  using ((select auth.uid()) = follower_id);

-- recipe_photos -------------------------------------------
drop policy if exists "Users can add their own recipe photos" on public.recipe_photos;
create policy "Users can add their own recipe photos"
  on public.recipe_photos for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own recipe photos" on public.recipe_photos;
create policy "Users can delete their own recipe photos"
  on public.recipe_photos for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- meal_plans (insert is the only policy that still calls auth.uid())
drop policy if exists "Users can add to their own meal plans" on public.meal_plans;
create policy "Users can add to their own meal plans"
  on public.meal_plans for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- shopping_items
drop policy if exists "Users can add their own shopping items" on public.shopping_items;
create policy "Users can add their own shopping items"
  on public.shopping_items for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- households / household_members
drop policy if exists "Members can view their household" on public.households;
create policy "Members can view their household"
  on public.households for select to authenticated
  using (
    exists (
      select 1 from public.household_members m
      where m.household_id = id and m.user_id = (select auth.uid())
    )
  );

drop policy if exists "Owners can update household" on public.households;
create policy "Owners can update household"
  on public.households for update to authenticated
  using (
    exists (
      select 1 from public.household_members m
      where m.household_id = id and m.user_id = (select auth.uid()) and m.role = 'owner'
    )
  );

drop policy if exists "Members can view household roster" on public.household_members;
create policy "Members can view household roster"
  on public.household_members for select to authenticated
  using (user_id = any (public.my_household_user_ids()) or user_id = (select auth.uid()));

-- storage (policies already present; wrap auth.uid())
drop policy if exists "Users upload recipe covers" on storage.objects;
create policy "Users upload recipe covers"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'recipe-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users update recipe covers" on storage.objects;
create policy "Users update recipe covers"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'recipe-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users upload to their own folder" on storage.objects;
create policy "Users upload to their own folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id in ('cook-photos', 'avatars')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users update their own objects" on storage.objects;
create policy "Users update their own objects"
  on storage.objects for update
  to authenticated
  using (
    bucket_id in ('cook-photos', 'avatars')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users delete their own objects" on storage.objects;
create policy "Users delete their own objects"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id in ('cook-photos', 'avatars')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
