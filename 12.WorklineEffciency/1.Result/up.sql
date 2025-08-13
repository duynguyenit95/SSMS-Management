with t1 as(
select ta.ID 
	  ,tf.Fac_no as Factory
	  ,tf.Dep_no
	  ,tf.Wrk_no
	  ,te.Name as KanbanName
	  ,tb.Name as ScreenName
	  --,(select 698 as GxNo, 700 as QcGxNo for json path) as JSONAA
	  ,isnull(JSON_VALUE(JSONParamater,'$.GxNo'),isnull(JSON_VALUE(JSONParamater,'$.gxNo'),'700')) as GxNo
	  , case when Dep_no in ('DPD1','DPD2','DPD3','DPD8') or te.Name = 'UPP1' then 2 else 1 end as CalculationFormula
	  , JSON_VALUE(JSONParamater,'$.Workshop') as Workshop
	  , ISNULL(JSON_VALUE(JSONParamater,'$.Span'),N'生产效率Hiệu suất') as Span
	  , isnull(JSON_VALUE(JSONParamater,'$.etsServer'),'ETSHP') as etsServer
	  ,ta.JSONParamater
	  --,* 
from KTV_ScreenKanbanMapping(nolock)  ta 
inner join KTV_Screen (nolock) tb on ta.ScreenID = tb.ID
inner join KTV_KanbanTVScreenMapping (nolock) tc on tc.ScreenID = tb.ID
inner join KTV_KanbanTV(nolock) te on te.ID = tc.KanbanID
left join (select distinct Fac_no,Dep_no,Wrk_no from Regina_User.dbo.HR_Org(nolock)) tf on tf.Wrk_no = te.Name
where ta.KanbanID = 21 
and (tf.Dep_no like N'%PD%' or tf.Dep_no like N'%BRA%' or te.Name = 'UPP1')
)
select ID,(
	select GxNo as gxNo,  CalculationFormula as samCalculationFormula,
	Workshop,Span,etsServer
	from t1 ta where ta.ID = t1.ID
	for json path,WITHOUT_ARRAY_WRAPPER
) as JSONParam 
into #AAA
from t1 

update KTV_ScreenKanbanMapping 
set KanbanID = 134,
	JSONParamater = ta.JSONParam
from #AAA ta
inner join KTV_ScreenKanbanMapping tb on ta.ID = tb.ID


select * from KTV_Kanban