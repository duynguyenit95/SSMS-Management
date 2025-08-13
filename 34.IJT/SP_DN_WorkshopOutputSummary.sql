USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_WorkshopOutputSummary]    Script Date: 5/26/2023 8:51:47 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Created in 172.19.18.86.dbo.ROS

ALTER PROCEDURE [dbo].[SP_DN_WorkshopOutputSummary]
	@pWorkshop varchar(10) = 'IJT-D',
	@pGxNo varchar(max) = '1143'
AS

DECLARE @GxNo TABLE (GxNo nvarchar(10));
insert into @GxNo
select * from string_split(@pGxNo,',');

BEGIN
with t0 as (
	select 
	 SUM(case when WorkDate = convert(Date,getdate()) then TotalQty else 0 end) DailyQty
	,SUM(case when WorkDate >= DATEADD(month, DATEDIFF(month, 0, getdate()), 0) then TotalQty else 0 end) MonthQty
	,MAX(UpdateTime) LastUpdateTime
	from WorkLineSummaryWithEmp
	where Workshop = @pWorkshop
	and Gx_No in (select * from @GxNo)
)
,t1 as (
	select N'日期Ngày' as [Field]
	,LEFT(CONVERT(VARCHAR, LastUpdateTime, 120), 10)
	as [Value] from t0
)
,t2 as (
	select N'时间Thời gian' as [Field]
	,CONVERT(VARCHAR, LastUpdateTime, 24)
	as [Value] from t0
)
,t3 as (
	select N'总量Kiểm trong ngày' as [Field]
	,CONVERT(VARCHAR, DailyQty)
	as [Value] from t0
)
,t4 as (
	select N'总月Kiểm trong tháng' as [Field]
	,CONVERT(VARCHAR, MonthQty)
	as [Value] from t0
)
select * from t1
union
select * from t2
union
select * from t3
union
select * from t4
END
--[SP_DN_WorkshopOutputSummary]

EXEC [SP_DN_WorkshopOutputSummary] @pWorkshop = 'IJT-D', @pGxNo = '1143'