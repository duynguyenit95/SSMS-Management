USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_C_RM042Collector]    Script Date: 4/19/2023 7:20:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_C_RM042Collector] 
AS

DECLARE @pDate date, @pFactory nvarchar(50), @pStyle nvarchar(7)
SET @pDate = convert(date,getdate()-6)
SET @pFactory = 'VNA,VNB,VNC,VND,VNE'
SET @pStyle = 'A01,R01'

DECLARE @Factory TABLE (Factory nvarchar(3));
insert into @Factory
select * from string_split(@pFactory,',');

DECLARE @Style TABLE (Style nvarchar(3));
insert into @Style
select * from string_split(@pStyle,',');

BEGIN
with
--Get RP507
t1 as (
	select WorkDate, Factory, workShop, workline, Style_No
	,SUM(TotalSAM) TotalSAM
	,MAX(WorkTime) WorkTime
	,SUM(TotalQty) TotalQty
	,MAX(EmpCount) EmpCount
	from RP507
	where 1=1 
	and Factory in (select * from @Factory)
	and SUBSTRING(Style_No,1,3) in (select * from @Style)
	and WorkDate >= @pDate
	and WorkTime > 0
	group by WorkDate, Factory, workShop, workline, Style_No
)
,t2 as (
	select t1.*
	,SUM(TotalSAM) OVER (PARTITION BY WorkDate, workline) SumTotalSAM
	,COUNT(Style_No) OVER (PARTITION BY WorkDate, workline) CountStyleNo
	from t1
)
,t3 as (
	select t2.*
	,cast(TotalSAM/60 as decimal(18,4)) TotalEarnedHours
	,cast(TotalSAM / SumTotalSAM * WorkTime / 60 as decimal(18,4)) TotalWorkingHours
	from t2
)
-- Inline
,t4 as (
	SELECT CONVERT(DATE, [Time]) QCDate, [LineNo], StyleNo, SUM(TotalNG) TotalNG
  FROM [QCSYSTEM].[dbo].[V_InlineAdidas] (nolock)
  where convert(date,[Time]) >= @pDate
  and SUBSTRING(StyleNo,1,3) in (select * from @Style)
  and Factory in (select * from @Factory)
  and TotalNG > 0
  group by CONVERT(DATE, [Time]), [LineNo], StyleNo
)
-- Endline
,t5 as (
	select convert(date,ta.[TimeStart]) QCDate,  ta.[LineNo], tb.StyleNo,SUM(tc.ErrCount) RWCount
  from [QCSYSTEM].[dbo].[EndLine] (nolock) ta
  left join [QCSYSTEM].[dbo].[CardInfo] (nolock) tb on ta.SID = tb.SID
  left join [QCSYSTEM].[dbo].[EndLineErr] (nolock) tc on ta.Id = tc.EndLineId and ta.[Level] = tc.[Level]
  where convert(date,ta.[TimeStart]) >= @pDate
  and SUBSTRING(tb.StyleNo,1,3) in (select * from @Style)
  and Factory in (select * from @Factory)
  and ErrCount >0
  group by convert(date,ta.[TimeStart]), ta.[LineNo], tb.StyleNo
)
-- RP005
,t6 as (
	select BillDate, WorkLine
	,SUM(case when OffStdCode = 3 then [Value] else 0 end) WaitingTime
	,SUM(case when OffStdCode in (1,2,7,9,10) then [Value] else 0 end) Machine
	,SUM(case when OffStdCode = 4 then [Value] else 0 end) QualityIssue
	,SUM(case when OffStdCode = 5 then [Value] else 0 end) ChangeOver
	,0 as Sampling
	,SUM(case when OffStdCode in (6,8) then [Value] else 0 end) Other
	from [ORP].[dbo].[ETS_OffWorkWithDate]
	where BillDate = @pDate
	--and WorkLine like 'A2-L11'
	group by BillDate, WorkLine
)
-- Get min WorkDate via StyleNo
,t7 as (
	select Style_No, workline, MIN(WorkDate) FirstDateProduction 
	from RP507
	where SUBSTRING(Style_No,1,3) in (select * from @Style)
	group by Style_No, workline
)
,result as (
	select t3.WorkDate [Date]
	,t7.FirstDateProduction
	,t3.Factory
	,t3.workShop Workshop
	,t3.workline Line
	,t3.Style_No StyleNo
	,t3.TotalEarnedHours
	,t3.TotalWorkingHours
	,DATEDIFF(day,t7.FirstDateProduction,t3.WorkDate) DayInProduction
	,t3.TotalQty
	,ISNULL(t4.TotalNG,0) InlineErr
	,ISNULL(t5.RWCount,0) EndlineErr
	,t3.EmpCount
	,cast(ISNULL(t6.WaitingTime,0) / t3.CountStyleNo as decimal(18,4)) WaitingTime
	,cast(ISNULL(t6.Machine,0) / t3.CountStyleNo as decimal(18,4)) Machine
	,cast(ISNULL(t6.QualityIssue,0) / t3.CountStyleNo as decimal(18,4)) QualityIssue
	,cast(ISNULL(t6.ChangeOver,0) / t3.CountStyleNo as decimal(18,4)) ChangeOver
	,cast(ISNULL(t6.Sampling,0) / t3.CountStyleNo as decimal(18,4)) Sampling
	,cast(ISNULL(t6.Other,0) / t3.CountStyleNo as decimal(18,4)) Other
	--into RM042_AdidasMEReport
	from t3
	left join t7
	on t3.Style_No = t7.Style_No and t3.workline = t7.workline
	left join t4
	on t3.WorkDate = t4.QCDate and t3.Style_No = t4.StyleNo and t3.workline = t4.[LineNo]
	left join t5
	on t3.WorkDate = t5.QCDate and t3.Style_No = t5.StyleNo and t3.workline = t5.[LineNo]
	left join t6
	on t3.WorkDate = t6.BillDate and t3.workline = t6.WorkLine collate database_default 
)
--select * from result
INSERT INTO RM042_AdidasMEReport
select *, GETDATE() UpdateTime, 1 OriginalData from result

DELETE RM042_AdidasMEReport
where [Date] >= @pDate
and UpdateTime < (select MAX(UpdateTime) from RM042_AdidasMEReport)


END