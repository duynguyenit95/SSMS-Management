USE [ROS]
GO
/****** Object:  StoredProcedure [dbo].[LL_SP_WorkShop_Output_Hour]    Script Date: 11/10/2021 3:11:27 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_LL_RM004]
 @Factory nvarchar(max) = '',
 @pDepartment nvarchar(max) = '',
 @pWorkShop nvarchar(max) = '',
 @StyleNo nvarchar(max) = '',
 @SaveLog bit = 0
AS 

DECLARE @Date date = Convert(date,GetDate());


DECLARE @Workshop table(workshop nvarchar(10));
DECLARE @Department table(dept nvarchar(10));


insert into @Workshop
select * from string_split(@pWorkShop,',')

insert into @Department
select * from string_split(@pDepartment,',')

-- Workshop Line Target 
select tb.Fac_no as Factory,tb.Dep_no as Dept,tb.Wrk_no as Workshop,Workline,AimQty,Floor(AimQty/TotalWorkTime) as HourAimQty
into #Target
from T_ETS_WorklineTarget (nolock) ta 
inner join HR_Org(nolock) tb on ta.Workline = tb.Lin_no collate database_default
where UpdateTime >= @Date
and (tb.Fac_no = @Factory OR @Factory = '')
and (Dep_no in (select * from @Department) OR @pDepartment = '')
and (Wrk_no in (select * from @Workshop) OR @pWorkShop = '')
group by tb.Fac_no,tb.Dep_no,tb.Wrk_no,Workline,AimQty,Floor(AimQty/TotalWorkTime);

--select * from #Target;

select tb.Fac_no as Factory,tb.Dep_no as Dept,tb.Wrk_no as Workshop,ta.*
into #OutputData
from WorkLineSummary (nolock) ta
inner join HR_Org(nolock) tb on ta.Workline = tb.Lin_no collate database_default
where WorkDate = @Date
and GxNo in (698,700)
and (tb.Fac_no = @Factory OR @Factory = '')
and (Dep_no in (select * from @Department) OR @pDepartment = '')
and (Wrk_no in (select * from @Workshop) OR @pWorkShop = '')
and (ta.StyleNo like N'%'+@StyleNo+'%'  OR @StyleNo = '')
;

--select * 
--from #OutputData;

select Workline,Count(LastSwipeTime) as TotalWorker
into #Worker
from T_ETS_EmployeeAttendance(nolock) 
where 1 = 1 
and Shift_date = @Date
and (Factory = @Factory OR @Factory = '')
and (Dept in (select * from @Department) OR @pDepartment = '')
and (Workshop in (select * from @Workshop) OR @pWorkShop = '')
group by Workline
;



with t1 as(
select Upper(WorkLine) WorkLine,Zdcode,TimeString as TimeString,GxNo,SUM(TotalQty) as OutputQuantity 
from #OutputData
group by Upper(WorkLine),StyleNo,Zdcode,TimeString,GxNo
)
select * 
into #OutputByHour
from t1

select distinct Zdcode 
into #ZdcodeBases
from #OutputData

select ta.Zdcode,isnull(tb.ClosestExportDate,tc.ExportDate) as ExportDate,isnull(tb.StyleNo,tc.STYLE_NO) as StyleNo
into #ZdcodeInfors
from #ZdcodeBases ta
left join BigSOInfor(nolock) tb on ta.Zdcode = tb.MO collate database_Default
left join (
select ZDCODE,STYLE_NO,ExportDate 
from T_ETS_MOInProduction(nolock)
where ZDCODE in (select  * from #ZdcodeBases)
group by ZDCODE,STYLE_NO,ExportDate
) tc on ta.Zdcode = tc.ZDCODE 
;


with t1 as(
select ta.*,tb.Zdcode,tb.TimeString,tb.GxNo,tb.OutputQuantity
from #Target ta 
left join #OutputByHour tb on ta.Workline = tb.WorkLine
)
select t1.*,tc.ExportDate,tc.StyleNo,td.TotalWorker 
into #Result
from t1
left join #ZdcodeInfors tc on tc.Zdcode = t1.Zdcode
left join #Worker td on td.Workline = t1.Workline collate database_Default
where t1.Zdcode is not null
order by t1.Workline


IF(@SaveLog = 1)
BEGIN
	insert into RM004Data
	select *,@Date as WorkDate,GETDATE() as UpdateTime
	from #Result
END
ELSE 
BEGIN
select * 
from #Result
for json path,include_null_values
END

