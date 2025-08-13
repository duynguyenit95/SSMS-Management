USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_C_KanbanDailyPowerLog]    Script Date: 7/7/2023 11:25:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   PROCEDURE  [dbo].[SP_C_KanbanDailyPowerLog]
	@inpDate nvarchar(10) = null
as

DECLARE @Date datetime
IF @inpDate is not null
SET @Date = convert(date,@inpDate)
else 
SET @Date = convert(date,GetDate()-1)


DECLARE @Start datetime = DateAdd(hour,6,@Date)
DECLARE @End datetime = DateAdd(day,1,@Start)
---Morning: 08:00 - 09:00  
---Afternoon: 12:30 - 14:30  
---Night: 20:00 - 06:00 (next day)  
DROP TABLE IF EXISTS #Result;  
WITH t1 as (  
 SELECT KanbanID as KanbanID, cast([Time] as time) as [TimeShift]  
 FROM [172.19.18.86].[ROS].[dbo].[KTV_VisitLog]  with (nolock) 
 WHERE  [Time] >= @Start
 AND   [Time] <= @End 
)   
SELECT  
 KanbanID,   
       MAX(CASE WHEN [TimeShift] between '06:00:00' and '09:00:00' THEN 2  
				WHEN [TimeShift] between '09:00:01' and '12:30:00' THEN 1 
				ELSE 0 END) AS [Morning],  
       MAX(CASE WHEN [TimeShift] between '12:00:00' and '14:00:00' THEN 2  
				WHEN [TimeShift] between '14:00:00' and '20:00:00' THEN 1 
				ELSE 0 END) AS [Afternoon],  
       MAX(CASE WHEN ([TimeShift] between '20:00:00' and '23:59:59') OR ([TimeShift] between '00:00:00' and '06:00:00') THEN 2 
				ELSE 0 END) AS [Night]  
 INTO #Result  
FROM t1  
GROUP BY KanbanID  
  
DELETE KTV_DailyPowerLog  
WHERE DateShift = @Date;  
  
INSERT INTO KTV_DailyPowerLog  
SELECT @Date,KanbanID,Morning,Afternoon,Night,GETDATE() UpdatedTime  
FROM #Result  