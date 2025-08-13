
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SP_LL_QCByStyleNo]
 @pWorkline nvarchar(max) = 'KTT1-L1,KTT1-L10,KTT1-L2,KTT1-L3,KTT1-L4,KTT1-L5,KTT1-L6,KTT1-L7,KTT1-L8,KTT1-L9,KTT1-OF',
 @pStyleNO nvarchar(max) = 'FWTR,FWTD',
 @pQcGxNo nvarchar(max) = '150,5200'
 as

DECLARE @QcGxNo TABLE (GxNo nvarchar(15));
insert into @QcGxNo
select * from string_split(@pQcGxNo,',');

DECLARE @Workline TABLE (Workline nvarchar(15));
insert into @Workline
select * from string_split(@pWorkline,',');

DECLARE @StyleNo TABLE (StyleNo nvarchar(30));
insert into @StyleNo
select * from string_split(@pStyleNO,',');


with t1 as(
select BillDate,CardCode,ReturnWorkCode,ReturnWorkCount,ReturnWorkName,Workline,cCount,StyleNo
	-- Kiểm tra thứ tự kiểm
	,Count(ReturnWorkCount) Over (Partition by CardCode Order by CardCode,Billdate Rows between UNBOUNDED PRECEDING and 1 PRECEDING) as CheckOrder 
from T_ETS_QC (nolock) ta 
where 1 = 1 
and Workline collate database_default in (select * from  @Workline)
and BillDate >= convert(date,GetDate())
and QCGxNo in( select * from @QcGxNo)
)
-- lấy số lượng hàng của thẻ = số lượng kiểm cho lần kiểm đầu 
select case when CheckOrder = 0 then Ccount+ReturnWorkCount else ReturnWorkCount end as Totalcheck
,*
into #QC
from t1;


with t1 as (
select SUBSTRING(StyleNo,6,3) StyleNo,Sum(TotalCheck) as TotalCheck, Sum(ReturnWorkCount) as TotalError 
		,cast(Round(Sum(ReturnWorkCount)/cast(Sum(TotalCheck) as decimal(18,2))*100,2) as decimal(18,2)) as Rate
from  #QC 
group by SUBSTRING(StyleNo,6,3)
)
select (
select StyleNo
	,isnull(TotalCheck,0) as  TotalCheck
	,isnull(TotalError,0) as  TotalError
	,isnull(Rate,0) as  Rate
from t1
	for json path , include_null_values
) as [Value]




