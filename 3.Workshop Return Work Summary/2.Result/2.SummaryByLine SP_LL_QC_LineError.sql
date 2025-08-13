-- Created in ROS ORP Database 172.19.18.86 - ROS 
CREATE OR ALter PROCEDURE [dbo].[SP_LL_QC_LineError] 
 @pWorkline nvarchar(max) = 'E1-L2,E1-L1',
 @pGxNo nvarchar(max) = '700',
 @useQCServer bit = 0
as

DECLARE @Workline TABLE (Workline nvarchar(15));
insert into @Workline
select * from string_split(@pWorkline,',');


DECLARE @GxNo TABLE (GxNo nvarchar(10));
insert into @GxNo
select * from string_split(@pGxNo,',');

if(@useQCServer = 0)
	with t1 as(
		select Workline,Sum(ReturnWorkCount) as TotalError
		from T_ETS_QC (nolock) 
		where BillDate > convert(date,GetDate())
		and ReturnWorkCode > 0
		and QCGxNo in (select * from @GxNo)
		and Workline collate database_Default in (select * from @Workline)
		group by Workline
	)
	select Workline as [Param],cast(TotalError as decimal(18,2)) as [Value]
	from t1 
	Order by [Value] desc

else 
	with t1 as(
		select [LineNo] as [Param],Sum(tb.ErrCount) as TotalError
		from T_QC_EndLine(nolock) ta 
		inner join T_QC_EndLineErr(nolock) tb on ta.Id = tb.EndLineId
		where [TimeStart] >= convert(date,GetDate())
		and [LineNo] collate database_default in (select * from @Workline)
		group by [LineNo]
	)
	select [Param],cast(TotalError as decimal(18,2)) as [Value]
	from t1 
	Order by [Value] desc


