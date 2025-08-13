USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_LL_Workline_OutputAndReasonReaction]    Script Date: 4/14/2022 9:16:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_LL_Workline_OutputAndReasonReaction] 
@pWorkline nvarchar(20) = 'A1-L1',
@pOutputGxNo nvarchar(1000) = '698',
@pOutputQcGxNo nvarchar(1000) = '700',
@pGxName nvarchar(2000) = '',
@pETSServer nvarchar(10) = ''
as

------------ Config Paramater

-- Main Workline List
DECLARE @Workline TABLE (MainWorkline nvarchar(10),Workline nvarchar(15));
insert into @Workline
select value as MainWorkline,value as Workline
from string_split(@pWorkline,',');

-- Insert Fake line if have
insert into @Workline
select ta.value Workline, tb.FakeLine 
from string_split(@pWorkline,',') ta
inner join KTV_FakeLine tb on ta.value = tb.Line;

DECLARE @OutputGxNo TABLE (GxNo int);
insert into @OutputGxNo
select cast([value] as int) as GxNo from string_split(@pOutputGxNo,',');

DECLARE @OutputQcGxNo TABLE (GxNo int);
insert into @OutputQcGxNo
select cast([value] as int) as GxNo from string_split(@pOutputQcGxNo,',');

DECLARE @OutputGxName TABLE (Gxname nvarchar(200));
insert into @OutputGxName
select [value] as  Gxname from string_split(@pGxName,',');

------------ End Config Paramater


------------ Target 

--- Workline Target
drop table if exists #Target;
select *
into #Target
from T_ETS_WorklineTarget
where UpdateTime >= convert(date,GetDate())
and Workline collate database_default in (select distinct MainWorkline from @Workline)


--- Workline Attendant
drop table if exists #EmpAtt;
select Workline, COUNT(LastSwipeTime) EmpCount 
into #EmpAtt
from T_ETS_EmployeeAttendance(nolock) 
where WorkLine collate database_default in (select distinct MainWorkline from @Workline)
and Shift_date = convert(date, GetDate())
group by Workline;
;
drop table if exists #TargetWorkTime;
with 
-- Get Line Work Time
t0a as (
	select * from #Target
)
,t0b as (
	select * from #EmpAtt
)
,t0 as (
	select t0a.*, t0a.AccumulatedMinutes * t0b.EmpCount as TimeSam
	from t0a left join t0b on t0a.Workline = t0b.Workline collate database_default
)
select * 
into #TargetWorkTime
from t0

------------ End Target 


--- Workline Output Data

drop table if exists #WorklineOutput;
select tc.MainWorkline as Workline
	,TimeString
	,StyleNo
	,GxNo
	,case when ta.GxNo in (select * from @OutputGxNo) then 'GxNo'
			 when ta.GxNo in (select * from @OutputQcGxNo) then 'QcGxNo'
			 else 'Undefined' end as TypeGxNo
	,Sum(TotalQty) as TotalQty
	,Sum(TotalSam) as TotalSam
into #WorklineOutput
FROM WorkLineSummary (nolock) ta
-- Get all Workline output while group by MainWorkline to get main Workline real output
inner join @Workline tc on tc.Workline = ta.WorkLine collate database_default
where 1 = 1
and WorkDate = convert(date,GetDate())
and ( 
	GxNo in (select * from @OutputGxNo) 
	or GxNo in (select * from @OutputQcGxNo)
)
group by tc.MainWorkline,TimeString,GxNo,StyleNo;
--select * from #WorklineOutput; --4
--- End Workline Output Data


--- Calculate Output Quantity base on GxNo,GxName,ETSServer
drop table if exists #TempOutput;
select 'TempWorkline' as Workline,'00:00-00:00' as TimeString, 'Undefined' as TypeGxNo,0 as TotalQty
into #TempOutput
truncate table #TempOutput;

if(@pGxName != '')
	BEGIN
		drop table if exists #TempOutputStyleGx;
					--- Get GxName in StyleGx to filter later
		SELECT ta.*,tb.gxName collate database_default as gxName
		into #TempOutputStyleGx
		FROM #WorklineOutput ta 
		inner join T_ETS_StyleGx (nolock) tb 
		on ta.StyleNo = tb.StyleNo collate database_default
		and ta.GxNo = tb.GxNO
		where 1 = 1 
		-- Filter by GxNo 
		and (ta.GxNo in (select * from @OutputGxNo)
			or ta.GxNo in (select * from @OutputQcGxNo))
		-- Check ETS Server
		and (tb.ETSServer = @pETSServer OR @pETSServer = '')

	
		--- Insert Data
		insert into #TempOutput
		select Upper(Workline) as [WorkLine]
			,TimeString
			,TypeGxNo
			,SUM([TotalQty]) as [TotalQty]
		from #TempOutputStyleGx ta 
		-- Filter GxName
		inner join @OutputGxName tc on ta.gxName like N'%'+tc.GxName+'%'
		group by Workline,TimeString, TypeGxNo
	END
ELSE
	BEGIN
		insert into #TempOutput
		SELECT  Upper([WorkLine]) as [WorkLine]
				,TimeString
				,TypeGxNo
				,SUM([TotalQty]) as [TotalQty]
		FROM #WorklineOutput ta 
		where 1 = 1
		-- Filter by GxNo 
		 --and ( GxNo in (select * from @OutputGxNo) 
			--	or GxNo in (select * from @OutputQcGxNo))
		group by [WorkLine], TypeGxNo, TimeString
	END
--- End Calculate Output Quantity base on GxNo,GxName,ETSServer

;
-- Combine Data
with 
-- Calculate Total Sam 
t2a as (
	select Workline,TimeString,TypeGxNo,Sum(TotalSam) as TotalSam 
	from #WorklineOutput
	group by Workline,TypeGxNo,TimeString
)
-- Calculate Accumulated Sam
--select * from t2a
,t2 as (
	select *,SUM(TotalSam) OVER(partition by TypeGxNo order by TypeGxNo, TimeString rows between unbounded preceding and current row) AccumulatedSAM 
	from t2a
)
-- Combination
--select * from t2
--select * from #TargetWorkTime;
--select * from #TempOutput
,t3 as(
select t1.Workline,t1.HourAimQty,StartTime,EndTime,t1.TimeString,t1.TotalWorkTime,t1.AimQty
	,t0.TypeGxNo
	,isnull(t0.TotalQty,0) as TotalQty
	,isnull(t2.TotalSam,0) as SAM
	,isnull(t2.AccumulatedSAM,0) as TotalSam
	,t1.TimeSam
	--Target Table
from  #TargetWorkTime t1
-- Output table
left join #TempOutput t0 on t1.TimeString = t0.TimeString collate database_default and t1.Workline = t0.Workline collate database_default 
-- Sam table
left join t2 on t1.TimeString = t2.TimeString collate database_default and t1.Workline = t2.Workline collate database_default and t0.TypeGxNo = t2.TypeGxNo
)

-- Config result column 
select t3.Workline as [LineNo]
	,t3.TypeGxNo
	,t3.TimeString as TimeWork
	,t3.HourAimQty as TotalTarget
	,cast(t3.TotalQty as decimal(18,2)) TotalQty
	,'' as ReasonAndReaction
	,t3.TimeString as [Description]
	,t3.AimQty
	,SAM
	,[TotalSam]
	,t3.TimeSam
	,cast(0 as decimal(18,2)) as TotalStyleCMSam
	,cast(0 as decimal(18,2)) as TotalSamByGx
from t3
order by TypeGxNo desc, StartTime