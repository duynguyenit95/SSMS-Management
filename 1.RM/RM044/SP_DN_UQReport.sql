USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_UQReport]    Script Date: 4/19/2023 7:25:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_DN_UQReport]
@FromDate datetime = '2022-12-22',
@EndDate datetime = '2022-12-22'
as
BEGIN

DROP TABLE IF EXISTS #t_sap
select SaleNo, SOItemNo, Factory, MaterialType, MaterialNo, SAPstyle, Dyelot, Barcode, CONVERT(date, MaterialArrivalDate, 104) MaterialArrivalDate, MaterialDescription, Gridvalue, InspectedInventory, Quantity
into #t_sap
from SAP.dbo.C_ZBAPI_MAT_STOCK_BY_WAREHOUSE (nolock) 
where MaterialType = 'ZROH'
and LEFT(SaleNo, 1) = 'A'
and InspectedInventory > 0
and LEFT(Factory,2) = '25'
and CONVERT(date, MaterialArrivalDate, 104) >= @FromDate
and CONVERT(date, MaterialArrivalDate, 104) <= @EndDate

DROP TABLE IF EXISTS #t_SOQty
SELECT SO, SOItemNo, Factory, SUM(Quantity) Quantity
into #t_SOQty
FROM [SAP].[dbo].[SOInfors] (nolock)
group by SO, SOItemNo, Factory

DROP TABLE IF EXISTS #t_base
select t1.*, t2.DSClass, CONVERT(DATE,t3.CreateDate) CreateDate, t3.GridDescription, t4.Quantity SOQty
into #t_base
from #t_sap t1
left join ORP.dbo.IMMQI_SAPColorCode t2 on t1.Gridvalue = t2.SAPColorCode collate database_default
left join ORP.dbo.IMMQI_BarcodeCreateDate t3 on t1.Barcode = t3.Barcode collate database_default
left join #t_SOQty t4 on t1.SaleNo = t4.SO and t1.SOItemNo = t4.SOItemNo and t1.Factory = t4.Factory

DROP TABLE IF EXISTS #t_analyze1
select *
,CASE WHEN MaterialDescription LIKE N'%341199%' 
		OR MaterialDescription LIKE N'%121145%'
		OR MaterialDescription LIKE N'%12531%' 
		OR MaterialDescription LIKE N'%341413%'
		OR MaterialDescription LIKE N'%123519%'
		OR MaterialDescription LIKE N'%329090%'
THEN 'Spandex' ELSE null END as TypeFabric--('341199','121145','12531','341413','123519','329090')
into #t_analyze1
from #t_base

DROP TABLE IF EXISTS #t_analyze2
select *
,CASE WHEN TypeFabric = 'Spandex' THEN 60
	-- màu nhạt / màu sáng: 180 ngày
	  WHEN DSClass = N'浅色' THEN 90
	  WHEN DSClass = N'深色' THEN 180
	  ELSE null END as ValidDay
into #t_analyze2
from #t_analyze1

select NEWID() as ID,*
,DATEADD(day, ValidDay, CreateDate) ValidDate
,DATEDIFF(day,CONVERT(date, getdate()),DATEADD(day, ValidDay, CreateDate)) RemainDay
,CONVERT(date, getdate()) CurrentDay
from #t_analyze2
--where ValidDay is not null
--and CreateDate is not null

END
