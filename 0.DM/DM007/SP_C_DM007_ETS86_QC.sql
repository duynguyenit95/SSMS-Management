USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_C_DM007_ETS86_QC]    Script Date: 4/19/2023 7:31:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_C_DM007_ETS86_QC] 
AS
-- MOD & FNC dept (VNB)
-- COLLECT DATA FROM ETS QC 
with ta as (
	select *
	--into #temp
	from openquery([172.19.18.86],'
		select
		BillDate as BillTime
		,Convert(date, DATEADD(HOUR, 4, BillDate)) BillDate
		,t1.ZhuBie,t1.Workshop,t1.Workline,t1.QCGxNo,t1.ZDCode,t2.STYLE_NO,t2.CUSTNAME,t1.CM,t2.COLOR_NO,t2.Quantity,t1.cCount
		,t1.ReturnWorkCode
		,t1.ReturnWorkCount
		,t1.CardCode
		from ROS.[dbo].[T_ETS_QC] (nolock) t1
		left join ROS.[dbo].[T_ETS_MOInProduction] (nolock) t2 on t1.ZDCode = t2.ZDCODE and t1.CM = t2.CM
		where 1=1
		and (Workline like ''FNG-%'' or Workline like ''MOD-%'')
		and QCGxNo in (9110,9120,9100,9001,6000,6090,6100,6101,8100,8000,8101,8490,1149,1150,9700,9701,9702)
		--and ReturnWorkCode > 0
		and BillDate >= CONVERT(date, getdate())
'))
,tb as (
	select distinct Workshop, Line from [ORP].[dbo].[KTV_CustomLine] where Workshop like 'MOD-%'
	union
	select distinct Wrk_no Workshop, Lin_no Line from [Regina_User].[dbo].[HR_Org] where Wrk_no like 'FNG-%'
)
,tc as (
	select *,Count(ReturnWorkCount) Over (Partition by CardCode Order by CardCode,BillTime Rows between UNBOUNDED PRECEDING and 1 PRECEDING) as CheckOrder 
	from ta
)
,td as (
	select case when CheckOrder = 0 then cCount+ReturnWorkCount else ReturnWorkCount end as Totalcheck
	,*
	from tc
)
,te as (
	select td.BillDate, tb.Workshop, td.ZDCode, td.STYLE_NO, td.CUSTNAME, td.CM, td.COLOR_NO, td.ReturnWorkCode
	,SUM(td.Quantity) Quantity, Sum(td.Totalcheck) TCount, Sum(td.ReturnWorkCount) ReturnWorkCount
	from td
	inner join tb on td.Workline = tb.Line collate database_default
	inner join DM007_ErrorCode tc on  td.ReturnWorkCode = tc.RWCode collate database_default
	and tc.WorkshopType = LEFT(td.Workshop,3) collate database_default
	group by td.BillDate, tb.Workshop, td.ZDCode, td.STYLE_NO, td.CUSTNAME, td.CM, td.COLOR_NO, td.ReturnWorkCode
)
--select * from te
INSERT INTO DM007_ETS_QC
select *, GETDATE() UpdatedTime, 'Sys' UpdatedUser,null Note, 0 IsDeleted, 1 IsOriginal
from te

delete from DM007_ETS_QC 
where convert(date, BillDate) = convert(date,GetDate())
and UpdatedTime >= convert(date,GetDate())
and UpdatedTime < (select Max(UpdatedTime) from DM007_ETS_QC where UpdatedTime >= convert(date,GetDate()));



