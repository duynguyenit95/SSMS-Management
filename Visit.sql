drop table if exists #A;

DECLARE @StartDate date = '2022-07-01';
DECLARE @EndDate date = '2022-07-31';

DECLARE @DateDiff int = DateDiff(day,@StartDate,@EndDate) + 1;

select KanbanID
	,Sum(case when UserAgent like N'%Windows%' then 1 else 0 end) as PcRequest
	,Sum(case when UserAgent like N'%Chromium%' then 1 else 0 end) as mPCRequest
	,Count(1) as TotalView
into #A
from KTV_VisitLog(nolock)
where [Time] >= @StartDate and [Time] <= @EndDate
--and UserIP like N'%137.249%'
--and UserAgent  like N'%Chronium%'
group by KanbanID



drop table  if exists #B;
select * 
into #B
from [172.19.18.58].ORP.dbo.KTV_KanbanTV
--select top 1 * from #B;


drop table  if exists #E;
select tb.[Name],tb.ID as KanbanID,tb.GroupID, ta.PcRequest,ta.mPCRequest,ta.TotalView,TotalView-PcRequest-mPCRequest as TVRequest
into #E
from #A ta 
right join #B tb on ta.KanbanID = tb.ID
where 1 = 1 
--ta.KanbanID is null
order by [Name],TVRequest,PcRequest	


drop table  if exists #C;
select * 
into #C
from [172.19.18.58].ORP.dbo.KTV_KanbanTVGroup
;

drop table  if exists #D;
with 
t1 as(
	select * 
	from #C
	where ParentID = 0
	union all
	select ta.ID,ta.Factory,ta.GroupName,t1.[Description] +' || '+ ta.[Description], ta.DisplayOrder,ta.ParentID,ta.GroupType
	from  t1
	inner join #C ta on t1.ID = ta.ParentID
)
select * 
into #D
from t1


--select * from #D
--order by ID,Factory,Description

select tb.Factory 
	 ,tb.Description as [KanbanPath]
	 ,ta.Name as KanbanName
	 ,ta.KanbanID as KanbanID
	 ,isnull(TotalView,0) TotalView, cast(Round(isnull(TotalView,0) / cast(@DateDiff as decimal(18,4)),4) as decimal(18,4))   as DailyView
	 ,isnull(PcRequest,0) PcRequest, cast(Round(isnull(PcRequest,0) / cast(@DateDiff as decimal(18,4)),4) as decimal(18,4))   as DailyPCRequest
	 ,isnull(mPCRequest,0) mPCRequest, cast(Round(isnull(mPCRequest,0) / cast(@DateDiff as decimal(18,4)),4) as decimal(18,4))   as DailymPCRequest
	 ,isnull(TVRequest,0) TVRequest, cast(Round(isnull(TVRequest,0) / cast(@DateDiff as decimal(18,4)),4) as decimal(18,4))  as DailyTVRequest
from #E ta
inner join #D  tb on ta.GroupID = tb.ID
where tb.Factory != 'Deleted'
order by DailyView desc

