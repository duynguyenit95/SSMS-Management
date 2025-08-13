


--25	LineOutputAndReasonReaction	LineOutputAndReasonReaction
--21	WorkshopLineEfficiency	WorkshopLineEfficiency	Default

--133	LineOutputAndReasonReactionV2	LineOutputAndReasonReactionV2
--134	WorkshopLineEfficiencyV2	WorkshopLineEfficiencyV2


with t1 as(
select ta.ID 
	  ,tf.Fac_no as Factory
	  ,tf.Dep_no
	  ,tf.Wrk_no
	  ,te.Name as KanbanName
	  ,tb.Name as ScreenName
	  --,(select 698 as GxNo, 700 as QcGxNo for json path) as JSONAA
	  ,isnull(JSON_VALUE(JSONParamater,'$.GxNo'),isnull(JSON_VALUE(JSONParamater,'$.gxNo'),'698')) as GxNo
	  ,isnull(JSON_VALUE(JSONParamater,'$.QcGxNo'),isnull(JSON_VALUE(JSONParamater,'$.qcGxNo')
		,case when Dep_no in ('DPD1','DPD2','DPD3','DPD8') or Wrk_no like N'%UPP%' then '' else '700' end)
		) as QCGxNo
	  , case when Dep_no in ('DPD1','DPD2','DPD3','DPD8') or Wrk_no like N'%UPP%' then 2 else 1 end as CalculationFormula
	  , isnull(JSON_VALUE(JSONParamater,'$.etsServer'),'ETSHP') as EtsServer
	  , '700' as SamGxNo
	  ,ta.JSONParamater
	  --,* 
from KTV_ScreenKanbanMapping(nolock)  ta 
inner join KTV_Screen (nolock) tb on ta.ScreenID = tb.ID
inner join KTV_KanbanTVScreenMapping (nolock) tc on tc.ScreenID = tb.ID
inner join KTV_KanbanTV(nolock) te on te.ID = tc.KanbanID
left join Regina_User.dbo.HR_Org(nolock) tf on tf.Lin_no = te.Name
where ta.KanbanID = 25 
),
t2 as(
select t1.*
	,case when JSON_VALUE(t2.value,'$.Title') like N'%100%' and JSON_VALUE(t2.value,'$.Visible') = 'true' then 1 else 0 end as Eff100
	,case when JSON_VALUE(t2.value,'$.Title') like N'%Reason%' and JSON_VALUE(t2.value,'$.Visible') = 'true' then 1 else 0 end as Reason
	,t2.value
from t1 
cross apply OpenJSON(t1.JSONParamater,'$.React') t2
where  1 = 1 
and (JSON_VALUE(t2.value,'$.Title') like N'%100%' or JSON_VALUE(t2.value,'$.Title') like N'%Reason%')
--QCGxNo != '700' or GxNo != '698'
),
t3 as(
select ID,Factory,Dep_no,Wrk_no,KanbanName,ScreenName,GxNo,QCGxNo,CalculationFormula,EtsServer,SamGxNo
	,Max(Eff100) as Eff100
	,Max(Reason) as Reason
from t2
group by ID,Factory,Dep_no,Wrk_no,KanbanName,ScreenName,GxNo,QCGxNo,CalculationFormula,EtsServer,SamGxNo
)
select ID,(
select top 1 GxNo as gxNo,QCGxNo as qcGxNo, CalculationFormula as samCalculationFormula,
	   case when Eff100 = 0 then 'true' else 'false' end as hide100EffOutput,
	   case when Reason = 0 then 'true' else 'false' end as ReasonAndReaction,
	   KanbanName as Workline,
	   EtsServer as etsServer,
	   SamGxNo
from t3 ta where t3.ID = ta.ID
for json path,WITHOUT_ARRAY_WRAPPER 
) as JSONParam
--, *
into #AAA
from t3
order by Factory,Len(KanbanName),KanbanName



update KTV_ScreenKanbanMapping 
set KanbanID = 133,
	JSONParamater = ta.JSONParam
from #AAA ta
inner join KTV_ScreenKanbanMapping tb on ta.ID = tb.ID

select * from KTV_Kanban


update KTV_ScreenKanbanMapping 
set KanbanID = tb.KanbanID,
	JSONParamater = tb.JSONParamater
from KTV_ScreenKanbanMapping ta 
inner join KTV_ScreenKanbanMapping20221128 tb on ta.ID = tb.ID