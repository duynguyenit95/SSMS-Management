-- CREATED in 172.19.18.86 [ROS]

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_LL_WorkshopSummary]
 @pWorkline nvarchar(max) = 'E1-L1,E1-L2,E1-L3,E1-L4',
 @pQcGxNo nvarchar(max) = '700',
 @pGxNo nvarchar(max) = '700',
 @pGxName nvarchar(max) = '',
 @pETServer nvarchar(10) = 'HP',
 @useQCServer bit = 0
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



DECLARE @TempReturnWorkAll table (Workline nvarchar(20)
								,CardCode nvarchar(25)
								,ReturnWorkCode int
								,ReturnWorkCount int
								,cCount int
								,TotalCheck int)

if(@useQCServer = 1)
Begin
	insert into @TempReturnWorkAll
	select Workline,CardCode,ReturnWorkCode,ReturnWorkCount,cCount
		  ,case when CheckOrder = 1 then CCount else 0 end as Totalcheck 
	from (
		select isnull(TimeStop,TimeStart) as BillDate,CardNo as CardCode
			  ,tb.RootId as ReturnWorkCode
			  ,tb.ErrCount as ReturnWorkCount
			  ,cast('' as nvarchar(200)) as ReturnWorkName
			  ,[LineNo] as Workline
			  ,CCount
			  ,ROW_NUMBER() Over (Partition by [LineNo],[CardNo] order by [LineNo],[CardNo]) as CheckOrder
		from T_QC_EndLine(nolock) ta 
		left join T_QC_EndLineErr(nolock) tb on ta.Id = tb.EndLineId
		where [TimeStart] >= convert(date,GetDate())
		and [LineNo] collate database_default in (select * from @Workline)
	) ta ;
End
else
begin
	insert into @TempReturnWorkAll
	select Workline,CardCode,ReturnWorkCode,ReturnWorkCount,cCount
		  ,case when CheckOrder = 0 then Ccount+ReturnWorkCount else ReturnWorkCount end as Totalcheck 
	from (
		select *,Count(ReturnWorkCount) Over (Partition by CardCode Order by CardCode,Billdate Rows between UNBOUNDED PRECEDING and 1 PRECEDING) as CheckOrder
		from T_ETS_QC(nolock) 
		where BillDate > Convert(date,GetDate())
		and Workline collate database_default in (select * from @Workline)
		and QCGxNo in (select * from @QcGxNo)
	) ta ;
end;

--Analyze Return Work Error Data
--drop table if exists #TempDataError;
with 
t0 as (
	select * from @TempReturnWorkAll
),
-- Line Error
t1 as(
	select Workline,ReturnWorkCode,Sum(ReturnWorkCount) as ReturnWorkCount
	from t0
	where 1 = 1
	and ReturnWorkCode > 0
	group by Workline,ReturnWorkCode
),
-- Line Total Error
t2 as (
	select Workline,Sum(ReturnWorkCount) as TotalError
	from t1
	group by Workline
),
-- Line top 3 Error .  Use Row number to check top 3 
t3 as(	
		select ta.Workline,ReturnWorkCode
			   ,case when RN = 1 then 'X1stError'
					 when RN = 2 then 'Y2ndError'
					 when RN = 3 then 'Z3rdError'
				end as RN
		from (
				select Workline,ReturnWorkCode,ROW_NUMBER() Over ( partition by Workline order by TotalError desc ) as RN 
				from (
					select Workline,ReturnWorkCode,Sum(ReturnWorkCount) as TotalError
					from t1
					group by Workline,ReturnWorkCode
				)ta 
			) ta 
		where RN < 4
),
-- Workshop Total Error
t4 as(
	select Sum(ReturnWorkCount) as TotalError
	from t1
),
-- Workshop Top 3 Error.  Use Row number to check top 3 
t5 as(
		select ReturnWorkCode
			   ,case when RN = 1 then 'X1stError'
					 when RN = 2 then 'Y2ndError'
					 when RN = 3 then 'Z3rdError'
				end as RN
		from (
				select ReturnWorkCode,ROW_NUMBER() Over ( order by TotalError desc ) as RN 
				from (
					select ReturnWorkCode,Sum(ReturnWorkCount) as TotalError
					from t1
					group by ReturnWorkCode
				)ta 
			) ta 
		where RN < 4
),
-- Union all Data
t7 as(

	Select UPPER(Workline) as Workline, cast(TotalError as decimal(18,2)) as [Value], 'VTotalError' as [Param]
	from t2 
	union all
	select UPPER(Workline) as Workline , cast(ReturnWorkCode as decimal(18,2)) as [Value], RN as [Param]
	from t3
	union all
	select 'ZZZZZTotal' as Workline , cast(isnull(TotalError,0) as decimal(18,2)) as [Value], 'VTotalError' as [Param]
	from t4
	union all
	select 'ZZZZZTotal' as Workline , cast(ReturnWorkCode as decimal(18,2)) as [Value], RN as [Param]
	from t5

)
-- Save Data 
select * 
into #TempDataError
from t7;



