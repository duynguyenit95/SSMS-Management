USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_OEEKanban]    Script Date: 4/19/2023 7:24:14 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_DN_OEEKanban]
@pKanbanBlock nvarchar(5) = 'CCUT'
as
BEGIN
DECLARE @StartMonth date =  convert(date,DATEADD(month, DATEDIFF(month, 0, getdate()-1), 0))
DECLARE @EndMonth date = EOMONTH(@StartMonth)

DROP TABLE IF EXISTS #OEE_Report
CREATE TABLE #OEE_Report(
	[ID] [uniqueidentifier] NULL,
	[Year] [int] NULL,
	[Season] [varchar](4) NULL,
	[Month] [date] NULL,
	[SupplierGroup] [varchar](6) NOT NULL,
	[COO] [varchar](7) NOT NULL,
	[MachineType] [varchar](12) NOT NULL,
	[BillDate] [date] NULL,
	[Factory] [nvarchar](9) NULL,
	[MachineNo] [nvarchar](10) NOT NULL,
	[MachineCode] [nvarchar](50) NOT NULL,
	[MachinePosition] [int] NOT NULL,
	[Break] [int] NULL,
	[Meeting] [int] NULL,
	[TotalWorkingMinutes] [decimal](38, 2) NULL,
	[Training] [money] NULL,
	[NoProductionPlan] [int] NULL,
	[FactoryOrMachineUpgrade] [int] NULL,
	[PreventiveMaintenance] [money] NULL,
	[OtherScheduledDowntime] [int] NULL,
	[SetupAdjustment] [int] NULL,
	[ChangeOver] [money] NULL,
	[MachineIssue] [money] NULL,
	[QualityIssue] [money] NULL,
	[MaterialIssue] [money] NULL,
	[OtherUnscheduledDownTime] [money] NULL,
	[TotalOutput] [int] NULL,
	[GoodOutput] [int] NULL,
	[MachineRunningTime] [decimal](18, 2) NULL,
	[ScheduledDowntime] [money] NULL,
	[UnScheduledDowntime] [money] NULL,
	[PlannedProductionTime] [decimal](38, 2) NULL,
	[OperatingTime] [decimal](38, 2) NULL,
	[Availability] [decimal](18, 4) NULL,
	[Performance] [decimal](18, 4) NULL,
	[Quality] [decimal](18, 4) NULL,
	[OEE] [decimal](18, 4) NULL,
	[TargetOEE] [int] NULL
)

INSERT INTO #OEE_Report
EXEC [SP_DN_OEEReport] @FromDate = @StartMonth, @EndDate = @EndMonth, @pBlock = @pKanbanBlock

DROP TABLE IF EXISTS #t1
select BillDate, MachineNo, MachineCode, MachinePosition, OEE
,SUM(TotalWorkingMinutes) OVER(PARTITION BY BillDate) Date_TotalWorkingMinutes
,SUM(TotalWorkingMinutes) OVER(PARTITION BY MachineNo) Machine_TotalWorkingMinutes
,SUM(TotalWorkingMinutes) OVER() Month_TotalWorkingMinutes

,SUM(OperatingTime) OVER(PARTITION BY BillDate) Date_OperatingTime
,SUM(OperatingTime) OVER(PARTITION BY MachineNo) Machine_OperatingTime
,SUM(OperatingTime) OVER() Month_OperatingTime

,SUM(MachineRunningTime) OVER(PARTITION BY BillDate) Date_MachineRunningTime
,SUM(MachineRunningTime) OVER(PARTITION BY MachineNo) Machine_MachineRunningTime
,SUM(MachineRunningTime) OVER() Month_MachineRunningTime

,SUM(PlannedProductionTime) OVER(PARTITION BY BillDate) Date_PlannedProductionTime
,SUM(PlannedProductionTime) OVER(PARTITION BY MachineNo) Machine_PlannedProductionTime
,SUM(PlannedProductionTime) OVER() Month_PlannedProductionTime

,SUM(GoodOutput) OVER(PARTITION BY BillDate) Date_GoodOutput
,SUM(GoodOutput) OVER(PARTITION BY MachineNo) Machine_GoodOutput
,SUM(GoodOutput) OVER() Month_GoodOutput

,SUM(TotalOutput) OVER(PARTITION BY BillDate) Date_TotalOutput
,SUM(TotalOutput) OVER(PARTITION BY MachineNo) Machine_TotalOutput
,SUM(TotalOutput) OVER() Month_TotalOutput
into #t1
from #OEE_Report

select MAX(BillDate) BillDate, MachineNo
into #t2
from #t1
group by MachineNo 



select(
	select #t1.BillDate, #t2.MachineNo, MachineCode, MachinePosition, OEE
	,DailyTotal = cast((cast(Date_OperatingTime as float) * cast(Date_MachineRunningTime as float) * (case when Date_GoodOutput = 0 then 1 else Date_GoodOutput end))
	/ (cast(Date_TotalWorkingMinutes as float) * cast(Date_PlannedProductionTime as float) * (case when Date_TotalOutput = 0 then 1 else Date_TotalOutput end)) as decimal(18,4)) 
	,MachineTotal = cast((cast(Machine_OperatingTime as float) * cast(Machine_MachineRunningTime as float) * (case when Machine_GoodOutput = 0 then 1 else Machine_GoodOutput end))
	/ (cast(Machine_TotalWorkingMinutes as float) * cast(Machine_PlannedProductionTime as float) * (case when Machine_TotalOutput = 0 then 1 else Machine_TotalOutput end)) as decimal(18,4)) 
	,MonthTotal = cast((cast(Month_OperatingTime as float) * cast(Month_MachineRunningTime as float) * (case when Month_GoodOutput = 0 then 1 else Month_GoodOutput end))
	/ (cast(Month_TotalWorkingMinutes as float) * cast(Month_PlannedProductionTime as float) * (case when Month_TotalOutput = 0 then 1 else Month_TotalOutput end)) as decimal(18,4)) 
	from #t1
	inner join #t2 on #t1.BillDate = #t2.BillDate and #t1.MachineNo = #t2.MachineNo
	order by #t1.MachineNo
	for json path, include_null_values
) as [Value]
END
