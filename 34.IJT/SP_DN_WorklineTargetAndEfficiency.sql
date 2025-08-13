USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_WorklineTargetAndEfficiency]    Script Date: 5/26/2023 8:50:08 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Created in 172.19.18.86.dbo.ROS

ALTER PROCEDURE [dbo].[SP_DN_WorklineTargetAndEfficiency]
	@pWorkline nvarchar(1000) = 'IJT-D02,IJT-D03',
	@pGxNo varchar(max) = '1140'
AS

DECLARE @GxNo TABLE (GxNo nvarchar(10));
insert into @GxNo
select * from string_split(@pGxNo,',');

DECLARE @Workline TABLE (Workline varchar(10));
insert into @Workline
select * from string_split(@pWorkline,',');

BEGIN
with t0 as (
	select WorkLine, SUM(TotalQty) TotalQty, SUM(TotalSAM) TotalSAM
	from WorkLineSummary (nolock)
	where 1=1
	and WorkLine collate database_default in (select * from @Workline)
	and GxNo in (select * from @GxNo)
	and WorkDate = convert(date,getdate())
	group by Workline
)
,t1 as (
	SELECT Workline, SUM(TotalWorkTime) TotalWorkTime
	FROM T_ETS_EmployeeAttendance (nolock)
	where WorkLine collate database_default in (select * from @Workline)
	and LastSwipeTime is not null
	and Shift_date = convert(date,getdate())
	group by Workline, Shift_date
)
,t2 as (
	SELECT * from [172.19.18.58].[ORP].[dbo].[DM010]
	where Workline in (select * from @Workline)
	and [Date] = convert(date,getdate())
)
,result as (
	select t0.*, t1.TotalWorkTime, ISNULL(t2.PlanQty,0) PlanQty
	,case when t0.WorkLine = 'IJT-D02' then N'A栋一楼 A1F'
		  when t0.WorkLine = 'IJT-D03' then N'C栋一楼 C1F'
		  else t0.WorkLine end AS  DisplayName
	from t0
	inner join t1 on t0.WorkLine = t1.Workline collate database_default
	left join t2 on t0.WorkLine = t2.Workline collate database_default
)
select (
	select * from result
	for json path
) as [Value]
END
--[SP_DN_WorklineTargetAndEfficiency]
