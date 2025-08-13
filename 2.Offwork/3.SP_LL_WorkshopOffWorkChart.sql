-- Created in ROS ORP Database 172.19.18.86 - ROS 
/****** Object:  StoredProcedure [dbo].[SP_LL_WorkshopOffWorkChart]    Script Date: 9/13/2021 11:28:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SP_LL_WorkshopOffWorkChart]
@Workshop nvarchar(20) = 'A1'
as
select OffStdName as [Param],Sum([Value]) as [Value]
from T_ETS_OffWork(nolock) 
where UpdateTime > convert(date,GetDate())
and WorkShop = @Workshop
-- Only get Workshop summary data
and WorkLine = 'ZZZZZTotal'
group by OffStdName
