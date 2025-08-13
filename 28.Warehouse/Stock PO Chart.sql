CREATE OR ALTER PROCEDURE SP_R_SAPWHSStockByPOChart
 @Factory nvarchar(200) = '2503,2513',
 @MaterialType nvarchar(5) = 'ZR01'
as
with t1 as (
select MaterialGroup,MaterialGroupDescription
	,Sum(StockQuantity) as TodayStartStock
	,Sum( case when Warehouse not in ('ONOS','ONHK','ONWY') then TotalInQuantity else 0 end) as InQuantity
	,Sum( case when Warehouse not in ('ONOS','ONHK','ONWY') then TotalOutQuantity else 0 end) as OutQuantity
	,Sum( case when Warehouse in ('ONOS','ONHK','ONWY') then StockQuantity + TotalInQuantity - TotalOutQuantity else 0 end ) as ProcessingQuantity
from [R_SAP_WHS_Stock_IO](nolock) 
where Factory in (select * from string_split(@Factory,','))
and MaterialType = @MaterialType
group by MaterialGroup,MaterialGroupDescription
)
select MaterialGroupDescription as [Param],cast(TodayStartStock + InQuantity - OutQuantity - ProcessingQuantity as decimal(18,2)) as [Value]
from t1
