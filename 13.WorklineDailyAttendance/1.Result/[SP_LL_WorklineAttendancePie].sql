-- CREATED in 172.19.18.86 [ROS]

/****** Object:  StoredProcedure [dbo].[UpdateWorklineSummary]    Script Date: 10/1/2021 3:51:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Alter PROCEDURE [dbo].[SP_LL_WorklineAttendancePie]
 @pWorkline nvarchar(max) = 'A1-L2,A1-L3,A1-L4,A1-L5,'
as

DECLARE @Workline TABLE (Workline nvarchar(15));
insert into @Workline
select * from string_split(@pWorkline,',');


with t1 as(
SELECT  Count(1) as Total
	,Count(case when LastSwipeTime is not null then 1 else null end ) as Attended
  FROM [T_ETS_EmployeeAttendance] (nolock)
  where [Shift_date] = convert(date,GetDate())
  and WorkLine collate database_Default in (select * from @Workline)
  and Workline not like N'%OF%'
  and Pos_id like N'W%'
  and convert(date,StartTime) = convert(date,EndTime)
  and convert(time,EndTime) < convert(time, '20:00:00')
  and StartTime <= GETDATE()
),
t2 as(
	select cast(Attended as decimal(18,2))  as [Value], N'Số người đi làm thực tế 实际出勤人数' as [Param]
	from t1
),
t3 as(
	select cast(Total-Attended  as decimal(18,2)) as [Value], N'Số người không đi làm 缺勤人数' as [Param]
	from t1
),
t4 as(
select * from t2 
union all 
select * from t3
)
select * from t4
