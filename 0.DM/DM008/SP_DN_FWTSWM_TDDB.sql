USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_FWTSWM_TDDB]    Script Date: 4/19/2023 7:32:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Created in 172.19.18.86.dbo.ROS

ALTER PROCEDURE [dbo].[SP_DN_FWTSWM_TDDB]
as
---------------------------- Take MO incomplete ----------------------------
drop table if exists #MOInc
select ZDCODE as MO
	,CUSTNAME
	,SUBSTRING(STYLE_NO,6,3) as StyleBody
	,SUBSTRING(STYLE_NO,9,1) as Sex
	,MY_COUNT as MOQty
into #MOInc
from ETSDB_SHOES.dbo.T_SCZZD (nolock)
where [state] is null
and SUBSTRING(STYLE_NO,9,1) in ('M','W');
--select * from #MOInc
---------------------------- End Take MO incomplete -----------------------

--- Get MatingStock (Đồng bộ tồn kho) & TotalCumu (Luỹ kế phát liệu) -----
with t1 as (
	select Zdcode
	-- "Det vanh de & Vanh de" only
	,SUM(case when WorklayerNo in (101, 206) then Ccount else 0 end) MatingStock
	-- "Mu giay"
	,SUM(case when WorklayerNo = 5201 then Ccount else 0 end) TotalCumu
	from [ETSDB_SHOES].dbo.T_StoreInOutFlow(nolock)
	-- Only take FWTSWM store
	where StoreNo = 'FWTSWM'
	and Zdcode in (select MO from #MOInc)
	-- In Store Only
	and [State] = 1
	group by Zdcode
)
---- Get MatingStock (Đồng bộ tồn kho) & TotalCumu (Luỹ kế phát liệu) ----

-- Join Data --
,t2 as (
	select t2.MO, t2.CUSTNAME, t2.StyleBody, t2.Sex, t2.MOQty
		,t1.MatingStock, t1.TotalCumu, cast(t2.MOQty - t1.TotalCumu as int) LackQty
	from #MOInc t2
	inner join t1 on t1.Zdcode = t2.MO
)
select (
	select CUSTNAME, StyleBody, MO, Sex, MOQty, TotalCumu, LackQty, MatingStock from t2
	where LackQty > 0
	for json path
) as [Value]

