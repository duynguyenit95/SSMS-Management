USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_LL_WorkshopLineEfficiency]    Script Date: 10/1/2021 4:50:02 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/
Create Or ALTER PROCEDURE [dbo].[SP_LL_WorkshopLineEfficiencyV2]
 @pWorkline nvarchar(max) = 'E1-L1',
 @pGxNo nvarchar(max) = '700'
as

-- Main Workline List
DECLARE @Workline TABLE (MainWorkline nvarchar(10),Workline nvarchar(15));
insert into @Workline
select value as MainWorkline,value as Workline
from string_split(@pWorkline,',');

--select * from @Workline;
-- Insert Fake line if have
insert into @Workline
select ta.value Workline, tb.FakeLine 
from string_split(@pWorkline,',') ta
inner join KTV_FakeLine(nolock) tb on ta.value = tb.Line;

DECLARE @GxNos Table(GxNo int);
insert into @GxNos
select cast(value as int) as gxNo
from string_split(@pGxNo,',') ta;


--select * from @Workline;

--- Workline Attendant
with t1 as(
select Workline, Count(LastSwipeTime) as EmpCount
--into #TargetWorkTime
from T_ETS_EmployeeAttendance(nolock) 
where WorkLine collate database_default in (select distinct MainWorkline from @Workline)
and Shift_date = convert(date, GetDate())
group by Workline
),
t2 as(
select Workline,Max(AccumulatedMinutes) as AccumulatedMinutes
from T_ETS_WorklineTarget (nolock)
where UpdateTime >= convert(date,GetDate())
and Workline collate database_default in (select distinct MainWorkline from @Workline)
and (EndTime <= convert(time,GETDATE()) or (StartTime <= convert(time,GETDATE()) and convert(time,GETDATE()) <= EndTime))
group by Workline
)
select t1.Workline, t1.EmpCount * AccumulatedMinutes  as TotalWorkTime
into #TargetWorkTime
from t1 
inner join t2 on t1.Workline = t2.Workline collate database_default
--select * from #TargetWorkTime
;
with 
t1 as(
SELECT  Upper(MainWorkline) as [WorkLine]
	,SUM(ta.TotalSam) as TotalGxSam
	,SUM(case when td.GxNo is not null then ta.TotalQty * tc.CMTotalSam  else 0 end) as TotalStyleCMSam
  FROM WorklineSummary (nolock) ta 
  inner join @Workline tb on ta.WorkLine = tb.Workline collate database_default
  inner join T_ETS_StyleGx (nolock) tc on tc.StyleNo = ta.StyleNo collate database_default and tc.GxNO = ta.GxNo
  left join @GxNos td on td.GxNo = ta.GxNo
  where WorkDate >= convert(date,GetDate())
  group by MainWorkline
)
select (
select t1.*,isnull(ta.TotalWorkTime,0) as TotalWorkTime
from t1
left join #TargetWorkTime ta on t1.WorkLine = ta.Workline
for json path, include_null_values
) as [Value]