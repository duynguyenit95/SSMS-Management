CREATE OR ALTER PROCEDURE SP_C_RM050ETSDataCollector
@pDate date = null
as
DECLARE @Date date = convert(date,isnull(@pDate,GetDate()));
drop table if exists #ABCDEF;
-- Get ETS Summary Output
select WorkLine,Zdcode,GxNo,Sum(TotalQty) as TotalQty,Sum(TotalSam) as TotalSam
into #ABCDEF
from [172.19.18.81].[ETSDB_Regina].dbo.EmployeeEfficencyInfo with (nolock) 
where Work_Date = @Date
group by WorkLine,Zdcode,GxNo

-- Get Workshop line
drop table if exists #GGGG;
select WorkLineName,WorkShop
into #GGGG
from [172.19.18.81].[ETSDB_Regina].dbo.TWorkLine with (nolock) 
where WorkShop in ('CCUT','CCUT3')
and IsUse = 1




delete from RM050_ETSData where WorkDate = @Date;

-- insert
insert into RM050_ETSData
select @Date as WorkDate,ta.Workshop,tb.*,GetDate() as UpdateTime
from #GGGG ta
inner join #ABCDEF tb on ta.WorkLineName = tb.WorkLine


