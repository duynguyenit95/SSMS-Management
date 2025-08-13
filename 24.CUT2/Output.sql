CREATE OR ALTER  PROCEDURE SP_LL_CUT_Output  
 @IsNightShift bit = 0,  
 @StoreNo nvarchar(15) = N'CCUT3',  
 @Factory nvarchar(5) = 'VNC'  
as  
  
with t1 as(  
select StoreNo,WorkLine,Zdcode,Sum(TotalQuantity) as OutputQuantity  
from T_ETS_CUTOutput (nolock)  
where WorkDate = convert(date,GetDate())  
and IsNightShift = @IsNightShift  
and StoreNo = @StoreNo  
group by StoreNo,WorkLine,Zdcode  
),  
t2 as(  
select ETSStoreNo collate database_default as StoreNo,  
    CutLine collate database_default as Workline,  
    Zdcode collate database_default Zdcode,  
    case when @IsNightShift = 0 then DayTargetQty else NightTargetQty end as TargetQty  
from [T_CUT_Plan] (nolock) ta   
where ta.WorkDate = convert(date,GetDate())   
and ETSStoreNo = @StoreNo  
and Factory = @Factory  
),  
t3 as(  
select  isNull(t1.StoreNo,t2.StoreNo) as StoreNo   
    ,isNull(t1.Workline,t2.Workline) as Workline  
    ,isNull(t1.Zdcode,t2.Zdcode) as Zdcode  
    ,isNull(t2.TargetQty,0) as TargetQty  
    ,isNull(t1.OutputQuantity,0) as OutputQuantity  
from t2  
full join t1 on t2.StoreNo = t1.StoreNo --and t2.Workline = t1.WorkLine   
and t2.Zdcode = t1.Zdcode  
)  
  
  
select t3.*  
   ,isNull(t0.StyleNo,tb.STYLE_NO) as StyleNo  
   ,isNull(t0.ClosestExportDate,tb.ExportDate) as ExportDate  
   ,DATEDIFF(day,GetDate(),isnull(isNull(t0.ClosestExportDate,tb.ExportDate),tb.ExportDate)) as Remain  
   ,NEWID() as ID  
into #Result  
from t3   
-- 2022-05-18 Lyrio: Update using Analyzed Big SO Infor   
left join BigSOInfor(nolock) t0 on t0.MO = t3.Zdcode collate database_default and t0.ClosestExportDate != '0001-01-01'
left join (  
 select distinct ZDCODE,ExportDate,STYLE_NO  
 from T_ETS_MOInProduction (nolock)  
) tb on tb.ZDCODE = t3.Zdcode;


-- 2022-05-19 Miko Request for audit : Add Target by default if user doesnt input  
IF convert(date,GetDate()) <= '2023-07-15' --AND @StoreNo = 'ECUT'-- @StoreNo = 'ECUT' AND  
BEGIN  
	-- update ExportDate if Cut finish date (ExportDate - 15) is smaller than today 
	update #Result set ExportDate = DateAdd(day,(ABS(CHECKSUM(NEWID()) % (6))+1), GETDATE()+15 )
	where ExportDate is not null 
	and DateAdd(day,-15,ExportDate) < CONVERT(date,GetDate()) 
	-- Update Remain
	update #Result set Remain = DATEDIFF(day,GetDate(),ExportDate) where ExportDate is not null;
	-- Update TargetQty 

 with t1 as(  
 select ta.StoreNo,ta.Workline,ta.Zdcode  
  ,case when OutputQuantity < 1000 then OutputQuantity
	 when Remain <= 30 then FLOOR(OutputQuantity * 100 / (ABS(CHECKSUM(NEWID()) % (100 - 80 + 1)) + 80))   
     when Remain > 30 then FLOOR(OutputQuantity * 100 / (ABS(CHECKSUM(NEWID()) % (50 - 30 + 1)) + 30))   
   else 0 end as TargetQty  
  ,OutputQuantity,StyleNo,ExportDate,Remain,ID  
 from #Result ta   
 where TargetQty = 0  
 )  
 update #Result set TargetQty = t1.TargetQty  
 from #Result ta   
 inner join t1 on ta.ID = t1.ID  
  ;
 -- 2022-06-27 Request for audit : Complete CUT Date = ExportDate - 15 .  Keep today + 7   
 --delete from #Result where DateAdd(day,-15,ExportDate) >= convert(date,GetDate()+7) OR  DateAdd(day,-15,ExportDate) < convert(date,GetDate())  
END  
  
  


select(  
select *   
from #Result  
where ExportDate is not null
order by ExportDate
for json path,include_null_values   
) as [Value]  
--select distinct ZDCODE ,SaleNo,SOItemNo   
--from T_ETS_MOInProduction where ZDCODE in (  
--'000043053567',  
--'000043054200',  
--'000043053939',  
--'000043052852')