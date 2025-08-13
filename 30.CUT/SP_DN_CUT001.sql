USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_CUT001]    Script Date: 4/19/2023 6:38:40 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		DARIUS NGUYEN
-- Create date: 2021-11-25
-- Description:	KANBAN issues #23 - KTG0009 / Daily part
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_CUT001]
	@pStoreNo varchar(max) = 'AHP-C,CUT-B,CUT-C,CUT-E',
	@pWorkline varchar(10) = 'CUT-B'
AS

DECLARE @StoreNo TABLE (StoreNo nvarchar(15));
insert into @StoreNo
select * from string_split(@pStoreNo,',');

BEGIN
CREATE TABLE #temp (
	[Workline] varchar(24),
	[Shift] nvarchar(20),
	[IsNightShift] bit,
	[Type] nvarchar(20),
	[LayerType] varchar(5)
);
INSERT INTO #temp ([Workline],[Shift],[IsNightShift],[Type],[LayerType]) VALUES (@pWorkline,N'夜班CA ĐÊM',1,N'主料Liệu chính','MAIN');
INSERT INTO #temp ([Workline],[Shift],[IsNightShift],[Type],[LayerType]) VALUES (@pWorkline,N'夜班CA ĐÊM',1,N'辅料Phụ liệu','SUB');
INSERT INTO #temp ([Workline],[Shift],[IsNightShift],[Type],[LayerType]) VALUES (@pWorkline,N'白班CA NGÀY',0,N'主料Liệu chính','MAIN');
INSERT INTO #temp ([Workline],[Shift],[IsNightShift],[Type],[LayerType]) VALUES (@pWorkline,N'白班CA NGÀY',0,N'辅料Phụ liệu','SUB');
--drop table #temp
with t1 as (
	select t1.WorkLine
	  ,t1.Zdcode
	  ,t1.TotalQuantity
	  ,t1.IsNightShift
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
	and t1.StartTime >= (
	case when DATEPART(HOUR, GETDATE()) >= 20
	then DATEADD(HOUR, 20, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0))
		when DATENAME(DW, GETDATE()) = 'Monday'
		then DATEADD(HOUR, -4, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), -1))
		else DATEADD(HOUR, -4, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0))
	end)
)
,t2 as (
	select t1.IsNightShift
	  ,CASE WHEN (
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
	select IsNightShift
	  ,LayerType
	  ,SUM(TotalQuantity) Quantity
	from t2
	group by IsNightShift, LayerType	
)
--select * from t3
,t4 as (
	select t0.*
	,(case when t3.Quantity is null then 0 else t3.Quantity end) as Quantity
	from #temp t0
	left join t3 on t0.[IsNightShift] =  t3.IsNightShift and t0.LayerType = t3.LayerType
)
,t5 as (
	select Workline, IsNightShift, sum(Quantity) as ShiftQty from t4
	group by Workline, IsNightShift
)
,t6 as (
	select Workline, sum(Quantity) as DailyQty from t4
	group by Workline
)
,t7 as (
	select CutLine, NightTargetQty + DayTargetQty as AimQty
	from T_CUT_Plan 
	where Factory ='VNB'
	and ETSStoreNo in (select * from @StoreNo)
	and CutLine = @pWorkline
	and WorkDate = (
	case when DATEPART(HOUR, GETDATE()) < 20
	then convert(date, getdate())
	else convert(date, getdate() + 1)
	end)
)
select(
	select t4.Workline
		  ,t4.Shift
		  ,t4.Type
		  ,t4.Quantity
		  ,t5.ShiftQty
		  ,t6.DailyQty
		  ,t7.AimQty
		  ,cast(t6.DailyQty * 1.0 / t7.AimQty as decimal(18,4)) as Ratio
	from t4
	left join t5 on t4.IsNightShift = t5.IsNightShift
	left join t6 on t4.Workline = t6.Workline
	left join t7 on t4.Workline = t7.CutLine
	order by t4.Shift desc
	for json path
) as [Value]


END
--[SP_DN_CUT001]