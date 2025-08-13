USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_WorkshopInOutDaily]    Script Date: 5/26/2023 8:50:42 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Created in 172.19.18.86.dbo.ROS

ALTER PROCEDURE [dbo].[SP_DN_WorkshopInOutDaily]
	@pStoreNo varchar(500) = 'IJT-DTWH'
AS

DECLARE @StoreNo TABLE (StoreNo varchar(20));
insert into @StoreNo
select * from string_split(@pStoreNo,',');
--DECLARE @Monday date = DATEADD(week, DATEDIFF(week, 0, getdate() - 1), 0)

BEGIN
select (
	select HandOverWorkline as Field
	,SUM(Ccount) Qty
	from T_ETS_StoreInOut_Handover (nolock)
	where StoreNo collate database_default in  (select * from @StoreNo)
	and BillDate >= convert(date,getdate())
	and State = 2
	and InOutType = 0
	group by HandOverWorkline
	order by Field
	for json path
) as [Value]
END
--EXEC [SP_DN_WorkshopInOutDaily] @pStoreNo = 'IJT-DTWH'