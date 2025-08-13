USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_WHS0003]    Script Date: 4/19/2023 6:57:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_WHS0003]
@pInventory nvarchar(1000) = 'MBT1,MBT2',
@pFromShelfNo int = 0, @pToShelfNo int = 9999
AS

DECLARE @Inventory TABLE (Inventory nvarchar(15));
insert into @Inventory
select * from string_split(@pInventory,',');

BEGIN
with temp as (
	select t2.Type, t2.Amount
	from SHELVES_Stack t1
	inner join SHELVES_StackLog t2 on t1.StackId = t2.StackId
	where 1=1
	and Inventory in (select * from @Inventory)
	and t1.ShelfNo >= @pFromShelfNo
	and t1.ShelfNo <= @pToShelfNo
	and convert(date, t2.Time) = convert(date, getdate())
)
,temp1 as (
	select cast(sum(case when Type = 1 then Amount else 0 end) as decimal(18,2))as [Value],
	N'上架 Số lượng lên giá ' as [Param]
	from temp
)
,temp2 as (
	select cast(sum(case when Type = 2 then Amount else 0 end) as decimal(18,2))as [Value],
	N'下架 Số lượng xuống giá ' as [Param]
	from temp
)
,temp3 as (
	select cast(sum(case when Type = 3 then Amount else 0 end) as decimal(18,2))as [Value],
	N'调架 Số lượng điều giá ' as [Param]
	from temp
)
,result as (
	select case when Value is null then 0 else [Value] end as [Value], [Param] from temp1
	union all
	select case when Value is null then 0 else [Value] end as [Value], [Param] from temp2
	union all
	select case when Value is null then 0 else [Value] end as [Value], [Param] from temp3
)
select * from result --[SP_DN_WHS0003]
END
