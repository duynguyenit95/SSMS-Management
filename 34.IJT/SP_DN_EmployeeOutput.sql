USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_EmployeeOutput]    Script Date: 4/19/2023 8:00:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Created in 172.19.18.86.dbo.ROS

ALTER PROCEDURE [dbo].[SP_DN_EmployeeOutput]
	@pWorkshop varchar(10) = 'IJT-D',
	@pGxNo varchar(max) = '1143'
AS

DECLARE @GxNo TABLE (GxNo nvarchar(10));
insert into @GxNo
select * from string_split(@pGxNo,',');

BEGIN

with t0 as (
	select EmpID, SUM(TotalQty) Quantity
	from WorkLineSummaryWithEmp
	where WorkDate = Convert(date,getdate())
	and Workshop = @pWorkshop
	and Gx_No in (select * from @GxNo)
	group by EmpID
)

select (
	select * from t0
	order by t0.EmpID
	for json path
) as [Value]
END
--[SP_DN_EmployeeOutput]