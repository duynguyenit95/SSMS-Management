USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_C_WorkLineSummaryWithEmp]    Script Date: 4/19/2023 7:55:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Created in ROS ORP Database 172.19.18.86 - ROS 
-- Related Job : DN_ETS_WorklineSummaryWithEmp
-- Only sync data from ESP Department

ALTER PROCEDURE [dbo].[SP_C_WorkLineSummaryWithEmp]
as

BEGIN

DROP TABLE IF EXISTS #T_View
	select *
	into #T_View
	from [172.19.18.81].[ETSDB_Regina].[dbo].[V_DN_WorklineSummaryWithEmp]
	where WorkLine like 'ESP%' or WorkLine like 'IJT%'

DROP TABLE IF EXISTS #T_Summary
	select Convert(date,ta.BillDate) WorkDate, ta.WorkLine, ta.EmpID, ta.Gx_No, t1.TimeString, SUM(Qty) TotalQty
	into #T_Summary
	from #T_View ta
	inner join WorkTimeDetails t1 on convert(time,ta.EndTime) between t1.StartTime and t1.EndTime
	group by Convert(date,ta.BillDate), ta.WorkLine, ta.EmpID, ta.Gx_No, t1.TimeString

DROP TABLE IF EXISTS #T_HR
	select * into #T_HR from openquery([172.19.18.58],'select Emp_id, Emp_name, Factory, Dept, Workshop, Line_no from Regina_User.dbo.Employee');

-- WorkLineSummaryWithEmp --
INSERT INTO WorkLineSummaryWithEmp
SELECT tc.Factory, tc.Dept, tc.Workshop, tc.Emp_name,
	   tb.*, getdate() UpdateTime 
from #T_Summary tb
left join #T_HR tc on tb.EmpID = tc.Emp_id collate database_default;

-- Delete 
DELETE WorkLineSummaryWithEmp 
where (
-- Only keep lastest data in day
UpdateTime > convert(date,GetDate())
and UpdateTime < (select max(UpdateTime) from WorkLineSummaryWithEmp where UpdateTime > convert(date,GetDate()))
)
OR 
(
-- Only keep in month data or last 3 days data
	WorkDate < DATEADD(DAY, -( DAY( WorkDate ) -1 ), WorkDate)
	and DATEDIFF(day,WorkDate,GetDate()) > 2
);
--- END WorkLineSummaryWithEmp ---- 


--- WorkLineSummaryTimeSheet ---
INSERT INTO WorkLineSummaryTimeSheet
SELECT tc.Factory, tc.Dept, tc.Workshop, tc.Emp_name,
	   ta.*, getdate() UpdateTime
from #T_View ta
left join #T_HR tc on ta.EmpID = tc.Emp_id collate database_default;

-- Delete 
DELETE WorkLineSummaryTimeSheet 
where (
-- Only keep lastest data in day
UpdateTime > convert(date,GetDate())
and UpdateTime < (select max(UpdateTime) from WorkLineSummaryTimeSheet where UpdateTime > convert(date,GetDate()))
)
OR 
(
-- Only keep in month data or last 3 days data
	DATEDIFF(day,EndTime,GetDate()) > 2
)
END