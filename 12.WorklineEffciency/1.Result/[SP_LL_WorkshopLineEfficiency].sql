
/****** Object:  StoredProcedure [dbo].[SP_LL_WorkshopLineEfficiency]    Script Date: 10/1/2021 4:50:02 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/
ALTER PROCEDURE [dbo].[SP_LL_WorkshopLineEfficiency]
 @pWorkline nvarchar(max) = 'A1-L2,A1-L3,A1-L4,A1-L5,',
 @pGxNo nvarchar(max) = '700'
as

DECLARE @Workline TABLE (Workline nvarchar(15));
insert into @Workline
select * from string_split(@pWorkline,',');

DECLARE @GxNo TABLE (GxNo nvarchar(10));
insert into @GxNo
select * from string_split(@pGxNo,',');


with t1 as(
SELECT  Upper([WorkLine]) as [WorkLine]
	,SUM([TotalQty]) as [TotalQty]
  FROM T_ETS_EmployeeEfficiency
  where UpdateTime > convert(date,GetDate())
  and WorkLine collate database_Default in (select * from @Workline)
  and GxNo in (select * from @GxNo)
  group by [WorkLine]
),
t2 as(
	select Workline,AimQty,SUM(HourAimQty) as TargetQty 
	from T_ETS_WorklineTarget
	where UpdateTime >  convert(date,GetDate())
    and WorkLine collate database_Default in (select * from @Workline)
	and AimQty > 0
		and EndTime < convert(time,GetDate())
	group by Workline,AimQty

),
t3 as(
	select IdLine as WorkLine, EfficiencyTarget/100 as EfficiencyTarget
	from Workline_KanbanConfig
	where 1 = 1
	and IdLine collate database_Default in (select * from @Workline)
),
t4 as(
	select t2.Workline,Floor(TargetQty/EfficiencyTarget) as Target100
	from t2 
	inner join t3 on t3.WorkLine = t2.Workline collate database_default
),
t5 as(
select  t4.Workline,isnull(t1.TotalQty,0)/t4.Target100 as Rate
from t4
left join t1 on t4.Workline = t1.Workline
),
t6 as(
	--select 'ZZZZZTotal' as Workline,cast(Round(SUM(isnull(t1.TotalQty,0))/Sum(t4.Target100),4) as decimal(18,4)) as Rate 
	--from t4 
	--left join t1 on t4.Workline = t1.WorkLine
	select 'ZZZZZTotal' as Workline, AVG(Rate) as Rate 
	from t5
),
t7 as(
select * from t6
union all
select * from t5
)
select Workline,cast(Round(Rate ,4) as decimal(18,4)) as Rate, 'Efficiency' as [Param]
into #TempDAta
from t7
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