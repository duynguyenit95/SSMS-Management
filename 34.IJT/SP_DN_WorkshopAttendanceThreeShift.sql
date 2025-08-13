USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_WorkshopAttendanceThreeShift]    Script Date: 4/19/2023 8:03:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Created in 172.19.18.86.dbo.ROS

ALTER PROCEDURE [dbo].[SP_DN_WorkshopAttendanceThreeShift]
	@pWorkshop nvarchar(10) = 'IJT-D'
AS

DROP TABLE IF EXISTS #TimeSheet
CREATE TABLE #TimeSheet (
	[Shift] varchar(5),
	StartTime datetime,
	EndTime datetime
)

--Nếu vào sáng thứ 2, lấy dữ liệu ca tối từ hôm thứ 7 tuần trước
--Nếu dữ liệu load sau 22h tối, dữ liệu sẽ lấy load của ngày hôm sau, ca đêm lấy dữ liệu hiện tại, ca sáng và ca chiều hôm sau = 0
DECLARE @Date datetime = CASE WHEN DATEPART(HOUR,GETDATE()) < 22
							  THEN DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
							  ELSE DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 1) END
--SELECT DATEADD(HOUR,-2,DATEADD(DAY,-1, @Date)) 
INSERT INTO #TimeSheet VALUES('AB08',CASE WHEN DATEPART(DW, GETDATE()) = 2 
									THEN DATEADD(HOUR,-2,DATEADD(DAY,-1, @Date)) 
									ELSE DATEADD(HOUR,-2,DATEADD(DAY, 0, @Date)) END
									,DATEADD(SECOND,-1,DATEADD(HOUR,6,@Date)));
INSERT INTO #TimeSheet VALUES('AB06',DATEADD(HOUR,6,@Date)
									,DATEADD(SECOND,-1,DATEADD(HOUR,14,@Date)));
INSERT INTO #TimeSheet VALUES('AB07',DATEADD(HOUR,14,@Date)
									,DATEADD(SECOND,-1,DATEADD(HOUR,22,@Date)));

--SELECT * from #TimeSheet
BEGIN
with ta as (
	SELECT t1.Shift
		  ,COUNT(1) as Total
		  ,COUNT(case when LastSwipeTime is not null then 1 else null end ) as Attendance
	FROM [T_ETS_EmployeeAttendance] (nolock) t1
	inner join #TimeSheet t2 on t1.[Shift] = t2.Shift and t1.StartTime = t2.StartTime
	where t1.Workshop = @pWorkshop
	group by t1.Shift
)
--select * from ta
select (
	select Shift, Total, Attendance, Total - Attendance as Leave
	from ta
	for json path
) as [Value]
END
--[SP_DN_WorkshopAttendanceThreeShift]
