-- Created In 172.19.18.86.ROS 

ALTER PROCEDURE SP_LL_ChartEmpEff
@Workline nvarchar(20) = 'A1-L1'
as
with t1 as(
select EMP_ID,Emp_name,TotalWorkTime
from T_ETS_EmployeeAttendance (nolock)
where Workline = @Workline
and LastSwipeTime is not null
and Shift_date = convert(date,GetDate())
),
t2 as(
select Code,Sum(TotalSam) TotalSam
from T_ETS_EmployeeEfficiency (nolock)
where 1 = 1
and Code  collate database_default in (select EMP_ID from t1)
and Work_date = convert(date,GetDate())
group by Code
)
select t1.*,t2.TotalSam
from t1 
inner join t2 on t1.EMP_ID = t2.Code collate database_default
