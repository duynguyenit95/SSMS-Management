USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_WorklineSummaryWithEmp]    Script Date: 4/19/2023 7:58:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		DARIUS NGUYEN
-- Create date: 2022-09-29
-- Description:	KANBAN - ETSEmployeeEffciency Daily part
-- =============================================
ALTER PROCEDURE [dbo].[SP_DN_WorklineSummaryWithEmp]
	@pDept varchar(10) = 'ESP',
	@pGxNo varchar(max) = '50351'
AS

DECLARE @GxNo TABLE (GxNo nvarchar(10));
insert into @GxNo
select * from string_split(@pGxNo,',');

BEGIN

with ta as (
	select *
	from
	(
		SELECT  WorkDate, Dept, Workshop, WorkLine, EmpID, Emp_name, TimeString, TotalQty
		FROM [ROS].[dbo].[WorkLineSummaryWithEmp]
		where WorkDate = Convert(date,getdate())
		and Dept = @pDept
		and Gx_No in (select * from @GxNo)
	
	) src
	pivot (
		sum(TotalQty)
		for TimeString in ([08:00-09:00],[09:00-10:00],[10:00-11:00],[11:00-12:00],[12:00-13:00],
						   [13:00-14:00],[14:00-15:00],[15:00-16:00],[16:00-17:00],[17:00-18:00],[18:00-19:00])
	) piv
)
select(
	select WorkDate, Dept, Workshop, WorkLine, EmpID, Emp_name,
	[08:00-09:00] F8T9,
	[09:00-10:00] F9T10,
	[10:00-11:00] F10T11,
	[11:00-12:00] F11T12,
	[12:00-13:00] F12T13,
	[13:00-14:00] F13T14,
	[14:00-15:00] F14T15,
	[15:00-16:00] F15T16,
	[16:00-17:00] F16T17,
	[17:00-18:00] F17T18,
	[18:00-19:00] F18T19
	from ta
	for json path
) as [Value]


END
