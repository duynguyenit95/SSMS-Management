-- Created in ROS ORP Database 172.19.18.86 - ROS 
/****** Object:  StoredProcedure [dbo].[SP_LL_WorkshopOffWorkGrid]    Script Date: 9/13/2021 10:57:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_LL_WorkshopOffWorkGrid]
@Workshop nvarchar(20) = 'C18'
as
DECLARE @ColList nvarchar(max) ;
DECLARE @SQLQuery nvarchar(max) ;

select OffStdName,WorkLine,[Value]
into #TempBaseData
from T_ETS_OffWork(nolock) 
where UpdateTime > convert(date,GetDate())
and WorkShop = @Workshop
Order by OffStdName,Len(WorkLine),WorkLine

IF EXISTS(SELECT TOP 1 1 FROM #TempBaseData)
BEGIN
select @ColList = STUFF((
				select ',[' + Workline + ']' 
				from (            
					SELECT distinct Workline
					FROM #TempBaseData 
				) ta Order by Len(WorkLine),WorkLine
            FOR XML PATH('')
            ), 1, 1, '');

select @SQLQuery ='
select(
select * 
from #TempBaseData
pivot(
	Max([Value]) 
	for Workline in ('+@ColList+ ')
) as pvt for json path,include_null_values) as Value;';

Exec(@SQLQuery);
END
ELSE 
BEGIN
	select '' as [Value]
END