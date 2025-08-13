USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_CUT004]    Script Date: 4/19/2023 6:43:07 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		DARIUS NGUYEN
-- Create date: 2021-11-25
-- Description:	KANBAN issues #23 - KTG0009 / Monthly part
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_CUT004]
	@pStoreNo varchar(max) = 'AHP-C,CUT-B,CUT-C,CUT-E',
	@pWorkline varchar(10) = 'CUT-C',
	@startMonth	date = '2022-03-01',
	@endMonth date = '2022-03-30'
AS
DECLARE @StoreNo TABLE (StoreNo nvarchar(15));
insert into @StoreNo
select * from string_split(@pStoreNo,',');

BEGIN
with temp1 as(
	select
		cast(
			CASE WHEN SUM(TotalQuantity) is null then 0 else SUM(TotalQuantity) end
			as decimal(18,2)) as [Value], 
		N'当月累计裁切数量<br> <br>Số lượng cắt trong tháng ' as [Param]
	from T_ETS_CUTOutput(nolock)
	where 1=1
	and StoreNo collate database_default in (select * from @StoreNo )
	and WorkLine = @pWorkline
	and StartTime >= DATEADD(HOUR, -4, DATEADD(DAY, DATEDIFF(DAY, 0, @startMonth), 0))
)
,temp2 as (
	select 
		cast(
			CASE WHEN SUM(NightTargetQty) is null then 0 else SUM(NightTargetQty) end
		  + CASE WHEN SUM(DayTargetQty) is null then 0 else SUM(DayTargetQty) end
			as decimal(18,2)) as [Value],
		N'当月裁切目标<br> <br>Số lượng mục tiêu theo tháng ' as [Param]
	from T_CUT_Plan(nolock)
	where 1=1
	and Factory ='VNB'
	and ETSStoreNo in (select * from @StoreNo)
	and CutLine = @pWorkline
	and WorkDate >= @startMonth
	and WorkDate <= @endMonth
)
,temp3 as (
	select 
	cast(temp2.[Value] - temp1.[Value] as decimal(18,2)) as [Value],
	N'当月裁切欠数<br> <br>Số lượng cắt thiếu trong tháng ' as [Param]
	from temp1 inner join temp2 on 1=1
)
,result as (
	select * from temp3
	union all
	select * from temp1
)
select * from result--[SP_DN_CUT004]
END



	