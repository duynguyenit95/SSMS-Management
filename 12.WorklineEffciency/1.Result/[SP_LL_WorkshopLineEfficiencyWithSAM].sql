
/****** Object:  StoredProcedure [dbo].[SP_LL_WorkshopLineEfficiency]    Script Date: 10/1/2021 4:50:02 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/
ALTER PROCEDURE [dbo].[SP_LL_WorkshopLineEfficiencyWithSAM]
 @pWorkline nvarchar(max) = 'D5-L1,D5-L2,D5-L3,D5-L4,D5-L5,D5-L6,D5-L7,D5-L8',
 @pViewOffLine bit = 1
as

DECLARE @Workline TABLE (MainWorkline nvarchar(10),Workline nvarchar(15));
insert into @Workline
select value as MainWorkline,value as Workline
from string_split(@pWorkline,',');


insert into @Workline
select ta.value Workline, tb.FakeLine 
from string_split(@pWorkline,',') ta
inner join KTV_FakeLine tb on ta.value = tb.Line;


with t1 as(
	-- get total SAM
	SELECT MainWorkline, SUM([TotalSam]) as [TotalSam]
	FROM T_ETS_EmployeeEfficiency (nolock) ta
	inner join @Workline tb on ta.WorkLine = tb.Workline collate database_default
	where UpdateTime > convert(date,GetDate())
	group by MainWorkline
),
t2 as(
	-- get total work time
	SELECT Workline, SUM([TotalWorkTime]) as [TotalWorkTime]
	FROM T_ETS_EmployeeAttendance(nolock) 
	WHERE Shift_date = convert(date, GetDate())
	AND Workline in (select distinct MainWorkline from @Workline)
	AND LastSwipeTime is not null
	group by Workline
),
t3 as (
	select t2.Workline, 
	case when t2.TotalWorkTime > 0 
		 then ISNULL(t1.TotalSam,0) / t2.TotalWorkTime 
		 else 0 
	end	as Rate
	from t2 left join t1 on t1.MainWorkline = t2.Workline
),

t4 as (
	select 'ZZZZZTotal' as Workline, AVG(Rate) as Rate 
	from t3
),
t5 as (
	select * from t3
	union all
	select * from t4
)
select Workline,cast(Round(Rate ,4) as decimal(18,4)) as Rate, 'Efficiency' as [Param]
into #TempData
from t5
where t5.Rate > case when @pViewOffLine = 1 then -1 else 0 end
order by len(Workline),Workline
DECLARE @SQLQuery NVARCHAR(max);
DECLARE @ColList  NVARCHAR(max) ;

SELECT @ColList = STUFF(
             (SELECT ',[' + Workline + ']'
              FROM  (select distinct Workline from #TempData) ta
			  Order by Workline
              FOR XML PATH (''))
             , 1, 1, '')


			SELECT @SQLQuery  = 'SELECT (
			SELECT *
			from #TempData
			pivot
			(
			  max(Rate)
			  for Workline in ('+@ColList+')
			) piv  FOR JSON PATH ,INCLUDE_NULL_VALUES ) AS Value' ;

			/*PRINT(@SQLQuery)*/


	EXEC(@SQLQuery);