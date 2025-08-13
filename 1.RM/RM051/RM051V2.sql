-- CREATED IN 172.19.18.81.ETSDB_Regina
CREATE OR ALTER PROCEDURE SP_LL_RM051V2
 @pStartDate nvarchar(32) = '2023-08-01 05:47:00',
 @pEndDate nvarchar(32) = '2023-08-31 20:47:00',
 @pQcGxNo nvarchar(max) = '',
 @pWorkshop nvarchar(10) = 'QAD-B',
 @pWorkline nvarchar(max) = '', -- QADB-L4A
 @pPreQcGxNo nvarchar(max) = '', --7700,9700,9701,9702,9917
 @pPackGxNo nvarchar(max) = '' --7800,9800
as
DECLARE @StartDate datetime = convert(datetime,@pStartDate);
DECLARE @EndDate datetime =  convert(datetime,@pEndDate);
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
create table #ABCD(
	ID int Identity(1,1) not null,
	WorkDate date,
	ZDCode nvarchar(16),
	STT int,
	ColorName nvarchar(128),
	Size nvarchar(32),
	QCGxNo int,
	cCount int,
	ReturnWorkCode int,
	ReturnWorkCount int,
	QcPeople nvarchar(32),
	Workline nvarchar(32),
	BundleId int
)
insert into #ABCD
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
from TbReturnWork(nolock) ta 
where ta.Billdate >= @StartDate and ta.BillDate <= @EndDate
and (QCGxNo in (select * from @GxNos) or @pQcGxNo = '')
and Workshop = @pWorkshop
and (Workline in (select * from @Worklines) or @pWorkline = '')
and ReturnWorkCode is not null
order by BundleId

drop table if exists #Zdcodes;
select distinct ZDCODE 
into #Zdcodes
from #ABCD



drop table if exists #OrderInfo 
select ZDCODE,STYLE_NO as StyleNo
into #OrderInfo
from T_SCZZD(nolock) 
where ZDCODE in (select ZDCODE collate database_default from #Zdcodes)

drop table if exists #EmpInfo
select CODE,NAME
into #EmpInfo
from T_YGDA(nolock)
where CODE in (select distinct QcPeople collate database_default from #ABCD)

drop table if exists #ReturnCodeInfo;
select ReturnWorkCode,ReturnWorkName
into #ReturnCodeInfo
from tbBsReturnWorkCode (nolock)

drop table if exists #PreQcGxNoEmp;
create table #PreQcGxNoEmp(
	BundleId int,
	GxGroup nvarchar(32),
	Emp nvarchar(32),
)

if(@pPreQcGxNo != '' OR @pPackGxNo != '')
Begin
	drop table if exists #PreQcGxNo;
	select BundleId,Code,Gx_No,EndDate,sid,cast(N'' as nvarchar(16)) as GxGroup
	into #PreQcGxNo
	from T_JJB(nolock)
	where 1 = 1  
	-- Do not filter date because output might not be in filter range
	-- Filter Bundle only 
	and BundleId in (select BundleId from #ABCD)
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

	insert into #PreQcGxNoEmp
	select BundleId,@C_PREQCGX as GxGroup, Code as Emp
	from #PreQcGxNo
	where GxGroup = @C_PREQCGX


	insert into #PreQcGxNoEmp
	select BundleId,@C_PACKGX as GxGroup, Code as Emp
	from #PreQcGxNo
	where GxGroup = @C_PACKGX

	insert into #EmpInfo
	select Code,NAME 
	from T_YGDA(nolock) 
	where CODE in (select distinct Emp collate database_default from #PreQcGxNoEmp)
	and CODE not in (select CODE collate database_default from #EmpInfo)
End

select (
	select * 
	from #ABCD
	where ID < 20000
	for json path,include_null_values
) as [Value]
union all
select (
	select * 
	from #ABCD
	where ID >= 20000 and ID < 40000
	for json path,include_null_values
) as [Value]
union all
select (
	select * 
	from #ABCD
	where ID >= 60000 and ID < 80000
	for json path,include_null_values
) as [Value]
union all
select (
	select * 
	from #ABCD
	where ID >= 80000 and ID < 100000
	for json path,include_null_values
) as [Value]
union all
select (
	select * 
	from #OrderInfo
	for json path,include_null_values
) as [Value]
union all
select (
	select * 
	from #EmpInfo
	for json path,include_null_values
) as [Value]
union all
select (
	select * 
	from #ReturnCodeInfo
	for json path,include_null_values
) as [Value]
union all
select (
	select * 
	from #PreQcGxNoEmp
	order by BundleId
	OFFSET     0 ROWS     
	FETCH NEXT 50000 ROWS ONLY
	for json path,include_null_values
) as [Value]
union all
select (
	select * 
	from #PreQcGxNoEmp
	order by BundleId
	OFFSET     50000 ROWS     
	FETCH NEXT 50000 ROWS ONLY
	for json path,include_null_values
) as [Value]

union all
select (
	select * 
	from #PreQcGxNoEmp
	order by BundleId
	OFFSET     100000 ROWS     
	FETCH NEXT 50000 ROWS ONLY
	for json path,include_null_values
) as [Value]

union all
select (
	select * 
	from #PreQcGxNoEmp
	order by BundleId
	OFFSET     150000 ROWS     
	FETCH NEXT 50000 ROWS ONLY
	for json path,include_null_values
) as [Value]

