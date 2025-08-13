USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_WorklineOutputThreeShift]    Script Date: 4/19/2023 8:01:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Created in 172.19.18.86.dbo.ROS

ALTER PROCEDURE [dbo].[SP_DN_WorklineOutputThreeShift]
	@pWorkline nvarchar(1000) = 'IJT-D02,IJT-D03',
	@pGxNo varchar(max) = '1140'
AS

DECLARE @GxNo TABLE (GxNo nvarchar(10));
insert into @GxNo
select * from string_split(@pGxNo,',');

DECLARE @Workline TABLE (Workline varchar(10));
insert into @Workline
select * from string_split(@pWorkline,',');

DROP TABLE IF EXISTS #TimeSheet
CREATE TABLE #TimeSheet (
	[Content] nvarchar(100),
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
INSERT INTO #TimeSheet VALUES(N'CA 3<br>(CA ĐÊM)','AB08',CASE WHEN DATEPART(DW, GETDATE()) = 2 
									THEN DATEADD(HOUR,-2,DATEADD(DAY,-1, @Date)) 
									ELSE DATEADD(HOUR,-2,DATEADD(DAY, 0, @Date)) END
									,DATEADD(SECOND,-1,DATEADD(HOUR,6,@Date)));
INSERT INTO #TimeSheet VALUES(N'CA 1<br>(CA SÁNG)','AB06',DATEADD(HOUR,6,@Date)
									,DATEADD(SECOND,-1,DATEADD(HOUR,14,@Date)));
INSERT INTO #TimeSheet VALUES(N'CA 2<br>(CA CHIỀU)','AB07',DATEADD(HOUR,14,@Date)
									,DATEADD(SECOND,-1,DATEADD(HOUR,22,@Date)));

--SELECT * from #TimeSheet
BEGIN
with ta as (
	SELECT t1.WorkLine, t2.[Shift], SUM(t1.Qty) TotalQty, SUM(t1.SAM) TotalSAM
	FROM WorkLineSummaryTimeSheet (nolock) t1
	inner join #TimeSheet t2 on t1.EndTime between t2.StartTime and t2.EndTime
	where t1.WorkLine collate database_default in (select * from @Workline)
	and t1.Gx_No in (select * from @GxNo)
	group by t1.WorkLine, t2.[Shift]
)
,tb as (
	SELECT t1.Workline, t2.Content, t1.Shift, Sum(TotalWorkTime) as TotalWorkTime
	FROM [T_ETS_EmployeeAttendance] (nolock) t1
	inner join #TimeSheet t2 on t1.[Shift] = t2.Shift and t1.StartTime = t2.StartTime
	where t1.Workline in (select * from @Workline)
	and LastSwipeTime is not null
	group by t1.Workline, t2.Content, t1.Shift
)
,tc as (
	select tb.*
		  ,ISNULL(ta.TotalQty,0) TotalQty
		  ,ISNULL(ta.TotalSAM,0) TotalSAM
		  ,case when tb.WorkLine = 'IJT-D02' then N'A栋一楼 A1F'
				when tb.WorkLine = 'IJT-D03' then N'C栋一楼 C1F'
				else '' end as DisplayName
	from tb
	left join ta on tb.Workline = ta.WorkLine collate database_default and tb.Shift = ta.Shift 
)
select (
	select *
	from tc
	for json path
) as [Value]
END
--[SP_DN_WorklineOutputThreeShift]
