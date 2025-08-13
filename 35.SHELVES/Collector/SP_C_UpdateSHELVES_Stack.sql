USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_C_UpdateSHELVES_Stack]    Script Date: 4/19/2023 6:54:06 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[SP_C_UpdateSHELVES_Stack]

AS
BEGIN
SELECT --top (100)
	   t3a.Id BarcodeId
	  ,t3.Id StackId
	  ,t3.Name Stack
	  ,t1.Id InventoryId
	  ,t1.Name Inventory
	  ,t2.Id ShelfId
	  ,t2.Name Shelf
	  ,t2.No ShelfNo
	  ,t3a.ItemNo
	  ,t3a.TimeUpdated
	  ,t3a.Amount
	  ,t3a.SAPID
	  ,t4.StyleNo
	  ,t4.ItemNumber
	  ,t4.Type
	  ,t4.Cylinder
	  ,t4.Color
	  ,t4.GroupColor
	  ,t4.ActualAmount
	  ,t4.VolumeNumber
	  ,t4.Weight
	  --drop table #tempStack
	  into #tempStack
from SHELVES.dbo.Inventory(nolock) t1
inner join SHELVES.dbo.Shelf(nolock) t2 on t1.Id = t2.InventoryId
inner join SHELVES.dbo.Stack(nolock) t3 on t2.Id = t3.ShelfId
inner join SHELVES.dbo.Barcode(nolock) t3a on t3.Id = t3a.StackId
left join SHELVES.dbo.SAPMain(nolock) t4 on t3a.SAPID = t4.Id
where t3.IsDeleted = 0
order by t3.Id;

MERGE SHELVES_Stack as target
USING #tempStack as s
ON target.BarcodeId = s.BarcodeId
WHEN MATCHED 
			AND (  target.ItemNo != s.ItemNo 
					OR (
							target.ItemNo is null 
							AND s.ItemNo is not null
						) 
					OR (
							target.ItemNo is not null 
							AND  s.ItemNo is null
						)
				 )
			OR target.TimeUpdated != s.TimeUpdated
	THEN UPDATE SET Stack = s.Stack,
			 Inventory = s.Inventory,
			 Shelf = s.Shelf,
			 ItemNo = s.ItemNo,
			 TimeUpdated = s.TimeUpdated,
			 Amount = s.Amount,
			 SAPID = s.SAPID,
			 StyleNo = s.StyleNo,
			 ItemNumber = s.ItemNumber,
			 Type = s.Type,
			 Cylinder = s.Cylinder,
			 Color = s.Color,
			 GroupColor = s.GroupColor,
			 ActualAmount = s.ActualAmount,
			 VolumeNumber = s.VolumeNumber,
			 Weight = s.Weight
WHEN NOT MATCHED BY TARGET THEN
  INSERT (BarcodeId, StackId, Stack, InventoryId, Inventory, ShelfId, Shelf, ShelfNo, ItemNo, TimeUpdated, Amount, SAPID, StyleNo, ItemNumber, [Type], Cylinder, Color, GroupColor, ActualAmount, VolumeNumber, [Weight])
  VALUES (s.BarcodeId, s.StackId, s.Stack, s.InventoryId, s.Inventory, s.ShelfId, s.Shelf, s.ShelfNo, s.ItemNo, s.TimeUpdated, s.Amount, s.SAPID, s.StyleNo, s.ItemNumber, s.[Type], s.Cylinder, s.Color, s.GroupColor, s.ActualAmount, s.VolumeNumber, s.[Weight])
WHEN NOT MATCHED BY SOURCE THEN	
  DELETE;
END
--set statistics time on

--(	select * from SHELVES_Stack
--	except
--	select * from #tempStack )
--union all
--(	select * from #tempStack
--	except
--	select * from SHELVES_Stack )
----set statistics time off
--select t1.StackId, t2.StackId, t1.ItemNo, t2.ItemNo from SHELVES_Stack t1
--	inner join #tempStack t2 on t1.StackId = t2.StackId
--	where (t1.ItemNo != t2.ItemNo OR (t1.ItemNo is null AND t2.ItemNo is not null) OR (t1.ItemNo is not null AND  t2.ItemNo is null))