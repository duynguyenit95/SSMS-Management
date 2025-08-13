  
CREATE OR ALTER PROCEDURE [dbo].[SP_LL_Workline_WFT_QCEndline]   
 @pWorkline nvarchar(20) = 'E1-L2'  
 as  
  
DECLARE @Workline nvarchar(20) = @pWorkline;  
DECLARE @Factory nvarchar(5);  
DECLARE @ReworkTable table(ReturnWorkCode nvarchar(20),[Description] nvarchar(50),StartTime time(7),TotalRework int)  
  
-- Get Workline Factory  
SELECT @Factory = (select Fac_no from HR_Org where Lin_no = @Workline);  
  
drop table if exists #TempWorkhour;  
--- Line Working Hour  
select *  
into #TempWorkhour  
from T_ETS_WorklineTarget (nolock)  
where 1 =1  
and UpdateTime > convert(date,GetDate())  
and Workline = @Workline  
  
  
  
--- ETS Rework Data  
drop table if exists #TempData;  
with t1 as(  
select isnull(TimeStop,TimeStart) as BillDate,CardNo as CardCode  
   ,tb.RootId as ReturnWorkCode  
   ,tb.ErrCount as ReturnWorkCount  
   ,cast('' as nvarchar(200)) as ReturnWorkName  
   ,[LineNo] as Workline  
   ,CCount  
from T_QC_EndLine(nolock) ta   
left join T_QC_EndLineErr(nolock) tb on ta.Id = tb.EndLineId  
where [TimeStart] >= convert(date,GetDate())  
and [LineNo] = @Workline  
)  
select t1.*,tb.StartTime,tb.TimeString  
into #TempData  
from t1  
right join #TempWorkhour tb on 
Convert(time,t1.BillDate) >= tb.StartTime and Convert(time,t1.BillDate) < tb.EndTime  
  
  
  
--- Error Information  
SELECT [Prioritize],Code,EVN,ECN,PVN,PCN,Id  
into #TempReworkData  
FROM QCErrorRoot  
where Factory = case when @Factory = 'VNE' then @Factory else 'VNA' end ;  
  
with   
-- Tính tổng lỗi theo giờ  
t0a as(  
 select  ReturnWorkCode,ReturnWorkName  
   ,TimeString as [Description],StartTime  
   ,Sum(ReturnWorkCount) as TotalRework  
 from #TempData ta   
 group by ReturnWorkCode,ReturnWorkName  
   ,TimeString,StartTime  
),  
-- Tổng kiểm theo giờ   
t2 as(  
 select [Description], Sum(CCount) as TotalQuantity  
 from   
 (  
  select TimeString [Description],CardCode,CCount  
  from #TempData   
  group by [TimeString],CardCode,CCount  
 ) ta  
 group by [Description]  
),  
-- Join Dữ liệu  
t3 as(  
 select t0a.*,t2.TotalQuantity  
 from t0a   
 inner join t2 on t0a.[Description] = t2.[Description]  
),  
-- Lấy thêm dữ liệu liệu từ hệ thống QC  
t4 as(  
 select ta.Code as ReturnWorkCode, ta.ECN + ta.EVN as ReturnWorkName,Description,StartTime,TotalRework,TotalQuantity,ta.*  
 from t3   
 left join #TempReworkData ta on t3.ReturnWorkCode = ta.Id  
  
)  
select (  
 select *,t4.[Description] as IdTimeWork  
 from t4  
 order by t4.[Description]  
 for json path , include_null_values  
) as [Value]  
  