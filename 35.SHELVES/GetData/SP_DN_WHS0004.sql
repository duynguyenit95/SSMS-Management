USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_WHS0004]    Script Date: 4/19/2023 6:57:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_WHS0004]
@pInventory nvarchar(1000) = 'MBT1,MBT2',
@pFromShelfNo int = 0, @pToShelfNo int = 9999
AS

DECLARE @Inventory TABLE (Inventory nvarchar(15));
insert into @Inventory
select * from string_split(@pInventory,',');

BEGIN
with temp as (
	select t1.Type
		  ,t2.Amount
		  ,t2.Type ActionType
		  ,t2.Time
	from SHELVES_Stack t1
	left join SHELVES_StackLog t2 on t1.StackId = t2.StackId
	where 1=1
	and t1.Type is not null
	and Inventory in (select * from @Inventory)
	and t1.ShelfNo >= @pFromShelfNo
	and t1.ShelfNo <= @pToShelfNo
	and convert(date, t2.Time) = convert(date, getdate())
)
,t0 as
	(
		select * from 
			(
				select Type, ActionType, Amount from temp
			) src
		pivot 
		(
			sum(Amount) 
			for ActionType in ([1], [2])
		) piv
	)
,t1 as(
	select N'布料 Vải' as [Material]
	 ,SUM(case when Type = 'ZROH' then [1] else 0 end) as Up
	 ,SUM(case when Type = 'ZROH' then [2] else 0 end) as Down
	from t0	
)
, t2 as (
	select N'棉 Bông' as [Material]
	 ,SUM(case when Type = 'ZR01' then [1] else 0 end) as Up
	 ,SUM(case when Type = 'ZR01' then [2] else 0 end) as Down
	from t0	
)
,result as (
	select * from t1
	union all
	select * from t2	
)
--select * from result
--[SP_DN_WHS0004]
select (
	select * from result
	for json path
) as [Value]
END
