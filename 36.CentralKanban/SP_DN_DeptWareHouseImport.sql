USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_DeptWareHouseImport]    Script Date: 6/10/2023 8:47:00 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Darius Nguyen
-- Create date: 2023-06-08
-- Description:	SCR202210227_Kanban tập trung VND
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_DeptWareHouseImport]
	@pDept nvarchar(10) = 'DPD2'

AS
BEGIN
select(
	select BigSO, BigSOItemNo, ExportDate
		   ,cast(BigSOItemNo as varchar) + '<br>' + BigSO + '<br>' + cast(ExportDate as varchar) as Argument
		   ,SUM(TotalWHSIn) TotalWHSIn 
		   ,SUM(MOQuantity) MOQuantity
	from T_R_DeptSummary (nolock)
	where Dept = @pDept
	group by BigSO, BigSOItemNo, ExportDate
	order by ExportDate
	for json path, include_null_values
) as [Value]

END
