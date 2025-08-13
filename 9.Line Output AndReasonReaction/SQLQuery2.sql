
DECLARE @pWorkline nvarchar(20) = 'A1-L1';
DECLARE @pOutputGxNo nvarchar(1000) = '698';
DECLARE @pOutputQcGxNo nvarchar(1000) = '700';
DECLARE @pSamGxNo nvarchar(1000) = '700';
DECLARE @pGxName nvarchar(2000) = '';
DECLARE @pETSServer nvarchar(10) = '';


------------ Config Paramater

-- Main Workline List
DECLARE @Workline TABLE (MainWorkline nvarchar(10),Workline nvarchar(15));
insert into @Workline
select value as MainWorkline,value as Workline
from string_split(@pWorkline,',');

-- Insert Fake line if have
insert into @Workline
select ta.value Workline, tb.FakeLine 
from string_split(@pWorkline,',') ta
inner join KTV_FakeLine tb on ta.value = tb.Line;

DECLARE @OutputGxNo TABLE (GxNo int);
insert into @OutputGxNo
select cast([value] as int) as GxNo from string_split(@pOutputGxNo,',');

DECLARE @OutputQcGxNo TABLE (GxNo int);
insert into @OutputQcGxNo
select cast([value] as int) as GxNo from string_split(@pOutputQcGxNo,',');

DECLARE @OutputGxName TABLE (Gxname nvarchar(200));
insert into @OutputGxName
select [value] as  Gxname from string_split(@pGxName,',');


DECLARE @SamGxNo TABLE (GxNo int);
insert into @SamGxNo
select cast([value] as int) as GxNo from string_split(@pSamGxNo,',');

drop table if exists #TGxNos;
select *
into #TGxNos
from (
select * from @OutputGxNo
union 
select * from @OutputQcGxNo
union 
select * from @SamGxNo
) ta 
------------ End Config Paramater


------------ Target 

--- Workline Target
drop table if exists #Target;
select *
into #Target
from T_ETS_WorklineTarget(nolock)
where UpdateTime >= convert(date,GetDate())
and Workline collate database_default in (select distinct MainWorkline from @Workline)


--- Workline Attendant
drop table if exists #EmpAtt;
select Workline, COUNT(LastSwipeTime) EmpCount, Sum(TotalWorkTime) as TotalWorkTimeInMinutes
into #EmpAtt
from T_ETS_EmployeeAttendance(nolock) 
where WorkLine collate database_default in (select distinct MainWorkline from @Workline)
and Shift_date = convert(date, GetDate())
and LastSwipeTime is not null
group by Workline;
;

drop table if exists #TargetWorkTime;
DECLARE @currentTime time = Convert(time,GetDate());
with 
t0 as (
	select ta.*,tb.EmpCount, case when ta.EndTime < @currentTime then ta.AccumulatedMinutes * tb.EmpCount
					  else tb.TotalWorkTimeInMinutes end as TotalWorkTimeInMinutes
	from #Target ta
	left join #EmpAtt tb on ta.Workline = tb.Workline collate database_default
)
select * 
into #TargetWorkTime
from t0

------------ End Target 

-- Total Sam by Gx
drop table if exists #TotalSAMbyGx;
select tc.MainWorkline as WorkLine,TimeString,Sum(TotalSam) as TotalSamByGx
into #TotalSAMbyGx
FROM WorkLineSummary (nolock) ta  
inner join @Workline tc on tc.Workline = ta.WorkLine collate database_default
where 1 = 1 
and WorkDate = convert(date,GetDate())
group by tc.MainWorkline,TimeString
;

--- Workline Output Data
--
drop table if exists #WorklineOutput;
select tc.MainWorkline as Workline
	,TimeString
	,StyleNo
	,GxNo
	,Sum(TotalQty) as TotalQty
	,Case when GxNo in (select * from @OutputGxNo) then 'GxNo'  
		  when GxNo in (select * from @OutputQcGxNo) then 'QcGxNo'
		  else '' end as GxType
	,NEWID() as ID
into #WorklineOutput
FROM WorkLineSummary (nolock) ta
-- Get all Workline output while group by MainWorkline to get main Workline real output
inner join @Workline tc on tc.Workline = ta.WorkLine collate database_default
where 1 = 1
and WorkDate = convert(date,GetDate())
and GxNo in (select * from #TGxNos)
group by tc.MainWorkline,TimeString,GxNo,StyleNo;
--- End Workline Output Data
;

-- Total Sam by style
drop table if exists #StyleTotalCmSam;
with t1 as(
select *,
	(select top 1 CMTotalSam 
		from T_ETS_StyleGx (nolock) where StyleNo = ta.StyleNo collate database_default) as CMTotalSam
from #WorklineOutput ta
where GxNo in(select * from @SamGxNo)
)
select Workline,TimeString,Sum(TotalQty * CMTotalSam) as TotalStyleCMSam
into #StyleTotalCmSam
from t1  
group by Workline,TimeString
;


if @pGxName != ''
Begin
	-- delete records that don't meet gxName condition
	with t1 as(
		select ta.ID 
		from #WorklineOutput ta 
		inner join T_ETS_StyleGx (nolock) tb on ta.StyleNo = tb.StyleNo collate database_default and ta.GxNo = tb.GxNO
		inner join @OutputGxName tc on tb.gxName collate database_default not like N'%'+tc.GxName+'%' 
		where (tb.ETSServer = @pETSServer OR @pETSServer = '')
		and ta.GxType = 'GxNo'
	)
	delete from #WorklineOutput where ID in (select * from t1)
end


;
with t2 as(
select [TimeString]
	,Sum(Case when GxType = 'GxNo' then TotalQty else 0 end) as GxNo
	,Sum(Case when GxType = 'QcGxNo' then TotalQty else 0 end) as QcGxNo
from #WorklineOutput
group by [TimeString]
)
select ta.Workline
	,ta.TimeString as TimeWork
	,ta.AimQty
	,ta.HourAimQty as TotalTarget
	,ta.EmpCount
	,ta.TotalWorkTimeInMinutes
	,ISNULL(t2.GxNo,0) as TotalGxQty
	,ISNULL(t2.QcGxNo,0) as TotalQcGxQty
	,isnull(tb.TotalStyleCMSam,0) as TotalStyleCMSam
	,isnull(td.TotalSamByGx,0) as TotalSamByGx
	,'' as ReasonAndReaction
from #TargetWorkTime ta
left join t2 on ta.TimeString = t2.TimeString collate database_default
left join #StyleTotalCmSam tb on tb.TimeString = ta.TimeString collate database_default
left join #TotalSAMbyGx td on td.TimeString = ta.TimeString collate database_default
for json path 
;