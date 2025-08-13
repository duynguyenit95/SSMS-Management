USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_Kanban_FrequencyAnalysis]    Script Date: 7/7/2023 11:21:49 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Darius>
-- Create date: <2023-03-07>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[SP_Kanban_FrequencyAnalysis]
	@pStartDate date = '2023-06-26',
	@pEndDate date = '2023-06-30',
	@pType int = 1, -- 0: kanban CĐS, 1: kanban bộ phận khác
	@pFactory nvarchar(50) = 'VNA'
AS

DECLARE @Date TABLE (Date date)
DECLARE @index date = @pStartDate

WHILE(@index <= @pEndDate)
BEGIN
	IF DATENAME(DW, @index) != 'Sunday'
	INSERT INTO @Date 
	select @index
	SET @index = DATEADD(day, 1, @index)
END

DROP TABLE IF EXISTS #t_base
	SELECT KanbanID, GroupName, KanbanName, [Date]
	into #t_base
	FROM V_KTV_HRInfo 
	join @Date on 1=1
	where Factory = @pFactory
	and TypeNo = @pType

DROP TABLE IF EXISTS #t_log
SELECT ta.*, ISNULL(tb.Morning,0) + ISNULL(tb.Afternoon,0) PowerLog
into #t_log
from #t_base ta
left join KTV_DailyPowerLog tb on ta.KanbanID = tb.KanbanID and ta.[Date] = tb.[DateShift]
--select * from #t_log

IF @pType = 0
	BEGIN
		SELECT (
			SELECT GroupName, [Date]
				,case when MIN(PowerLog) = 4 then 'OK' else 'NG' end PowerLog
				,STUFF((
					SELECT ','+[KanbanName]
					FROM #t_log
					WHERE GroupName = res.GroupName 
					  and [Date] = res.[Date]
					  and PowerLog <> 4
					ORDER BY len(KanbanName), KanbanName
					FOR XML PATH(''),TYPE).value('(./text())[1]','NVARCHAR(MAX)')
				,1,1,'') AS Detail
			from #t_log res
			group by GroupName, [Date]
			order by GroupName, [Date]
			for json path, include_null_values
		) as [Value]
	END

ELSE
	BEGIN
	WITH t1 as (
		select ta.*, tb.ScreenID, tb.[Key]
			,case when tb.ScreenID is null then 2--N'NotTemplate'
				  when tc.ScreenID is null then 0--N'NotUpload'
				  when tc.UploadTime <= DATEADD(HOUR, 8, DATEDIFF(DAY, 0, tc.WorkDate)) then 2--N'OK'
				  else 1--N'Lated'
				  end as UploadStatus
		from #t_log ta
		left join V_KTV_KeyUploadPlan tb on ta.KanbanID = tb.KanbanID
		left join KTV_UserUploadedPlanData tc 
		on ta.KanbanID = tc.KanbanID
		and tb.ScreenID = tc.ScreenID
		and ta.[Date] = tc.WorkDate
		and tb.KeyType = tc.KeyType
		and tb.[Key] = tc.[Key]
		and tb.UploadName = tc.UploadName
		--order by KanbanID, [Date], ScreenID
	)
	SELECT (
		select GroupName, [Date]
			,case when MIN(PowerLog) = 4 then 'OK' else 'NG' end PowerLog
			,case when MIN(UploadStatus) = 2 then 'OK'
				  when MIN(UploadStatus) = 1 then 'Lated'
				  else 'NG' end as UploadStatus
		from t1
		group by GroupName, [Date]
		order by GroupName, [Date]
		for json path, include_null_values
	) as [Value]
END
