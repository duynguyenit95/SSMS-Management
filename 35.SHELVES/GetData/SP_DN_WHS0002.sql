USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_WHS0002]    Script Date: 4/19/2023 6:56:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_WHS0002]
@pInventory nvarchar(1000) = 'MBT1,MBT2',
@pFromShelfNo int = 0, @pToShelfNo int = 9999
AS

DECLARE @Inventory TABLE (Inventory nvarchar(15));
insert into @Inventory
select * from string_split(@pInventory,',');

BEGIN
with temp as (
	select * from SHELVES_Stack
	where 1=1
	and Inventory in (select * from @Inventory)
	and ShelfNo >= @pFromShelfNo
	and ShelfNo <= @pToShelfNo
)
,temp1 as (
	select cast(count(TimeUpdated) as decimal(18,2)) as [Value], 
	N'架位使用 Số giá đã sử dụng ' as [Param]
	from temp
)
,temp2 as (
	select cast(sum(case when TimeUpdated is null then 1 else 0 end) as decimal(18,2))as [Value], 
	N'架位未使用 Số giá chưa sử dụng ' as [Param]
	from temp
)
,result as (
	select * from temp1
	union all
	select * from temp2
)
select * from result --[SP_DN_WHS0002]
END
