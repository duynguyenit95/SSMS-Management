USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_RM052A]    Script Date: 8/12/2023 2:02:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/
ALTER   PROCEDURE [dbo].[SP_DN_RM052A]
@pDept nvarchar(20) = 'DPD2'
AS

DECLARE @date date = convert(Date,getdate())

DROP table if exists #T_Workline
select Dept Dept, Workshop Workshop, Workline Workline, ModGxNo ModGxNo, QcGxNo QcGxNo
into #T_Workline
from [172.19.18.58].[ORP].dbo.[RM052_MappingWorklineGxNo]
where Dept = @pDept

DECLARE @Workline TABLE (MainWorkline nvarchar(10), Workline nvarchar(15))
INSERT INTO @Workline
SELECT Workline MainWorkline, Workline
FROM #T_Workline
INSERT INTO @Workline
SELECT ta.Workline MainWorkLine, tb.FakeLine Workline
from #T_Workline ta
inner join KTV_FakeLine tb on ta.Workline = tb.Line

DROP table if exists #T_WorkTime;
DROP table if exists #T_Base1;

BEGIN 
--Head count & Attendance
with t1 as (
	select t1.Dept, t1.Workshop, t1.Workline
		  ,Count(*) Headcount
		  ,Count(LastSwipeTime) Attendance
	from T_ETS_EmployeeAttendance (nolock) ta
	inner join #T_Workline t1 on ta.Workline = t1.Workline
	where Shift_date = @date
	group by t1.Dept, t1.Workshop, t1.Workline
)
--AimQty & TotalWorkTime
,t2 as (
	select t1.Workline, SUM(ta.AimQty) AimQty,Max(AccumulatedMinutes) as AccumulatedMinutes
	from T_ETS_WorklineTarget (nolock) ta 
	inner join #T_Workline t1 on ta.Workline = t1.Workline collate database_default
	where UpdateTime >= @date
	and (EndTime <= convert(time,GETDATE()) or (StartTime <= convert(time,GETDATE()) and convert(time,GETDATE()) <= EndTime))
	group by t1.Workline
)

,t3 as (
	select t1.WorkLine
		,SUM(case when ta.GxNo = t1.ModGxNo then ta.TotalQty else 0 end) as ModQty
		,SUM(case when ta.GxNo = t1.QcGxNo then ta.TotalQty else 0 end) as QcQty
	from WorklineSummary (nolock) ta
	inner join #T_Workline t1 on ta.WorkLine = t1.Workline collate database_default
	--and (ta.GxNo = t1.ModGxNo or ta.GxNo = t1.QcGxNo)
	where ta.WorkDate = @date
	group by t1.WorkLine
)

select t1.*,
	   t2.AimQty, t2.AccumulatedMinutes * t1.Attendance as TotalWorkTime,
	   t3.ModQty, t3.QcQty
into #T_Base1
from t1
inner join t2 on t1.Workline = t2.Workline
inner join t3 on t1.Workline = t3.WorkLine
END


drop table if exists #T_Qty
SELECT  Upper(MainWorkline) as [WorkLine]
,ta.StyleNo
,SUM(ta.TotalSam) as TotalGxSam
,SUM(case when ta.GxNo is not null then ta.TotalQty * tc.CMTotalSam  else 0 end) as StyleCMSam
INTO #T_Qty
FROM WorklineSummary (nolock) ta 
inner join @Workline tb on ta.WorkLine = tb.Workline collate database_default
inner join T_ETS_StyleGx (nolock) tc on tc.StyleNo = ta.StyleNo collate database_default and tc.GxNO = ta.GxNo
where WorkDate >= @date
and ta.GxNo <> '700'
group by MainWorkline, ta.StyleNo

drop table if exists #T_BASE2
select WorkLine
	  ,SUM(ta.TotalGxSam) as TotalGxSam
	  ,SUM(ta.StyleCMSam) as TotalStyleCMSam
	  ,StyleNos = STUFF((
			select '/'+StyleNo
			from #T_Qty tb
			where ta.WorkLine = tb.WorkLine
			for xml path('')
	   ), 1, 1, '')
into #T_BASE2
from #T_Qty ta
group by WorkLine
select (
	select t1.*, t2.TotalGxSam, t2.TotalStyleCMSam, t2.StyleNos from #T_Base1 t1
	inner join #T_Base2 t2
	on t1.Workline = t2.WorkLine
	order by len(Workshop), Workshop, len(t1.Workline), t1.Workline
	for json path, include_null_values
) as [Value]