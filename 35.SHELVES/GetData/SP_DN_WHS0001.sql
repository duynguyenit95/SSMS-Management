USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_WHS0001]    Script Date: 4/19/2023 6:55:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_WHS0001]
@pInventory nvarchar(1000) = 'MBT1,MBT2',
@pFromShelfNo int = 0, @pToShelfNo int = 9999
AS

DECLARE @Inventory TABLE (Inventory nvarchar(15));
insert into @Inventory
select * from string_split(@pInventory,',');

BEGIN
select (
	select *, convert(date,TimeUpdated) Date
	from SHELVES_Stack
	where 1=1
	and Inventory in (select * from @Inventory)
	and StyleNo is not null
	and ShelfNo >= @pFromShelfNo
	and ShelfNo <= @pToShelfNo
	and (
			convert (date, TimeUpdated) = convert (date, getdate())
			or convert (date, TimeUpdated) <= convert (date, getdate()-25)
		)
	order by TimeUpdated desc
	for json path
) as [Value]


END
