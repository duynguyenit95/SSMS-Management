USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_RM045]    Script Date: 5/30/2023 4:35:12 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/
ALTER PROCEDURE [dbo].[SP_DN_RM045]
@pStartDate date = '2023-05-01',
@pEndDate date = '2023-05-06'
AS

DECLARE @Date TABLE (Date date)
DECLARE @Warehouse TABLE (Warehouse varchar(5))

DECLARE @index date = @pStartDate
DECLARE @WHfrom int = 9, @WHto int = 99

WHILE(@index <= @pEndDate)
BEGIN
	IF DATENAME(DW, @index) != 'Sunday'
	INSERT INTO @Date 
	select @index
	SET @index = DATEADD(day, 1, @index)
END

WHILE (@WHfrom <= @WHto)
BEGIN
	IF len(@WHfrom) = 1
	INSERT INTO @Warehouse
	select 'HA0'+cast(@WHfrom as varchar)
	ELSE
	INSERT INTO @Warehouse
	select 'HA'+cast(@WHfrom as varchar)
	SET @WHfrom = @WHfrom +1
END

BEGIN
--SAP
with t0 as (
	select Date, SUM(Quantity) SAPStock
	from [SAP].[dbo].[T_R_SAPStock]
	where Warehouse in (select * from @Warehouse)
	and MaterialType in ('FERT','FOAM')
	and Factory in (2503, 2513)
	group by [Date]
)
--ETS
,t1 as (
	select convert(Date, Indate) BillDate, SUM(Ccount) Qty
	from [172.19.18.86].[ETSDB_Regina].dbo.[T_STOREGROUPS] with (nolock)
	where StoreNo in ('WHS-B','WHS-B1')
	and State = 1
	and InDate < DATEADD(day,1,@pEndDate)
	group by convert(Date, Indate)
)
,t1a as (
	select BillDate, SUM(Qty) OVER (Order by BillDate) ETSStock
	from t1
)
--SAP
,t2 as (
	select InputDate
	,SUM(case when Factory in (2503,2513) 
				AND TransferType in ('101','102') then Quantity else 0 end) SAPIn
	,SUM(case when (Factory = 2513 and TransferType in ('601','602')
				OR Factory = 2502 and Warehouse = 'GAP1')
			  then Quantity else 0 end) SAPEx
	from [SAP].[dbo].[C_ZBAPI_MAT_TRANSFER_BY_WAREHOUSE] (nolock)
	where InputDate between @pStartDate and @pEndDate
	AND (Warehouse in (select * from @WareHouse) OR Warehouse = 'GAP1')
	group by InputDate
)
,t3 as (
	select BillDate,Convert(date,BillDate) as Date,State,InOutType,HandOverWorkshop,StoreNo,Ccount,WorklayerNo
	from [172.19.18.86].[ROS].dbo.[T_ETS_StoreInOut_Handover] with (nolock)
	where StoreNo in ('WHS-B','WHS-B1','FGM1','FGM2','FGM3','FGM5','FGM6','FGM8')
	and State = 1
	and Billdate between @pStartDate and DATEADD(day,1,@pEndDate)
)
,t3a as (
	select Date
	,SUM(case when StoreNo in ('WHS-B','WHS-B1')
					  and HandOverWorkshop in ('FNG-A','FNG-B','FNG-C','FNG-E1','FNG-E2') then Ccount else 0 end) as ETSIn
	,SUM(case when StoreNo in ('FGM1','FGM2')	and InOutType = 1 and WorklayerNo != 7000 then Ccount else 0 end) as ExVNA
	,SUM(case when StoreNo in ('FGM1','FGM2')	and InOutType = 1 and WorklayerNo  = 7000 then Ccount else 0 end) as ExSVNA
	,SUM(case when StoreNo in ('FGM5')			and InOutType = 1 and WorklayerNo != 7000 then Ccount else 0 end) as ExVNC
	,SUM(case when StoreNo in ('FGM5')			and InOutType = 1 and WorklayerNo  = 7000 then Ccount else 0 end) as ExSVNC
	,SUM(case when StoreNo in ('FGM3')			and InOutType = 1 and WorklayerNo != 7000 then Ccount else 0 end) as ExVND
	,SUM(case when StoreNo in ('FGM6','FGM8')	and InOutType = 1 and WorklayerNo != 7000 then Ccount else 0 end) as ExVNE
	from t3
	group by Date
)
select (
	select t3a.*, t2.SAPEx, t2.SAPIn, t1a.ETSStock, t4.ExHY, t4.ExSZ, t4.InFOAM, t4.ExSZFOAM, t0.SAPStock
	from t2
	inner join t3a on t2.InputDate = t3a.Date
	left join t1a on t2.InputDate = t1a.BillDate
	left join RM045_WHSManualData t4 on t2.InputDate = t4.Date
	left join t0 on t2.InputDate = t0.Date
	for json path, include_null_values
) as [Value]

END
--[SP_DN_RM045]