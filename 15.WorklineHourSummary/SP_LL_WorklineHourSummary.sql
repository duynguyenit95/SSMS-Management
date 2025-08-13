-- CREATED in 172.19.18.86 [ROS]

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALter PROCEDURE [dbo].[SP_LL_WorklineHourSummary]
 @pWorkline nvarchar(max) = 'UPP1-L4',
 @pQcGxNo nvarchar(max) = '5300',
 @pGxNo nvarchar(max) = '5213,5214',
 @pGxName nvarchar(max) = '',
 @pETServer nvarchar(10) = ''
as

DECLARE @Workline TABLE (Workline nvarchar(15));
insert into @Workline
select * from string_split(@pWorkline,',');

DECLARE @GxNo TABLE (GxNo nvarchar(10));
insert into @GxNo
select * from string_split(@pGxNo,',');

DECLARE @QcGxNo TABLE (GxNo nvarchar(10));
insert into @QcGxNo
select * from string_split(@pQcGxNo,',');


DECLARE @GxName TABLE (GxName nvarchar(200));
insert into @GxName
select * from string_split(@pGxName,'|');


-- Output with all GxNo 
SELECT ta.*
into #AllGxNoBaseData
FROM WorkLineSummary ta 

where WorkDate = convert(date,GetDate())
--and ta.GxNo in (5213,5214)
--and tb.gxName like N'%May la bang-may labang vanh de/de giua%'
--and WorkLine like N'UPP1-L%'
and WorkLine collate database_Default in (select * from @Workline)
--and ta.GxNo in (select * from @GxNo)


-- Output with GxNo
SELECT ta.*
into #BaseData
FROM #AllGxNoBaseData ta 

where WorkDate = convert(date,GetDate())
--and ta.GxNo in (5213,5214)
--and tb.gxName like N'%May la bang-may labang vanh de/de giua%'
--and WorkLine like N'UPP1-L%'
--and WorkLine collate database_Default in (select * from @Workline)
and ta.GxNo in (select * from @GxNo)


select 'TempWorkline' as Workline,'TimeStringString' as TimeString, 0 as TotalOutput 
into #TotalOutput
truncate table #TotalOutput





if(@pGxName != '')
	BEGIN
		-- CheckGxNo 
		select ta.*,tb.gxName collate database_default as gxName 
		into #OutputStyleGx
		from #BaseData ta 
		inner join T_ETS_StyleGx tb on ta.StyleNo = tb.StyleNo collate database_default
									and ta.GxNo = tb.GxNO
		where 1 = 1 
		and (tb.ETSServer = @pETServer OR @pETServer = '')

		-- Filter GxName
		insert into #TotalOutput
		select Workline,TimeString,Sum(TotalQty) as TotalOutput
		from #OutputStyleGx ta 
		inner join @GxName tc on ta.gxName like N'%'+tc.GxName+'%'
		group by [WorkLine],TimeString
	END
ELSE
	BEGIN
		insert into #TotalOutput
		select Workline,TimeString,Sum(TotalQty) as TotalOutput
		from #BaseData
		group by Workline,TimeString
	END;



;
with t1 as (
select *,Round(HourAimQty/(AimQty/TotalWorkTime)*60,0) as WorkingMinutes
from T_ETS_WorklineTarget (nolock) ta 
where UpdateTime > convert(date,GetDate())
and Workline collate database_default in (select * from @Workline)
),
t2 as (
				-- Correct value due to divide issues
select *,case when WorkingMinutes in (29,28,31,30,32) then 30
			  when WorkingMinutes in (58,59,60,61,62) then 60
			  else WorkingMinutes end as CorrectWorkingMinutes
from t1
)
select * 
into #Target
from t2 
;

select * 
into #EmployeeAtt
from T_ETS_EmployeeAttendance(nolock)
where 1 = 1 
and Workline collate database_default in (select * from @Workline)
and LastSwipeTime is not null
and Shift_date = convert(date,GetDate())

;
with
t3 as(
select * from #TotalOutput
),
t4 as(
select Workline,TimeString,Sum(TotalSam) as TotalSam
from #AllGxNoBaseData
group by Workline,TimeString
),
t5 as(
	select t2.Workline,TimeString,Sum(t2.CorrectWorkingMinutes) as TotalWorkTime--,Count(distinct EMP_ID) as Total--ta.*,t2.AimQty,t2.EndTime as EndTime2,t2.StartTime as StartTime2,t2.CorrectWorkingMinutes
	from #EmployeeAtt ta
	inner join #Target t2 on ta.Workline collate database_default = t2.Workline 
	where 1 = 1
	and (convert(time,GETDATE()) >= t2.EndTime OR convert(time,GETDATE()) >= t2.StartTime and convert(time,GETDATE()) < t2.EndTime)
	group by t2.Workline,TimeString
),
t6 as(
select t2.Workline,t2.TimeString
	  ,t2.HourAimQty as [Target]
	  ,t3.TotalOutput as [Output]
	  ,t4.TotalSam as TotalSAM
	  ,t5.TotalWorkTime
from #Target t2 
left join t3 on t2.Workline collate database_default = t3.Workline and t2.TimeString collate database_default = t3.TimeString
left join t4 on t2.Workline collate database_default = t4.Workline and t2.TimeString collate database_default = t4.TimeString
left join t5 on t2.Workline collate database_default = t5.Workline and t2.TimeString collate database_default = t5.TimeString
)
select  (
select t6.*,ta.Wrk_no as Workshop,ta.Dep_no as Department
from t6
inner join HR_Org ta on t6.Workline collate database_default = ta.Lin_no
order by Len(TimeString),TimeString
for json path,include_null_values
) as [Value]


-- [SP_LL_WorklineHourSummary]
