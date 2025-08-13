/****** Script for SelectTopNRows command from SSMS  ******/

CREATE OR ALTER PROCEDURE SP_RM050
 @pDate nvarchar(10) = '2022-06-15',
 @pExportDate nvarchar(10) = ''
as
------------------ Param Config --------------------
DECLARE @Date date = convert(date,@pDate);
DECLARE @Export date = convert(date,@pExportDate);


------------------ Create MO tables --------------------
-- From Plan Data
select distinct Zdcode as MO
into #MOs
from [T_CUT_Plan] (nolock)
where WorkDate = @Date
and ETSStoreNo in( 'CCUT3' ,'CCUT')


-- From Actual Output Data - Directly Insert
insert into #MOs
select distinct Zdcode as MO
from T_ETS_CUTOutput (nolock)
where WorkDate = @Date
and StoreNo in( 'CCUT3' ,'CCUT')
and Zdcode collate database_default not in (select * from #MOs)

------------------ MO Data based on Export Date --------------------
drop table if exists #MOInfors;
select Factory,Customer,StyleNo,MO,BigSO,BigSOItemNo
	,ClosestExportDate,ClosestExportDateQuantity
	,LastExportDate,LastExportDateQuantity
into #MOInfors
from BigSOInfor 
		-- Get MO by Export date if user input				or		MO in Plan Data
where ((ClosestExportDate = @Export And  @pExportDate != '') OR (MO in (select * from #MOs)))
and Factory = '2504'
and BigSO like N'A16%';


---- Insert MO from MO Data from Export Date
insert into #MOs
select distinct MO 
from #MOInfors
where MO not in (select * from #MOs)



drop table if exists #AccumulatedDayPlanQty;
select Zdcode
	,SUM(NightTargetQty + DayTargetQty) as AccumulatedPlanQty
into #AccumulatedDayPlanQty
from ros.dbo.[T_CUT_Plan] ta  with (nolock) 
where ETSStoreNo in( 'CCUT3' ,'CCUT')
and WorkDate <= Convert(date,@Date)
and Zdcode in (select distinct MO from #MOs)
group by Zdcode;


drop table if exists #TodayDayPlanQty;
select Zdcode
	,SUM(NightTargetQty + DayTargetQty) as TotalDayPlanQty
into #TodayDayPlanQty
from ros.dbo.[T_CUT_Plan] ta  with (nolock) 
where ETSStoreNo in( 'CCUT3' ,'CCUT')
and WorkDate = Convert(date,@Date)
and Zdcode in (select distinct MO from #MOs)
group by Zdcode;



drop table if exists #C;
select Zdcode,WorklayerNo,Sum(TotalQuantity) as TotalQty
into #C
from T_ETS_CUTOutput (nolock)
where Zdcode in (select distinct MO collate database_default from #MOInfors)
and StoreNo in ( 'CCUT3' ,'CCUT')
and WorkDate <= Convert(date,@Date)
group by Zdcode,WorklayerNo;

drop table if exists #D;
select Zdcode,WorklayerNo,Sum(TotalQuantity) as TotalQty
into #D
from T_ETS_CUTOutput (nolock)
where Zdcode in (select distinct MO collate database_default from #MOInfors)
and StoreNo in ( 'CCUT3' ,'CCUT')
and WorkDate = Convert(date,@Date)
group by Zdcode,WorklayerNo;


;

drop table if exists #FinalResults;
select ta.*,t1.WorklayerNo
		,cast(N'' as nvarchar(2048)) as WorklayerName
		,isnull(t4.TotalQty,0) as TodayOutputQty
		,isnull(t2.TotalDayPlanQty,0) as TotalDayPlanQty
		,isnull(t1.TotalQty,0) as AccumulatedOutputQty
		,isnull(t3.AccumulatedPlanQty,0) as AccumulatedPlanQty
		,@Date as WorkDate
into #FinalResults
from #MOInfors ta
left join #C t1 on ta.MO = t1.Zdcode collate database_default
left join #TodayDayPlanQty t2 on t2.Zdcode = t1.Zdcode collate database_default
left join #AccumulatedDayPlanQty t3 on t3.Zdcode = t1.Zdcode collate database_default
left join #D t4 on ta.MO = t4.Zdcode collate database_default and t4.WorklayerNo = t1.WorklayerNo
where 1 = 1 
;
with t1 as(
select distinct ZDCODE,STYLE_NO 
from T_ETS_MOInProduction(nolock) 
where ZDCODE in (select distinct MO collate database_default from #MOInfors)
),
t2 as(
select * from t1 
inner join T_ETS_StyleGx(nolock) t2 on t1.STYLE_NO = t2.StyleNo collate database_default
)
update #FinalResults 
set WorklayerName = t2.LayerName
from t2
inner join #FinalResults ta on t2.ZDCODE = ta.MO collate database_default and t2.LayerNo = ta.WorklayerNo
-- and t1.Zdcode is null

select * 
from #FinalResults 
order by MO,WorklayerNo
for json path, include_null_values;















--DECLARE @Date date = convert(date,@pDate);
--DECLARE @GxNo Table(GxNo int);
--insert into @GxNo
--select cast(value as int) from string_split(@pGxNo,',')


--  drop table if exists #TodayDayPlanQty;
--  select WorkDate
--		,Zdcode
--		,SUM(NightTargetQty + DayTargetQty) as TotalDayPlanQty
--  into #TodayDayPlanQty
--  from [172.19.18.86].ros.dbo.[T_CUT_Plan] ta  with (nolock) 
--  where ETSStoreNo in( 'CCUT3' ,'CCUT')
--  and WorkDate = @Date
--  group by WorkDate
--		,Zdcode;

--	drop table if exists #AllTimePlan;
--	select WorkDate
--		,Zdcode
--		,SUM(NightTargetQty + DayTargetQty) as TotalDayPlanQty
--	into #AllTimePlan
--	from [172.19.18.86].ros.dbo.[T_CUT_Plan] ta  with (nolock) 
--	where 1 = 1
--	and ETSStoreNo in( 'CCUT3' ,'CCUT')
--	and Zdcode in (select distinct Zdcode from #TodayDayPlanQty)
--	and WorkDate < @Date
--	  group by WorkDate
--		,Zdcode;

--		drop table if exists #AccumulatedOutputData;

--SELECT Max([WorkDate]) [LastWorkDate]
--      ,[Zdcode]
--      ,[GxNo]
--      ,SUM([TotalQty]) as [TotalQty]
--into #AccumulatedOutputData
--FROM [ORP].[dbo].[RM050_ETSData] (nolock)
--where 1 = 1 
--and Zdcode in (select distinct Zdcode collate database_default from #TodayDayPlanQty)
--and WorkDate <=@Date
--and (GxNo in (select * from @GxNo) OR @pGxNo = '')
--group by [Zdcode]
--    ,[GxNo];

--drop table if exists #TodayOutputData;
--SELECT [Zdcode]
--      ,[GxNo]
--      ,Sum([TotalQty]) as [TotalQty]
--into #TodayOutputData
--FROM [ORP].[dbo].[RM050_ETSData] (nolock)
--where 1 = 1 
--and Zdcode in (select distinct Zdcode collate database_default from #TodayDayPlanQty)
--and WorkDate = @Date
--and GxNo in (select * from @GxNo)
--group by  [Zdcode]
--      ,[GxNo]


--drop table if exists #Result;
--with t1 as(
--select *,Sum(TotalDayPlanQty) Over (Partition by Zdcode order by WorkDate rows between unbounded preceding  and current row ) as AccumulatedPlanQty
--from (
--	select * 
--	from #TodayDayPlanQty
--	union all
--	select * 
--	from #AllTimePlan
--) ta 
--),
--t2 as(
--	select * 
--	from #AccumulatedOutputData
--)
--select t1.*
--	,t2.GxNo
--	,isnull(t3.TotalQty,0) as TodayOutputQty
--	,t2.TotalQty as AccumulatedOutputQty
--	,t2.LastWorkDate
--into #Result
--from t1
--inner join t2 on t1.Zdcode collate database_default = t2.Zdcode
--left join #TodayOutputData t3 on t1.Zdcode collate database_default = t3.Zdcode and t2.GxNo = t3.GxNo
--where t1.WorkDate = @Date
----and t1.Zdcode = '000043066520'
--order by t1.Zdcode,GxNo

--select ta.*,tb.StyleNo,tb.LastExportDateQuantity,tb.LastExportDate
--from #Result ta
--left join BigSOInfor tb on ta.Zdcode = tb.MO 
--order by ta.Zdcode,GxNo
--for json path,include_null_values