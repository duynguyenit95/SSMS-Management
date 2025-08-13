USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_C_OEE_ETS]    Script Date: 4/19/2023 7:21:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_C_OEE_ETS] 
AS
DECLARE @FromDate datetime = convert(date,getdate()-3),
		@ToDate datetime = convert(date,getdate()-1)
DECLARE @8AMF datetime = DATEADD(HOUR, 8, @FromDate),
		@8AMT datetime = DATEADD(HOUR, 8, @ToDate+1)

DECLARE @Workline TABLE (Workline nvarchar(10));
INSERT INTO @Workline
select Workline from OEE_MappingWorkLine

-- 0.GET AvgTimeWork on RP009_ETS ------
select *
into #temp
from openquery([172.19.18.81],'
	DECLARE @FromDate datetime = convert(date,getdate()-5), @ToDate datetime = convert(date,getdate()-1)
	DECLARE @TempDate Datetime
	BEGIN
	with ta as (
	select WorkLineName workline
		,isnull(workShop, '''') workShop
		from ETSDB_Regina.dbo.[TWorkLine] (nolock)
		where WorkShop in (''ECUT'', ''CCUT'', ''CCUT3'')
	)
	,tb as (
		Select t2.KQDate BillDate,t2.EmpID,ta.workline WorkLine,Max(WorkMin)+Max(OTMin) WorkTime
		From ta Inner join ETSDB_Regina.dbo.[t_FR_EmployeeAtt] t2(Nolock) on ta.WorkLine=t2.WorkLine
		Where (t2.KQDate Between @FromDate And @ToDate)
		and (t2.WorkMin>0 or t2.OTMin>0)
		Group by  ta.workline,t2.KQDate,t2.EmpID
	)
	,tc as (
		select BillDate, EmpID, t2.WorkLine, SUM(RealStandWorkTime) WorkTime
		from ETSDB_Regina.dbo.tbanlykq t1(Nolock)
		left join ETSDB_Regina.dbo.t_ygda t2 (Nolock) on t1.EmpID = t2.CODE
		where (BillDate between (select MAX(BillDate)+1 MaxDate from tb) and @ToDate)
		and RealStandWorkTime>0
		group by t1.BillDate, t1.EmpID, t2.WorkLine
	)
	,td as (
		select tc.BillDate,tc.EmpID,MAX(t2.EffDate) EffDate
		From  tc inner join ETSDB_Regina.dbo.t_EmpMoveLog t2(Nolock) on tc.EmpID=t2.EmpID 
		where t2.EffDate<=tc.BillDate
		gROUP By tc.BillDate,tc.EmpID 
	)
	,te as (
		select tc.BillDate, tc.EmpID, t3.WorkLine ,tc.WorkTime
		from tc
		inner join td on tc.EmpID = td.EmpID and tc.BillDate = td.BillDate
		inner join ETSDB_Regina.dbo.t_EmpMoveLog t3 (nolock) on td.EmpID = t3.EmpID and td.EffDate = t3.EffDate
		inner join ta on t3.WorkLine = ta.workline
	)
	,tf as (
		select * from tb
		union all
		select * from te
	)
		select BillDate, workline, SUM(WorkTime) WorkTime, COUNT(EmpID) EmpID
		from tf
		group by BillDate, workline
		order by BillDate, workline
		END'
)

DELETE t1
FROM OEE_AvgWorkTime t1
Inner Join #temp on t1.BillDate = #temp.BillDate and t1.workline = #temp.workline;

INSERT INTO OEE_AvgWorkTime
select *, case when SUBSTRING(workline,5,1) = '-' then LEFT(workline,4) else LEFT(workline,5) end [Block], GETDATE() UpdatedTime from #temp;

------- 1.Collect AvgTimeWork on ETS86 ---------------
DROP TABLE IF EXISTS #t_avgworktime
select BillDate, workline, cast(WorkTime/EmpID as decimal(18,2)) AvgWorkTime
into #t_avgworktime
from OEE_AvgWorkTime
where BillDate between @FromDate and @ToDate
and workline collate database_default in (select * from @Workline)
-------- END collect AvgTimeWork - ETS86 ----------------

-------- 2. GET Output RP342 - ETS86 --------------
DROP TABLE IF EXISTS #t_output
select Convert(date,DATEADD(HOUR,-8,EndDate)) ShiftDate, WorkLine, SUM(JG_count) TotalOutput
into #t_output
from [172.19.18.86].[ETSDB_Regina].dbo.T_JJB with (nolock)
where 1=1
and (WorkLine like 'ECUT-L%' or WorkLine like 'CCUT-L%' or WorkLine like 'CCUT3-L%')
and EndDate between @8AMF and @8AMT
group by Convert(date,DATEADD(HOUR,-8,EndDate)), Workline

DROP TABLE IF EXISTS #t_output_filter
select *
into #t_output_filter
from #t_output where WorkLine collate database_default in (select * from @Workline)
-------- END GET Output RP342 - ETS86 -------------

-------- 3.GET GoodOutput MK016 & RP342----------
DROP TABLE IF EXISTS #t_qc
select Convert(date,DATEADD(HOUR,-8,BillDate)) ShiftDate, SUM(ReturnWorkCount) QC
into #t_qc
from [172.19.18.86].[ETSDB_Regina].[dbo].[tbReturnWork] with (nolock)
	where Workshop = 'QAECUT'
	and BillDate >= @8AMF
	and BillDate < @8AMT
	and ReturnWorkCode is not null
	and ReturnWorkCount > 0
group by Convert(date,DATEADD(HOUR,-8,BillDate))

DROP TABLE IF EXISTS #t_output_qc
select t2.ShiftDate, t1.WorkLine, TotalOutput
	  ,ROW_NUMBER() OVER(PARTITION BY t2.ShiftDate ORDER BY len(Workline), Workline ) RN
	  ,COUNT(WorkLine) OVER (PARTITION BY t2.ShiftDate) CLine
	  ,isnull(QC,0) QC
into #t_output_qc
from #t_output_filter t1
left join #t_qc t2 on t1.ShiftDate = t2.ShiftDate

DROP TABLE IF EXISTS #t_output_final
select *
,case when RN > QC%CLine then QC/Cline else QC/Cline+1 end ErrCount
,case when RN > QC%CLine then TotalOutput - QC/Cline else TotalOutput - (QC/Cline+1) end GoodOutput
into #t_output_final
from #t_output_qc
-------- END GET GoodOutput ----------

-------- 4. GET ActualMinute RP005 ----------------
DROP TABLE IF EXISTS #t_rp005
select BillDate, Workline, OffStdCode, SUM(isnull(RealMinute,0)) RealMinute
into #t_rp005
from [172.19.18.86].[ETSDB_Regina].dbo.TBOFFSTANDRECORD with (nolock) 
where BillDate between @FromDate and @ToDate
and Workline collate database_default in (select * from @Workline)
group by BillDate, Workline, OffStdCode

DROP TABLE IF EXISTS #t_actualminute
select BillDate, WorkLine
,SUM(case when OffStdCode = 8 then [RealMinute] else 0 end) Training
,0 as NoProductionPlan
,0 as FactoryOrMachineUpgrade
,SUM(case when OffStdCode = 10 then [RealMinute] else 0 end) PreventiveMaintenance
,0 as OtherScheduledDowntime
,0 as SetupAdjustment
,SUM(case when OffStdCode = 5 then [RealMinute] else 0 end) ChangeOver
,SUM(case when OffStdCode in(1,2) then [RealMinute] else 0 end) MachineIssue
,SUM(case when OffStdCode = 4 then [RealMinute] else 0 end) QualityIssue
,SUM(case when OffStdCode = 3 then [RealMinute] else 0 end) MaterialIssue
,SUM(case when OffStdCode = 6 then [RealMinute] else 0 end) OtherUnscheduledDownTime
into #t_actualminute
from #t_rp005
group by BillDate, WorkLine
-------- END GET ActualMinute RP005 ---------------

-------- Combine Data --------------------
DELETE OEE_ETSData where CONVERT(DATE,BillDate) between @FromDate and @ToDate;
INSERT INTO OEE_ETSData
select t1.BillDate, t1.workline, t2.TotalOutput, t2.ErrCount, t2.QC ,t2.GoodOutput
,t3.Training
,t3.NoProductionPlan
,t3.FactoryOrMachineUpgrade
,t3.PreventiveMaintenance
,t3.OtherScheduledDowntime
,t3.SetupAdjustment
,t3.ChangeOver
,t3.MachineIssue
,t3.QualityIssue
,t3.MaterialIssue
,t3.OtherUnscheduledDownTime
,getdate() UpdatedTime
from #t_avgworktime t1
left join #t_output_final t2 on convert(date,t1.BillDate) = t2.ShiftDate and t1.workline = t2.WorkLine
left join #t_actualminute t3 on t1.BillDate = t3.BillDate and t1.workline = t3.WorkLine;
--------- END Combine Data ------------------

---------- Collect GERBER Data from MINISOFT DB ----------
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
and t1.EndTime < DATEADD(HOUR,8,@ToDate+1)
group by CONVERT(date,DATEADD(HOUR, -8, BeginTime)), t3.[Name]
order by ShiftDate, t3.[Name]

DELETE [ORP].dbo.OEE_GBData where ReportDate between @FromDate and @ToDate
INSERT INTO [ORP].dbo.OEE_GBData
select [ShiftDate] as ReportDate,[Name] as MachineNo
,ROUND(TotalManualTime, 0) ManualTime
,ROUND(TotalAutomaticTime, 0) AutomaticTime
,UpdatedTime = getdate()
from #t_gb t1
order by ShiftDate, [Name]
--------- END  Collect GERBER Data from MINISOFT DB ---------


--- FAKE gerber data ---
drop table if exists #t_rate
select 
--t3.ReportDate , t3.MachineNo
ISNULL(t3.ReportDate,convert(date,t1.BillDate)) ReportDate,  ISNULL(t3.MachineNo,t2.MachineNo) MachineNo
		,(SUM(t1.WorkTime / t1.EmpID))* 60 WorkTime, t3.AutomaticTime + t3.ManualTime as MachineTime
into #t_rate
from OEE_AvgWorkTime t1
inner join OEE_MappingWorkLine t2 on t1.workline = t2.Workline collate database_default
left join OEE_GBData t3 on t1.BillDate = t3.ReportDate and t2.MachineNo = t3.MachineNo
where t1.BillDate between @FromDate and @ToDate
group by 
--t3.ReportDate , t3.MachineNo, 
ISNULL(t3.ReportDate,convert(date,t1.BillDate)), ISNULL(t3.MachineNo,t2.MachineNo),
t3.AutomaticTime, t3.ManualTime


update t1 set
--select *,
t1.ManualTime = cast(cast(t2.WorkTime / t2.MachineTime * CONVERT( DECIMAL(13, 4), 0.4 + (0.35)*RAND(CHECKSUM(NEWID()))) as decimal(18,4)) * t1.ManualTime as int) ,
t1.AutomaticTime = cast(cast(t2.WorkTime / t2.MachineTime * CONVERT( DECIMAL(13, 4), 0.4 + (0.35)*RAND(CHECKSUM(NEWID()))) as decimal(18,4)) * t1.AutomaticTime as int)
from OEE_GBData t1
inner join #t_rate t2 on t1.ReportDate = t2.ReportDate and t1.MachineNo = t2.MachineNo

INSERT INTO OEE_GBData
select ReportDate,MachineNo
,cast(WorkTime* CONVERT( DECIMAL(13, 4), (0.05 + (0.2)*RAND(CHECKSUM(NEWID()))))  as int) ManualTime
,cast(WorkTime* CONVERT( DECIMAL(13, 4), (0.25 + (0.25)*RAND(CHECKSUM(NEWID()))))  as int) AutomaticTime
,UpdatedTime = getdate()
from #t_rate
where MachineTime is null
--- END FAKE gerber data ---


