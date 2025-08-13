USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_CUT005]    Script Date: 4/19/2023 6:44:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		DARIUS NGUYEN
-- Create date: 2021-11-25
-- Description:	KANBAN issues #23 - KTG0009 / Daily part
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_CUT005]
	@pStoreNo varchar(max) = 'AHP-C,CUT-B,CUT-C,CUT-E',
	@pWorkline varchar(10) = 'CUT-B',
	@pTimeStart	datetime = '2022-03-07 20:00:00.000',
	@pTimeEnd datetime = '2022-03-08 08:00:00.000'
AS
DECLARE @StoreNo TABLE (StoreNo nvarchar(15));
insert into @StoreNo
select * from string_split(@pStoreNo,',');

SELECT ZDCODE, STYLE_NO, COLOR_NO, SUM(Quantity) ZdcodeQty
INTO #MOInProduction
FROM T_ETS_MOInProduction(nolock)
group by ZDCODE, STYLE_NO, COLOR_NO;

SELECT distinct StyleNo, LayerNo, LayerName
INTO #T_ETS_StyleGx
from T_ETS_StyleGx(nolock);

BEGIN
with t0 as (
	SELECT StoreNo, WorkLine, Zdcode, WorklayerNo, SUM(TotalQuantity) Quantity
	from T_ETS_CUTOutput(nolock) t1
	where 1=1
	and t1.StoreNo collate database_default in (select * from @StoreNo )
	and t1.WorkLine = @pWorkline
	and t1.StartTime >= @pTimeStart
	and t1.StartTime < @pTimeEnd
	group by StoreNo, WorkLine, Zdcode, WorklayerNo
)
,t1 as (
	select t0.WorkLine
	  ,t0.Zdcode
	  ,ta.STYLE_NO
	  ,ta.COLOR_NO
	  ,t0.WorklayerNo
	  ,tb.LayerName
	  ,ta.ZdcodeQty
	  ,t0.Quantity
	  ,t0.StoreNo
	  ,cast(t0.Quantity * 1.0 / ta.ZdcodeQty as decimal(18,4)) as Ratio
	from t0
	inner join #MOInProduction ta
	on t0.Zdcode = ta.ZDCODE
	inner join #T_ETS_StyleGx tb
	on ta.STYLE_NO = tb.StyleNo collate database_default
	and t0.WorklayerNo = tb.LayerNo
)
,t2 as (
	select *,Min(Ratio) Over ( Partition by Zdcode ) as MinRatio
		,ROW_NUMBER() OVER (
			PARTITION BY Zdcode
			ORDER BY Zdcode
		  ) ZIndex
		--,count(Zdcode)
	from t1
)
,t3 as (
	select Zdcode, COUNT(Zdcode) ZCount from t2
	group by Zdcode
)
select (
	select t2.*, t3.ZCount from t2
	inner join t3 on t2.Zdcode = t3.Zdcode
	for json path
) as [Value]

END
--[SP_DN_CUT005]