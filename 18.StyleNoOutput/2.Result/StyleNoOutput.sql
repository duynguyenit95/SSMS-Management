
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_LL_OutputByStyleNoGx]
 @pWorkline nvarchar(max) = 'QAKTT1',
 @pStyleNO nvarchar(max) = 'FWTR-150,FWTD-5200,FWTD-150'
 as

DECLARE @Workline TABLE (Workline nvarchar(15));
insert into @Workline
select * from string_split(@pWorkline,',');

DECLARE @StyleNo TABLE (StyleNo nvarchar(30),GxNo int);
insert into @StyleNo
select SUBSTRING([value],1,CHARINDEX('-',[value])-1) as StyleNo,
	   cast(SUBSTRING([value],CHARINDEX('-',[value])+1,Len([Value])) as int) as GxNo
from string_split(@pStyleNO,',');



select *--tb.StyleNo,Sum(TotalQty) as TotalQty
into #Output
from WorkLineSummary (nolock) ta 
--right join @StyleNo tb on ta.StyleNo collate database_default like N'%'+tb.StyleNo+'%' and ta.GxNo = tb.GxNo
where 1 = 1 
and Workline collate database_default in (select * from  @Workline)
and WorkDate = convert(date,GetDate())
and GxNo in (150,5200)
--group by tb.StyleNo


select (
select SUBSTRING(StyleNo,6,3) StyleNo,isnull(Sum(TotalQty),0) as TotalQty 
from  #Output ta --on ta.StyleNo collate database_default like N'%'+tb.StyleNo+'%' and ta.GxNo = tb.GxNo
group by SUBSTRING(StyleNo,6,3)
for json path,include_null_values
) as [Value]
