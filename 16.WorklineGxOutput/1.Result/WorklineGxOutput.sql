-- CREATED in 172.19.18.86 [ROS]

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_LL_WorklineGxOutput]
 @pWorkline nvarchar(max) = 'A11-L10'
as

DECLARE @Workline TABLE (Workline nvarchar(15));
insert into @Workline
select * from string_split(@pWorkline,',');

select  (
select GxNo GxCode,Sum(TotalQty) Quantity
from WorkLineSummary (nolock)
where WorkDate = convert(date,Getdate()) 
and Workline collate database_default in (select * from @Workline)
group by GxNo
for json path,include_null_values
) as [Value]


-- [SP_LL_WorklineHourSummary]
