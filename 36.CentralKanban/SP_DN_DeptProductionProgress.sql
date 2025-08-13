USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_DeptProductionProgress]    Script Date: 6/10/2023 8:46:38 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Darius Nguyen
-- Create date: 2023-06-09
-- Description:	SCR202210227_Kanban tập trung VND
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_DeptProductionProgress]
	@pDept nvarchar(10) = 'DPD2'

AS
BEGIN
select(
	select BigSO, BigSOItemNo
		   ,cast(BigSOItemNo as varchar) + '<br>' + BigSO + '<br>' as Argument
		   ,SUM(AccumulatedQCQuantity) AccumulatedQCQuantity 
		   ,SUM(AccumulatedQuantity) AccumulatedQuantity
		   ,SUM(TotalWHSIn) TotalWHSIn
	from T_R_DeptSummary (nolock)
	where Dept = @pDept
	group by BigSO, BigSOItemNo
	for json path, include_null_values
) as [Value]

END
