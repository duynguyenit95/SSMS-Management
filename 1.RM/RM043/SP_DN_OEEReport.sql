USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_OEEReport]    Script Date: 4/19/2023 7:24:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_DN_OEEReport]
@FromDate datetime = '2023-02-10',
@EndDate datetime = '2023-02-10',
@pBlock nvarchar(20) = 'CCUT,CCUT3,ECUT'
as

DECLARE @Block TABLE (Block nvarchar(5));
INSERT INTO @Block
select * from string_split(@pBlock,',');

BEGIN
DROP TABLE IF EXISTS #t_data
select CONVERT(DATE,t1.BillDate) BillDate, t1.workline
		,cast(t1.WorkTime / t1.EmpID as decimal(18,2)) AvgWorkTime
		,ISNULL(t2.Training				   ,0) Training				   
		,ISNULL(t2.NoProductionPlan		   ,0) NoProductionPlan		   
		,ISNULL(t2.FactoryOrMachineUpgrade ,0) FactoryOrMachineUpgrade 
		,ISNULL(t2.PreventiveMaintenance   ,0) PreventiveMaintenance   
		,ISNULL(t2.OtherScheduledDowntime  ,0) OtherScheduledDowntime  
		,ISNULL(t2.SetupAdjustment		   ,0) SetupAdjustment		   
		,ISNULL(t2.ChangeOver			   ,0) ChangeOver			   
		,ISNULL(t2.MachineIssue			   ,0) MachineIssue			   
		,ISNULL(t2.QualityIssue			   ,0) QualityIssue			   
		,ISNULL(t2.MaterialIssue		   ,0) MaterialIssue		   
		,ISNULL(t2.OtherUnscheduledDownTime,0) OtherUnscheduledDownTime
		,ISNULL(t2.TotalOutput			   ,0) TotalOutput			   
		,ISNULL(t2.GoodOutput			   ,0) GoodOutput			   
into #t_data
from OEE_AvgWorkTime (nolock) t1
left join OEE_ETSData (nolock) t2 on t1.BillDate = t2.BillDate and t1.workline = t2.workline
where Convert(date,t1.BillDate) between @FromDate and @EndDate
and t1.[Block] in (select * from @Block)

-- GET Gerber data via services ----
DROP TABLE IF EXISTS #t_gb
select CONVERT(date,DATEADD(HOUR, -8, BeginTime)) ShiftDate
,t3.[Name]
,SUM(case when t1.[Name] = 'TotalAutomaticTime' then [Value] else 0 end) TotalAutomaticTime
,SUM(case when t1.[Name] = 'TotalManualTime' then [Value] else 0 end) TotalManualTime
into #t_gb
from [MINISOFT].dbo.GB_MonitorData (nolock) t1
inner join [MINISOFT].dbo.GB_MonitorJobContext (nolock) t2
on t1.MonitorContextId = t2.MonitorContextId
inner join [MINISOFT].dbo.GB_DeviceConfig t3
on t1.[IP] = t3.[IP]
where t2.[Status] in ('Completed', 'Canceled')
and t1.BeginTime >= DATEADD(HOUR,8,@FromDate)
and t1.EndTime < DATEADD(HOUR,8,@EndDate+1)
group by CONVERT(date,DATEADD(HOUR, -8, BeginTime)), t3.[Name]
order by ShiftDate, t3.[Name]

-- GET Gerber data Fake --
--DROP TABLE IF EXISTS #t_gb
--select ReportDate as ShiftDate
--		,MachineNo as [Name]
--		,AutomaticTime as TotalAutomaticTime
--		,ManualTime as TotalManualTime
--into #t_gb
--from OEE_GBData
--where ReportDate  between @FromDate and @EndDate 


--- Combine data ----
DROP TABLE IF EXISTS #t_mapping
select t1.Factory, t1.Workline, t2.MachineNo, t2.MachineCode, t2.MachinePosition
into #t_mapping
from OEE_MappingWorkLine t1
inner join OEE_GBMachineInfo t2 on t1.MachineNo = t2.MachineNo

