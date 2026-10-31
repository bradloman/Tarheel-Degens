-- Nines (three-player) points for a single hole; inputs are net strokes.
create or replace function public.nines_points(a integer,b integer,c integer)
returns integer[] language plpgsql immutable strict set search_path='' as $$
begin
 if a=b and b=c then return array[3,3,3]; end if;
 if a=b then return case when a<c then array[4,4,1] else array[2,2,5] end; end if;
 if a=c then return case when a<b then array[4,1,4] else array[2,5,2] end; end if;
 if b=c then return case when b<a then array[1,4,4] else array[5,2,2] end; end if;
 return array[case when a=least(a,b,c) then 5 when a=greatest(a,b,c) then 1 else 3 end,case when b=least(a,b,c) then 5 when b=greatest(a,b,c) then 1 else 3 end,case when c=least(a,b,c) then 5 when c=greatest(a,b,c) then 1 else 3 end];
end $$;
revoke all on function public.nines_points(integer,integer,integer) from public,anon;
grant execute on function public.nines_points(integer,integer,integer) to authenticated;
