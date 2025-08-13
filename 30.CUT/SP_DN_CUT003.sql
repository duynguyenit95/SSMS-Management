USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_CUT003]    Script Date: 4/19/2023 6:42:46 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		DARIUS NGUYEN
-- Create date: 2021-11-25
-- Description:	KANBAN issues #23 - KTG0009 / Monthly part
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_CUT003]
	@pStoreNo varchar(max) = 'AHP-C,CUT-B,CUT-C,CUT-E',
	@pWorkline varchar(10) = 'CUT-C'
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
		N'当日累计裁切数量<br> <br>Số lượng cắt trong ngày ' as [Param]
	from T_ETS_CUTOutput(nolock)
	where 1=1
	and StoreNo collate database_default in (select * from @StoreNo )
	and WorkLine = @pWorkline
	and StartTime >= (
	case when DATEPART(HOUR, GETDATE()) >= 20
	then DATEADD(HOUR, 20, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0))
		when DATENAME(DW, GETDATE()) = 'Monday'
		then DATEADD(HOUR, -4, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), -1))
		else DATEADD(HOUR, -4, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0))
	end)
)
,temp2 as (
	select 
		cast(NightTargetQty + DayTargetQty as decimal(18,2)) as [Value],
		N'当日裁切目标<br> <br>Mục tiêu cắt trong ngày ' as [Param]
	from T_CUT_Plan(nolock)
	where 1=1
	and Factory ='VNB'
	and ETSStoreNo in (select * from @StoreNo)
	and CutLine = @pWorkline
	and WorkDate = (
	case when DATEPART(HOUR, GETDATE()) < 20
	then convert(date, getdate())
	else convert(date, getdate() + 1)
	end)
)
,temp3 as (
	select 
	cast(temp2.[Value] - temp1.[Value] as decimal(18,2)) as [Value],
	N'当日裁切欠数<br> <br>Số lượng cắt thiếu trong ngày ' as [Param]
	from temp1 inner join temp2 on 1=1
)
,result as (
	select * from temp3
	union all
	select * from temp1
)
select * from result--[SP_DN_CUT003]
END



	