DROP TABLE IF EXISTS #t_combine
select t2.BillDate, 'Factory ' + RIGHT(t1.Factory,1) Factory
,t1.MachineNo, t1.MachineCode, t1.MachinePosition
,COUNT(t2.workline) * 10 [Break]
,COUNT(t2.workline) * 5 [Meeting]
,SUM(t2.AvgWorkTime				) TotalWorkingMinutes
,SUM(t2.Training				) Training				   
,SUM(t2.NoProductionPlan		) NoProductionPlan		   
,SUM(t2.FactoryOrMachineUpgrade ) FactoryOrMachineUpgrade 
,SUM(t2.PreventiveMaintenance   ) PreventiveMaintenance   
,SUM(t2.OtherScheduledDowntime  ) OtherScheduledDowntime  
,SUM(t2.SetupAdjustment		   	) SetupAdjustment		   	
,SUM(t2.ChangeOver			   	) ChangeOver			   	
,SUM(t2.MachineIssue			) MachineIssue			   
,SUM(t2.QualityIssue			) QualityIssue			   
,SUM(t2.MaterialIssue		   	) MaterialIssue		   	
,SUM(t2.OtherUnscheduledDownTime) OtherUnscheduledDownTime
,SUM(t2.TotalOutput			   	) TotalOutput			   	
,SUM(t2.GoodOutput				) GoodOutput				
--,cast((t3.TotalAutomaticTime + t3.TotalManualTime) / 60 as decimal(18,2))  MachineRunningTime
--,t2.*
into #t_combine
from #t_mapping t1
inner join #t_data t2 on t1.Workline = t2.workline collate database_default
--left join #t_gb t3 on t1.MachineNo = t3.Name and t2.BillDate = t3.ShiftDate
group by t2.BillDate, t1.Factory, t1.MachineNo, t1.MachineCode, t1.MachinePosition


DROP TABLE IF EXISTS #t_calculation
select t1.*
	,MachineRunningTime = cast((ISNULL(t2.TotalAutomaticTime,0) + ISNULL(t2.TotalManualTime,0)) / 60 as decimal(18,2))
	,ScheduledDowntime = ([Break] + [Meeting] + [Training] + NoProductionPlan + FactoryOrMachineUpgrade + PreventiveMaintenance + OtherScheduledDowntime)
	,UnScheduledDowntime = (SetupAdjustment + ChangeOver + MachineIssue + QualityIssue + MaterialIssue + OtherUnscheduledDownTime)
	,PlannedProductionTime = (TotalWorkingMinutes - ([Break] + [Meeting] + [Training] + NoProductionPlan + FactoryOrMachineUpgrade + PreventiveMaintenance + OtherScheduledDowntime))
	,OperatingTime = (TotalWorkingMinutes - ([Break] + [Meeting] + [Training] + NoProductionPlan + FactoryOrMachineUpgrade + PreventiveMaintenance + OtherScheduledDowntime) 
						- (SetupAdjustment + ChangeOver + MachineIssue + QualityIssue + MaterialIssue + OtherUnscheduledDownTime))
	,[Availability] = cast((TotalWorkingMinutes - ([Break] + [Meeting] + [Training] + NoProductionPlan + FactoryOrMachineUpgrade + PreventiveMaintenance + OtherScheduledDowntime)
						  - (SetupAdjustment + ChangeOver + MachineIssue + QualityIssue + MaterialIssue + OtherUnscheduledDownTime)) / TotalWorkingMinutes as decimal(18,4))
	,[Performance] = cast((ISNULL(t2.TotalAutomaticTime,0) + ISNULL(t2.TotalManualTime,0)) / 60 
					/ (TotalWorkingMinutes - ([Break] + [Meeting] + [Training] + NoProductionPlan + FactoryOrMachineUpgrade + PreventiveMaintenance + OtherScheduledDowntime)) as decimal(18,4))
	,[Quality] = case when TotalOutput = 0 then 1 else cast(cast(GoodOutput as float) / cast(TotalOutput as float) as decimal(18,4)) end
into #t_calculation
from #t_combine t1
left join #t_gb t2 on t1.MachineNo = t2.Name and t1.BillDate = t2.ShiftDate

select NEWID() ID
	  ,YEAR(BillDate) [Year]
	  ,case when(MONTH(DATEADD(Month,4,BillDate)) >= 6) then 'SS' else 'FW' end + RIGHT(YEAR(DATEADD(Month,4,BillDate)),2) Season
	  ,convert(date,DATEADD(MONTH, DATEDIFF(Month, 0, BillDate), 0)) [Month]
	  ,'Regina' SupplierGroup
	  ,'VIETNAM' COO
	  ,'Auto Cutting' MachineType, *
	  ,cast([Availability] * [Performance] * [Quality] as decimal(18,4)) OEE
	  ,null as TargetOEE
from #t_calculation
order by BillDate
END
