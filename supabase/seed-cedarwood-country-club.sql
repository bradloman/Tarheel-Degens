-- Cedarwood Country Club, Charlotte NC: initial men's tee scorecards.
-- Sources: Cedarwood official hole-by-hole; USGA NCRDB; mygolfindex tee ratings.
-- Safe to re-run; inserts only if the course/tee is absent.
do $$
declare cid uuid; tid uuid; t record;
  pars int[] := array[4,4,3,5,4,4,4,5,3,4,3,5,4,4,4,4,3,4];
  si int[] := array[11,5,17,9,13,1,7,3,15,12,16,10,14,2,6,4,18,8];
begin
 select id into cid from public.courses
 where name='Cedarwood Country Club' and city='Charlotte' limit 1;
 if cid is null then
   insert into public.courses(name,city,region,country,created_by)
   values('Cedarwood Country Club','Charlotte','NC','USA',auth.uid())
   returning id into cid;
 end if;
 for t in select * from (values
 ('Black',73.8::numeric,138),('Blue',71.4::numeric,132),
 ('White',69.7::numeric,129),('Gold',67.3::numeric,120),
 ('Red',65.8::numeric,114)
 ) as x(tee_name,course_rating,slope_rating)
 loop
  select id into tid from public.course_tees
   where course_id=cid and tee_name=t.tee_name and gender='M' limit 1;
  if tid is null then
   insert into public.course_tees(course_id,tee_name,gender,course_rating,slope_rating,par)
   values(cid,t.tee_name,'M',t.course_rating,t.slope_rating,71)
   returning id into tid;
  end if;
  insert into public.course_holes(tee_id,hole_number,par,stroke_index)
   select tid,n,pars[n],si[n] from generate_series(1,18) n
   where not exists(select 1 from public.course_holes h where h.tee_id=tid and h.hole_number=n);
 end loop;
end $$;
select c.name,t.tee_name,t.gender,t.course_rating,t.slope_rating,
 (select count(*) from public.course_holes h where h.tee_id=t.id) as holes
from public.courses c join public.course_tees t on t.course_id=c.id
where c.name='Cedarwood Country Club' and c.city='Charlotte'
order by t.course_rating desc;