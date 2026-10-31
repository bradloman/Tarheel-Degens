-- Verified deployed Nines settlement function
CREATE OR REPLACE FUNCTION public.nines_settlement(p_a integer, p_b integer, p_c integer, p_stake numeric, p_mode text)
 RETURNS bigint[]
 LANGUAGE plpgsql
 IMMUTABLE STRICT
 SET search_path TO ''
AS $function$
declare scores integer[]:=array[p_a,p_b,p_c]; results bigint[]:=array[0::bigint,0::bigint,0::bigint]; highest integer; winners integer[]:=array[]::integer[]; count_w integer; cents bigint; owed bigint; i integer; j integer; 
begin
 if least(p_a,p_b,p_c)<0 or p_stake<0 or p_mode not in ('fixed','per_point') then raise exception 'Invalid Nines settlement inputs'; end if;
 highest:=greatest(p_a,p_b,p_c); cents:=round(p_stake*100)::bigint;
 for i in 1..3 loop if scores[i]=highest then winners:=array_append(winners,i); end if; end loop;
 count_w:=array_length(winners,1);
 if count_w=3 then return results; end if;
 for i in 1..3 loop
  if scores[i]=highest then continue; end if;
  owed:=case when p_mode='fixed' then cents else cents*(highest-scores[i]) end;
  results[i]:=results[i]-owed;
  for j in 1..count_w loop
   results[winners[j]]:=results[winners[j]]+(owed/count_w)+case when j<=mod(owed,count_w) then 1 else 0 end;
  end loop;
 end loop;
 return results;
end $function$
;
revoke all on function public.nines_settlement(integer,integer,integer,numeric,text) from public,anon;
grant execute on function public.nines_settlement(integer,integer,integer,numeric,text) to authenticated;
