USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_WHS0005]    Script Date: 4/19/2023 6:58:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_WHS0005]
@pInventory nvarchar(1000) = 'MBT1,MBT2',
@pFromShelfNo int = 0, @pToShelfNo int = 9999
AS

DECLARE @Inventory TABLE (Inventory nvarchar(15));
insert into @Inventory
select * from string_split(@pInventory,',');

BEGIN
with temp as (
	select Type, Amount
	from SHELVES_Stack
	where 1=1
	and Type is not null
	and Inventory in (select * from @Inventory)
	and ShelfNo >= @pFromShelfNo
	and ShelfNo <= @pToShelfNo
)
,temp1 as (
	select cast(sum(case when Type = 'ZROH' then Amount else 0 end) as decimal(18,2))as [Value],
	N'布料 Vải' as [Param]
	from temp
)
,temp2 as (
	select cast(sum(case when Type = 'ZR01' then Amount else 0 end) as decimal(18,2))as [Value],
	N'棉 Bông' as [Param]
	from temp
)
,result as (
	select * from temp1
	union all
	select * from temp2
)
select * from result --[SP_DN_WHS0005]
END