--drop table if exists #Temp700;
with
-- Get first record of bundle only > Only Check each bundle one
t1 as(
	select * 
	from @TempReturnWorkAll
),
-- Line Total Check
t2 as(
	select Workline,Sum(TotalCheck) as TotalCheck
	from t1
	group by Workline
),
--- Union Total Check Data
t4 as(
	select Workline,cast(TotalCheck as decimal(18,2)) as [Value], 'UTotalCheck' as [Param]
	from t2
	union all 
	--- Workshop Total Check
	select 'ZZZZZTotal' as Workline,cast(Sum(TotalCheck) as decimal(18,2)) as [Value], 'UTotalCheck' as [Param]
	from t2
),
--- Join TotalError to calculate ErrorRate
t5 as(
	select t4.Workline
	,cast(Round(isnull(ta.[Value],0)/cast(t4.[Value] as decimal(18,2)) * 100,2) as decimal(18,2)) as [Value] 
	,'WErrorRate' as [Param]
	from t4
	left join #TempDataError ta on t4.Workline = ta.Workline and ta.[Param] = 'VTotalError'
),
--- Union all Data 
t6 as(
	select * from t4 
	union all
	select * from t5
	union all
	select * from #TempDataError
)
select Workline collate database_default as Workline
	,[Value]
	,[Param]
into #Temp700
from t6;
--select * from #Temp700 order by Workline;



--drop table if exists #Temp;


select 'TempWorkline' as Workline, 0 as TotalQty 
into #TempOutput
truncate table #TempOutput

if(@pGxName != '')
BEGIN
	-- Check GxNo Name
	SELECT ta.*,tb.gxName collate database_default as gxName
	into #TempOutputStyleGx
	FROM WorkLineSummary ta 
	inner join T_ETS_StyleGx tb on ta.StyleNo = tb.StyleNo collate database_default
								and ta.GxNo = tb.GxNO
	where WorkDate = convert(date,GetDate())
	--and ta.GxNo in (5213,5214)
	--and tb.gxName like N'%May la bang-may labang vanh de/de giua%'
	--and WorkLine like N'UPP1-L%'
	and WorkLine collate database_Default in (select * from @Workline)
	and ta.GxNo in (select * from @GxNo)
	and (tb.ETSServer = @pETServer OR @pETServer = '')

	-- Filter GxName
	insert into #TempOutput
	select Upper([WorkLine]) as [WorkLine]
		,SUM([TotalQty]) as [TotalQty]
	from #TempOutputStyleGx ta 
	inner join @GxName tc on ta.gxName like N'%'+tc.GxName+'%'
	group by [WorkLine]
END
ELSE
BEGIN
insert into #TempOutput
SELECT  Upper([WorkLine]) as [WorkLine]
	,SUM([TotalQty]) as [TotalQty]
  FROM T_ETS_EmployeeEfficiency
  where UpdateTime > convert(date,GetDate())
  and WorkLine collate database_Default in (select * from @Workline)
  and GxNo in (select * from @GxNo)
  group by [WorkLine]
END
;


--Target and Output  
with
-- Base Target 
t0 as(
select Workline collate database_default as Workline,AimQty
from T_ETS_WorklineTarget ta 
where UpdateTime > convert(date,GetDate())
and Workline collate database_default in (select * from @Workline)
group by Workline,AimQty
),
-- Line Target
t1 as(
	select ta.Workline, cast(isnull(AimQty,0) as decimal(18,2)) as [Value] , 'STarget' as [Param]
	from t0 ta
)
--select * from t1
,
-- Workshop Target
t2 as(
	select 'ZZZZZTotal' as Workline, Sum([Value]) as [Value], 'STarget' as [Param]
	from t1
),
-- Line Output 
t3 as (

	select Workline,TotalQty as [Value],'TOutput' as [Param]
	from #TempOutput
	--select ta.WorkLine,Sum(TotalQty) as [Value],'TOutput' as [Param] 
	--from T_ETS_EmployeeEfficiency (nolock) ta 
	--where UpdateTime > convert(date,GetDate())
	--and GxNo in (select * from @GxNo)
	--and Workline collate database_default in (select * from @Workline)
	--group by ta.WorkLine
),
-- Workshop Output 
t4 as(
	select 'ZZZZZTotal' as Workline, Sum([Value]) as [Value], 'TOutput' as [Param]
	from t3 
),
--Union Data
t5 as(
	select * from t1 
	union all 
	select * from t2
	union all
	select * from t3
	union all
	select * from t4
	union all
	select * from #Temp700
)
select (
select *
from t5 Order by Len(Workline),Workline,[Param]
for json path,include_null_values
) as [Value]