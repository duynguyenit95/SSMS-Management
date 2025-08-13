CREATE OR ALTER PROCEDURE SP_R_SAPWHSFoamStockByFactory
as
DECLARE @FactoryKanban nvarchar(10) = 'VNBWHS';
select * 
into #Tempres
from [R_SAP_WHS_Stock_IO](nolock) 
where Factory in ('2503','2513')
and MaterialType in('FOAM','FERT')
and (Warehouse = 'VBB1' OR ('HA07' <= Warehouse AND Warehouse <= 'HA99'))
;

select cast(N'A,C,D,E 厂' as nvarchar(30)) as Factory,
		(	select Sum(Total) 
			from [vnrmetsmdm1].[ROS].[dbo].[R_ETSWarehouseStock]
			where StoreNo in ('WHS-B','WHS-B1')
		) as Stock,
		(
			SELECT Sum(TotalQty)
			FROM [ORP].[dbo].[ETS_StoreIOByMODate]
			where [Date] = convert(date,GetDate())
			and ProcessName ='VNBWHSImp'
		) as [InQuantity],
		(
			SELECT Sum(TotalQty)
			FROM [ORP].[dbo].[ETS_StoreIOByMODate]
			where [Date] = convert(date,GetDate())
			and ProcessName ='VNBWHSExp'
		) as [OutQuantity]
into #VNHY
		;






;
with t1 as(
	select cast(N'Hưng Yên 兴安' as nvarchar(30)) as Factory
		  ,Sum(StockQuantity)  as Stock
		  ,Sum(TotalInQuantity)  as [InQuantity]
		  ,Sum(TotalOutQuantity)  as [OutQuantity]
	from #Tempres
	where Factory = '2503' and MaterialType = 'FOAM' and SaleNo like N'H%'
),
t2 as(
	select cast(N'Thẩm Quyến 深圳' as nvarchar(30)) as Factory
		  ,Sum(StockQuantity)  as Stock
		  ,Sum(TotalInQuantity)  as [InQuantity]
		  ,Sum(TotalOutQuantity)  as [OutQuantity]
	from #Tempres
	where Factory in ('2503','2513') and MaterialType = 'FOAM' and SaleNo like N'Z%'
),
t3 as(
	select cast(N'Khách hàng 客户' as nvarchar(30)) as Factory
		  ,Sum(StockQuantity)  as Stock
		  ,Sum(TotalInQuantity)  as [InQuantity]
		  ,Sum(TotalOutQuantity)  as [OutQuantity]
	from #Tempres
	where Factory in ('2513') and MaterialType = 'FERT'
)
INSERT INTO [dbo].[R_WarehouseStockIODaily]
           ([FactoryKanban]
           ,[Factory]
           ,[Stock]
           ,[InQuantity]
           ,[OutQuantity]
           ,[UpdateTime])
select @FactoryKanban as FactoryKanban,*,GetDate() as UpdateTime 
from (
	select * from t1
	union all 
	select * from t2 
	union all
	select * from t3
	union all
	select * from #VNHY
) ta 
--group by MaterialGroup,MaterialGroupDescription,POGrou

delete from [R_WarehouseStockIODaily] 
where FactoryKanban = @FactoryKanban
and UpdateTime < (select max(UpdateTime) from [R_WarehouseStockIODaily] where FactoryKanban = @FactoryKanban)