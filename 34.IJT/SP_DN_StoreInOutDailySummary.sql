USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_StoreInOutDailySummary]    Script Date: 4/19/2023 8:01:12 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Created in 172.19.18.86.dbo.ROS

ALTER PROCEDURE [dbo].[SP_DN_StoreInOutDailySummary]
	@pStoreNo varchar(500) = 'IJT-DTWH'
AS

DECLARE @StoreNo TABLE (StoreNo varchar(20));
insert into @StoreNo
select * from string_split(@pStoreNo,',');

BEGIN

with t0 as (
	select State, Ccount
	from T_ETS_StoreInOut_Handover
	where StoreNo collate database_default in  (select * from @StoreNo)
	and BillDate >= convert(date,getdate())
	and InOutType = 0
)
,t1 as (
	select N'物料入库<br>Nhập kho' Field
	,SUM(case when [State] = 1 then Ccount else 0 end ) Qty
	from t0
)
,t2 as (
	select N'物料出入<br>Xuất kho' Field
	,SUM(case when [State] = 2 then Ccount else 0 end ) Qty
	from t0
)
,result as (
	select * from t1
	union
	select * from t2
)
select (
	select * from result
	for json path
) as [Value]
END
--EXEC [SP_DN_WorkshopStoreInOutDailySummary] @pStoreNo = 'IJT-DTWH'



