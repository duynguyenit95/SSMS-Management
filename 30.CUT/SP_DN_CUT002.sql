USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_CUT002]    Script Date: 4/19/2023 6:40:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		DARIUS NGUYEN
-- Create date: 2021-11-25
-- Description:	KANBAN issues #23 - KTG0009 / Monthly part
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_CUT002]
	@pStoreNo varchar(max) = 'AHP-C,CUT-B,CUT-C,CUT-E',
	@pWorkline varchar(10) = 'CUT-B',
	@startMonth	date = '2021-11-01',
	@endMonth date = '2021-11-30'
AS
DECLARE @StoreNo TABLE (StoreNo nvarchar(15));
insert into @StoreNo
select * from string_split(@pStoreNo,',');

BEGIN
CREATE TABLE #temp (
	[Workline] varchar(24),
	[Type] nvarchar(20),
	[LayerType] varchar(5)
);
INSERT INTO #temp ([Workline],[Type],[LayerType]) VALUES (@pWorkline,N'主料Liệu chính','MAIN');
INSERT INTO #temp ([Workline],[Type],[LayerType]) VALUES (@pWorkline,N'辅料Phụ liệu','SUB');
--drop table #temp
with t1 as (
	select t1.Workline
	  ,t1.Zdcode
	  ,t1.TotalQuantity
	  ,t1.WorklayerNo
	  ,t2.STYLE_NO
	from T_ETS_CUTOutput(nolock) t1
	left join (
		SELECT DISTINCT ZDCODE, STYLE_NO
		FROM T_ETS_MOInProduction(nolock)
	) t2
	on t1.Zdcode = t2.ZDCODE
	where 1=1
	and t1.StoreNo collate database_default in (select * from @StoreNo )
	and t1.WorkLine = @pWorkline
	and t1.StartTime >= DATEADD(HOUR, -4, DATEADD(DAY, DATEDIFF(DAY, 0, @startMonth), 0))
)
,t2 as (
	select Workline, CASE WHEN (
	t2.LayerName like N'%mat lieu%'
	OR t2.LayerName like N'%day lieu%'
	OR t2.LayerName like N'%lieu hai mat%'
	OR t2.LayerName like N'%mat xop%'
	OR t2.LayerName like N'%day xop%'
	) THEN 'MAIN' ELSE N'SUB' END LayerType
		 ,t1.TotalQuantity
	from t1
	left join (
		select distinct StyleNo, LayerNo, LayerName from T_ETS_StyleGx(nolock)
	) t2
	on t1.STYLE_NO = t2.StyleNo collate database_default and t1.WorklayerNo = t2.LayerNo
)
,t3 as (
	select LayerType
	  ,SUM(TotalQuantity) Quantity
	from t2
	group by LayerType	
)
,t4 as (
	select t0.*
	,(case when t3.Quantity is null then 0 else t3.Quantity end) as Quantity
	from #temp t0
	left join t3 on t0.LayerType = t3.LayerType
)
,t5 as (
	select Workline, sum(Quantity) as MonthQty from t4
	group by Workline
)
,t6 as (
	select CutLine, 
	(SUM(NightTargetQty) + SUM(DayTargetQty)) as AimQty
	from T_CUT_Plan(nolock) 
	where Factory ='VNB'
	and ETSStoreNo in (select * from @StoreNo)
	and CutLine = @pWorkline
	and WorkDate >= @startMonth
	and WorkDate <= @endMonth
	group by CutLine
)
select(
	select t4.Workline
		  ,t4.Type
		  ,t4.Quantity
		  ,t5.MonthQty
		  ,t6.AimQty
		  ,cast(t5.MonthQty * 1.0 / t6.AimQty as decimal(18,4)) as Ratio
	from t4
	left join t5 on t4.Workline = t5.Workline
	left join t6 on t4.Workline = t6.CutLine
	for json path
) as [Value]

END
--[SP_DN_CUT002]


	