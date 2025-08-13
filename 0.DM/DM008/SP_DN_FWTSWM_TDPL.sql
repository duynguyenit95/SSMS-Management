USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_FWTSWM_TDPL]    Script Date: 4/19/2023 7:33:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Created in 172.19.18.86.dbo.ROS

ALTER PROCEDURE [dbo].[SP_DN_FWTSWM_TDPL]
as
---------------------------- Output Result ----------------------------
drop table if exists #TempOutResult;
select Zdcode,PositionNo,Sum(Ccount) as TotalQty
into #TempOutResult
from [ETSDB_SHOES].dbo.T_StoreInOutFlow(nolock) ta
---- only Take FWUPP1
where StoreNo = 'FWUPP1'
---- Daily data
and Billdate >= convert(date,getdate())
---- In Store Only
and ta.[State] = 1 
---- Only Export worklayerno
and WorklayerNo = 5201
group by Zdcode,PositionNo;
--select * from #TempOutResult
---------------------------- End Output Result ----------------------------


---------------------------- Plan Data ----------------------------
drop table if exists #TPlan;
select Workline,StyleBody,Gender,SUM(PlanQty) PlanQty
into #TPlan
from [172.19.18.58].[ORP].[dbo].[T_FWTSWMExportPlan]
where [Date] = convert(date,getdate())
group by Workline,StyleBody,Gender;
--select * from #TPlan
---------------------------- End Plan Data ----------------------------


---------------------------- Analyze Data ----------------------------
with 
-- MO Infor
t1 as(
select ZDCODE as MO
	,SUBSTRING(STYLE_NO,6,3) as StyleBody
	,SUBSTRING(STYLE_NO,9,1) as Sex
	--,MY_COUNT as MOQty
from ETSDB_SHOES.dbo.T_SCZZD(nolock)
where 1 = 1
and ZDCODE in (select distinct Zdcode from #TempOutResult)
)
-- Output Details
,t2 as(
select ta.PositionNo, t1.StyleBody, t1.Sex, SUM(ta.TotalQty) TotalQty
from t1 
inner join #TempOutResult ta on t1.MO = ta.Zdcode 
group by ta.PositionNo, t1.StyleBody, t1.Sex
)
--select * from t2
-- Plan Details
select (
	select tb.Workline
	,tb.StyleBody
	,tb.Gender
	,tb.PlanQty
	,ISNULL(t2.TotalQty,0) ExportQty 
	from t2 right join #TPlan tb 
	on t2.PositionNo = RIGHT(UPPER(tb.Workline),2) collate database_default 
	and t2.StyleBody = tb.StyleBody collate database_default 
	and t2.[Sex] = tb.Gender collate database_default 
	order by len(tb.Workline), tb.Workline
	for json path
) as [Value]
--[SP_DN_FWTSWM_TDPL]