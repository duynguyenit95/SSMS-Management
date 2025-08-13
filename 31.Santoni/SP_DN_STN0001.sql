USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_STN0001]    Script Date: 4/19/2023 7:00:14 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_STN0001]
	@pWorkline varchar(10) = 'K1-L01'
AS
BEGIN
-- Plan Qty --
	drop table if exists #TPlan;
	select MachineNo,SUM(PlanQty) AimQty
	into #TPlan
	from [172.19.18.58].[ORP].[dbo].[T_SANTONI_PlanQty]
	where [Date] = convert(date,getdate())
	group by MachineNo;
-- 
with t1 as
	(select WorkLine, StyleNo, Zdcode, Sum(TotalQty) as Quantity
	  ,ROW_NUMBER() OVER (
		PARTITION BY Workline
		ORDER BY Workline
	  ) WorkLineIndex
	from WorkLineSummary (nolock)
	where 1=1
	and WorkLine in (select WorkLineName from T_ETS_Workline where Workshop = @pWorkline)
	and WorkDate = Convert(date, getdate())
	and GxNo in (32701,32721)
	group by StyleNo, WorkLine, Zdcode)
,t2 as (
	select t1.*, ta.AimQty
	from t1 left join #TPlan ta
	on t1.WorkLine = ta.MachineNo collate database_default
	and t1.WorkLineIndex = 1
)
,t3 as (
	select MO, Min(ExportDate) ExportDate from T_SAP_SOInProduction (nolock) where ExportDate != '0001-01-01' 
	group by MO
)
	select t2.*, t3.ExportDate
	into #temp
	from t2 left join t3 on t2.Zdcode = t3.MO collate database_default;

	update u set u.ExportDate = s.ExportDate
	from #temp u left join T_ETS_MOInProduction s on u.Zdcode = s.ZDCODE
	where u.ExportDate is null;
select (
	select *, DATEADD(DAY, -28, [ExportDate]) CompletionDate
	from #temp
	order by StyleNo, WorkLine, WorkLineIndex
	for json path)
as [Value]
END
--[SP_DN_STN0001]