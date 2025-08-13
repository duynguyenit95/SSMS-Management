USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_LL_WorkshopLineTargetOutput]    Script Date: 7/20/2022 2:34:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SP_LL_WorkshopLineTargetOutput]
 @pWorkline nvarchar(max) = 'A1-L1,A1-L2,A1-L3,A1-L4,A1-L10,A1-L11',
 @pGxNo nvarchar(max) = '698',
 @pQcGxNo nvarchar(max) = '700',
 @pGxName nvarchar(max) = '',--'May la bang-may labang vanh de/de giua',
 @pETServer nvarchar(10) = 'ETSFW',
 @pUseShiftTime bit = 0
as

-- Local Variable
DECLARE @Workline TABLE (Workline nvarchar(15));
insert into @Workline
select * from string_split(@pWorkline,',');

DECLARE @GxNo TABLE (GxNo nvarchar(10));
insert into @GxNo
select * from string_split(@pGxNo,',');

DECLARE @QcGxNo TABLE (GxNo nvarchar(10));
insert into @QcGxNo
select * from string_split(@pQcGxNo,',');

DECLARE @GxName TABLE (GxName nvarchar(200));
insert into @GxName
select * from string_split(@pGxName,'|');

select 'TempWorkline' as Workline, 0 as TotalQty
into #TempOutput
truncate table #TempOutput

select 'TempWorkline' as Workline, 0 as TotalQty2
into #TempOutput2
truncate table #TempOutput2

if(@pGxName != '')
BEGIN
	-- Check GxNo Name
	SELECT ta.*,tb.gxName collate database_default as gxName
	into #TempOutputStyleGx
	FROM WorkLineSummary ta 
	inner join T_ETS_StyleGx (nolock) tb on ta.StyleNo = tb.StyleNo collate database_default
								and ta.GxNo = tb.GxNO
	where WorkDate = convert(date,GetDate())
	--and ta.GxNo in (5213,5214)
	--and tb.gxName like N'%May la bang-may labang vanh de/de giua%'
	--and WorkLine like N'UPP1-L%'
	and WorkLine collate database_Default in (select * from @Workline)
	and ta.GxNo in (select * from @GxNo)
	and (tb.ETSServer = @pETServer OR @pETServer = '')

	-- Filter GxName
	insert into #TempOutput
	select Upper([WorkLine]) as [WorkLine]
		,SUM([TotalQty]) as [TotalQty]
	from #TempOutputStyleGx ta 
	inner join @GxName tc on ta.gxName like N'%'+tc.GxName+'%'
	group by [WorkLine]
END

ELSE IF(@pUseShiftTime = 1)
BEGIN
-- Time Variables
DECLARE 
@8PMYesterday datetime = DATEADD(HOUR, -4, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)),
@8AMToday datetime = DATEADD(HOUR, 8, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)),
@8PMToday datetime = DATEADD(HOUR, 20, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)),
@8AMTomorrow datetime = DATEADD(HOUR, 8, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 1)),
@now datetime = getdate()

INSERT INTO #TempOutput
SELECT UPPER(t1.WorkLine) as [Workline]
	,SUM([TotalQty]) as [TotalQty]
	--,t1.TotalQty
  FROM T_ETS_EmployeeEfficiency (nolock) t1
  inner join T_ETS_EmployeeAttendance (nolock) t2 
  on t1.WorkLine = t2.Workline collate database_default 
  and t1.Code = t2.EMP_ID collate database_default 
  and CONVERT(DATE,t1.Work_Date) = t2.Shift_date
  where 1=1
  and t1.WorkLine collate database_Default in (select * from @Workline)
  and t1.GxNo in (select * from @GxNo)
  and t2.StartTime >= (case when @now >= @8PMYesterday and @now < @8AMToday then @8PMYesterday
					   when @now >= @8AMToday and @now < @8PMToday then @8AMToday
					   when @now >= @8PMToday then @8PMToday else CONVERT(date,getdate()) end)
  and t2.EndTime <= (case when @now >= @8PMYesterday and @now < @8AMToday then @8AMToday
					   when @now >= @8AMToday and @now < @8PMToday then @8PMToday
					   when @now >= @8PMToday then @8AMTomorrow else CONVERT(date,getdate()) end)
  group by t1.WorkLine
END

ELSE
BEGIN
insert into #TempOutput
SELECT  Upper([WorkLine]) as [WorkLine]
	,SUM([TotalQty]) as [TotalQty]
  FROM T_ETS_EmployeeEfficiency (nolock)
  where UpdateTime > convert(date,GetDate())
  and WorkLine collate database_Default in (select * from @Workline)
  and GxNo in (select * from @GxNo)
  group by [WorkLine]

insert into #TempOutput2
SELECT  Upper([WorkLine]) as [WorkLine]
	,SUM([TotalQty]) as [TotalQty2]
  FROM T_ETS_EmployeeEfficiency (nolock)
  where UpdateTime > convert(date,GetDate())
  and WorkLine collate database_Default in (select * from @Workline)
  and GxNo in (select * from @QcGxNo)
  group by [WorkLine]
END
;

with t1 as(
	select * from #TempOutput
)
,t1a as (
	select * from #TempOutput2
)
,t2 as(
	select Workline,AimQty
	from T_ETS_WorklineTarget (nolock)
	where UpdateTime >  convert(date,GetDate())
    and WorkLine collate database_Default in (select * from @Workline)
	and AimQty > 0
	group by Workline,AimQty

)
select (
select t2.Workline,t2.AimQty as TargetQty
,cast(isnull(t1.TotalQty,0) as int) as OutputQty
,cast(isnull(t1a.TotalQty2,0) as int) as QcOutputQty
from t2
left join t1 on t1.WorkLine = t2.Workline collate database_default
left join t1a on t1a.WorkLine = t2.Workline collate database_default
order by len(t2.Workline), t2.Workline
for json path, include_null_values
) as [Value]
