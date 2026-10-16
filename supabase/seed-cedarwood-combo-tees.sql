-- Cedarwood CC: USGA-rated men's combination tees.
-- Source: https://ncrdb.usga.org/courseTeeInfo?CourseID=67
-- Hole par and men's stroke index follow the published Cedarwood scorecard.
do $$
declare cid uuid; tid uuid; t record;
 pars integer[] := array[4,4,3,5,4,4,4,5,3,4,3,5,4,4,4,4,3,4];
 ranks integer[] := array[11,5,17,9,13,1,7,3,15,12,16,10,14,2,6,4,18,8];
begin
 select id into cid from public.courses where name='Cedarwood Country Club' and city='Charlotte' limit 1;
 if cid is null then raise exception 'Cedarwood Country Club not found. Run the initial Cedarwood seed first.'; end if;
 for t in select * from (values ('Black/Blue',72.6::numeric,136),('Blue/White',70.7::numeric,131)) as v(tee_name,course_rating,slope_rating) loop
  select id into tid from public.course_tees where course_id=cid and tee_name=t.tee_name and gender='M' limit 1;
  if tid is null then
   insert into public.course_tees(course_id,tee_name,gender,course_rating,slope_rating,par)
   values(cid,t.tee_name,'M',t.course_rating,t.slope_rating,71) returning id into tid;
  else
   update public.course_tees set course_rating=t.course_rating,slope_rating=t.slope_rating,par=71 where id=tid;
  end if;
  insert into public.course_holes(tee_id,hole_number,par,stroke_index)
   select tid,n,pars[n],ranks[n] from generate_series(1,18) n
   where not exists(select 1 from public.course_holes h where h.tee_id=tid and h.hole_number=n);
 end loop;
end $$;
select t.tee_name,t.course_rating,t.slope_rating,
 (select count(*) from public.course_holes h where h.tee_id=t.id) as holes
from public.course_tees t join public.courses c on c.id=t.course_id
where c.name='Cedarwood Country Club' and t.tee_name in ('Black/Blue','Blue/White')
order by t.course_rating desc;