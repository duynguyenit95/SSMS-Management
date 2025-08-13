-- Created in 172.19.18.86 - ROS

CREATE OR ALTER PROCEDURE SP_CUTHistory
 @StoreNo nvarchar(15) = N'CCUT',
 @Date date = '2022-05-20',
 @Factory nvarchar(5) = 'VNC'
as 
with t1 as(
select Workdate,StoreNo,IsNightShift,WorkLine,Zdcode
	  ,Sum(TotalQuantity) as OutputQuantity
	  ,Max(EndTime) as EndTime
from T_ETS_CUTOutput (nolock)
where WorkDate = @Date
and StoreNo = @StoreNo
group by Workdate,StoreNo,IsNightShift,WorkLine,Zdcode
),
t2 as(
	select * from (
		select ETSStoreNo collate database_default as StoreNo,
			   CutLine collate database_default as Workline,
			   Zdcode collate database_default Zdcode,
			   WorkDate,
			   cast(1 as bit) as IsNightShift,
			   NightTargetQty as TargetQty,
			   LastUpdatedBy,
			   LastUpdatedTime
		from [T_CUT_Plan] (nolock) ta 
		where ta.WorkDate = @Date
		and ETSStoreNo = @StoreNo
		and Factory = @Factory
		and NightTargetQty > 0
	) ta
	union all
	select * from (
		select ETSStoreNo collate database_default as StoreNo,
			   CutLine collate database_default as Workline,
			   Zdcode collate database_default Zdcode,
			   WorkDate,
			   cast(0 as bit) as IsNightShift,
			   DayTargetQty as TargetQty,
			   LastUpdatedBy,
			   LastUpdatedTime
		from [T_CUT_Plan] (nolock) ta 
		where ta.WorkDate = @Date
		and ETSStoreNo = @StoreNo
		and Factory = @Factory
		and DayTargetQty > 0
	) ta
),
t3 as (
select isnull(t1.WorkDate,t2.Workdate) as Workdate
	  ,isnull(t1.StoreNo,t2.StoreNo) as StoreNo
	  ,isnull(t1.IsNightShift,t2.IsNightShift) as IsNightShift
	  ,isnull(t1.WorkLine,t2.WorkLine) as Workline
	  ,isnull(t1.Zdcode,t2.Zdcode) as Zdcode
	  ,isnull(t1.OutputQuantity,0) as OutputQuantity
	  ,t1.EndTime
	  ,isnull(t2.TargetQty,0) as TargetQty
	  ,t2.LastUpdatedBy
	  ,t2.LastUpdatedTime
from t1
full join t2 on t1.Zdcode = t2.Zdcode and t1.IsNightShift = t2.IsNightShift
)
--select * from t3
select (
select t3.*,ta.StyleNo,ta.ExportDate
from t3
left join T_SAP_SOInProduction(nolock) ta on ta.MO = t3.Zdcode collate database_default
--where t3.Zdcode = '000043070851'
order by Zdcode
for json path,include_null_values
) as [Value]
