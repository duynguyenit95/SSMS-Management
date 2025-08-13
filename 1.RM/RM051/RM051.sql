-- CREATED IN 172.19.18.81.ETSDB_Regina
CREATE OR ALTER PROCEDURE SP_LL_RM051
 @pStartDate datetime = '2023-01-30',
 @pEndDate datetime = '2023-01-31',
 @pQcGxNo nvarchar(max) = '',
 @pWorkshop nvarchar(10) = 'QAD-B',
 @pWorkline nvarchar(max) = '',
 @pPreQcGxNo nvarchar(max) = '',
 @pPackGxNo nvarchar(max) = ''
as
DECLARE @StartDate datetime = @pStartDate;
DECLARE @EndDate datetime =  @pEndDate;
DECLARE @GxNos Table(GxNo int);
DECLARE @EmpOutputGx Table(GxNo int,GxGroup nvarchar(16));

DECLARE @C_PREQCGX nvarchar(16) = N'PreQcGxNo';
DECLARE @C_PACKGX nvarchar(16) = N'PackGxNo';

insert into @GxNos
select * from tom_splitstring(@pQcGxNo,',');

DECLARE @Worklines Table(Workline nvarchar(10));
insert into @Worklines
select * from tom_splitstring(@pWorkline,',')

insert into @EmpOutputGx
select *,@C_PREQCGX from tom_splitstring(@pPreQcGxNo,',');

insert into @EmpOutputGx
select *,@C_PACKGX from tom_splitstring(@pPackGxNo,',');




drop table if exists #ABCD;
select
	convert(date,ta.BillDate) as WorkDate
   , ta.ZDCode
   , PackNo as STT
   , ColorName
   , CM as Size
   , QCGxNo
   , cCount
   , ReturnWorkCode
   , ReturnWorkCount
   , QcPeople
   , ta.WorkLine
   , ta.BundleId
   , ta.BillDate
into #ABCD
from TbReturnWork(nolock) ta 
where ta.Billdate >= @StartDate and ta.BillDate <= @EndDate
and (QCGxNo in (select * from @GxNos) or @pQcGxNo = '')
and Workshop = @pWorkshop
and (Workline in (select * from @Worklines) or @pWorkline = '')
and ReturnWorkCode is not null


drop table if exists #FinalResult;
select ta.*
   , tb.Name
   ,tc.Style_NO StyleNo
   ,cast(N'' as nvarchar(2048)) as ReturnWorkName
   ,cast(N'' as nvarchar(16)) as QcEmp
   ,cast(N'' as nvarchar(128)) as QcEmpName
   ,cast(N'' as nvarchar(16)) as PackEmp
   ,cast(N'' as nvarchar(128)) as PackEmpName
into #FinalResult
from #ABCD ta
inner join T_YGDA(nolock) tb on ta.QcPeople = tb.Code
inner join T_SCZZD(nolock) tc on tc.Zdcode = ta.Zdcode
where 1 = 1 



update #FinalResult set ReturnWorkName = td.ReturnWorkName 
from #FinalResult ta
inner join tbBsReturnWorkCode(nolock) td on ta.ReturnWorkCode = td.ReturnWorkCode


if(@pPreQcGxNo != '' OR @pPackGxNo != '')
Begin
	drop table if exists #PreQcGxNo;
	select BundleId,Code,Gx_No,EndDate,sid,cast(N'' as nvarchar(16)) as GxGroup
	into #PreQcGxNo
	from T_JJB(nolock)
	where 1 = 1  
	-- Do not filter date because output might not be in filter range
	-- Filter Bundle only 
	and BundleId in (select BundleId from #FinalResult)
	-- Do not filter Gx_No due to no index
	
	-- Clean unused Gx_No
	Delete from #PreQcGxNo where Gx_No not in (select GxNo from @EmpOutputGx)
	-- Update GxGroup
	update #PreQcGxNo set GxGroup = tb.GxGroup
	from #PreQcGxNo ta 
	inner join @EmpOutputGx tb on ta.Gx_No = tb.GxNo
	;
	-- Delete old data in each group if there are more than 1 record. Only get the lastest one based on EndDate
	with t1 as(
	select *,ROW_NUMBER() over (partition by Bundleid,GxGroup order by EndDate desc) as RN
	from #PreQcGxNo
	)
	delete from #PreQcGxNo where sid in (select sid from t1 where RN > 1)

	-- Update PreQc
	update #FinalResult set QcEmp = tb.Code, QcEmpName = tc.NAME
	from #FinalResult ta 
	inner join #PreQcGxNo tb on ta.BundleId = tb.BundleId and GxGroup = @C_PREQCGX
	inner join T_YGDA(nolock) tc on tc.CODE = tb.Code

	-- Update Pack
	update #FinalResult set PackEmp = tb.Code, PackEmpName = tc.NAME
	from #FinalResult ta 
	inner join #PreQcGxNo tb on ta.BundleId = tb.BundleId and GxGroup = @C_PACKGX
	inner join T_YGDA(nolock) tc on tc.CODE = tb.Code
End

select * 
from #FinalResult
order by WorkDate,Workline,QcPeople
for json path,include_null_values