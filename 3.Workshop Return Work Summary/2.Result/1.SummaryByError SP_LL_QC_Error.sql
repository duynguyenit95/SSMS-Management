-- Created in ROS ORP Database 172.19.18.86 - ROS 
CREATE OR ALter PROCEDURE [dbo].[SP_LL_QC_Error] 
 @pWorkline nvarchar(max) = 'UPP1-L1',
 @pGxNo nvarchar(max) = '5300',
 @useQCServer bit = 0,
 @pTop int = 0
as

DECLARE @Workline TABLE (Workline nvarchar(15));
insert into @Workline
select * from string_split(@pWorkline,',');

DECLARE @GxNo TABLE (GxNo nvarchar(10));
insert into @GxNo
select * from string_split(@pGxNo,',');

select cast(N'' as nvarchar(1000)) as [Param], cast(0 as decimal(18,2)) as [Value]
into #Result;

truncate table #Result;

if(@useQCServer = 0)
with t1 as(
	select ReturnWorkCode + '-' + ReturnWorkName as [Param],Sum(ReturnWorkCount) as TotalError
	from T_ETS_QC (nolock) 
	where BillDate > convert(date,GetDate())
	and ReturnWorkCode > 0
	and QCGxNo in (select * from @GxNo)
	and Workline collate database_Default in (select * from @Workline)
	group by ReturnWorkCode,ReturnWorkName
)
insert into #Result
select [Param],cast(TotalError as decimal(18,2)) as [Value]
from t1 


else 
with t1 as(
	select tc.Code + '-' + tc.ECN + '-' + tc.EVN as [Param],Sum(tb.ErrCount) as TotalError
	from T_QC_EndLine(nolock) ta 
	inner join T_QC_EndLineErr(nolock) tb on ta.Id = tb.EndLineId
	inner join QCErrorRoot(nolock) tc on tc.Id = tb.RootId
	where [TimeStart] >= convert(date,GetDate())
	and [LineNo] collate database_default in (select * from @Workline)
	group by tc.Code,tc.ECN,tc.EVN
)
insert into #Result
select [Param],cast(TotalError as decimal(18,2)) as [Value]
from t1 

if(@pTop > 0)
select TOP (@pTop)  *
from #Result
Order by [Value] desc
else 
select *
from #Result
Order by [Value] desc



