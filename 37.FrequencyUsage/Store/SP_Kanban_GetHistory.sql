USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_Kanban_GetHistory]    Script Date: 7/7/2023 11:23:07 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Darius>
-- Create date: <2023-01-07>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[SP_Kanban_GetHistory]
	-- Add the parameters for the stored procedure here
	@pDate date = '2023-06-30',
	@pType int = 0, -- 0: kanban CĐS, 1: kanban bộ phận khác
	@pFactory nvarchar(50) = 'VNA,VNB'
AS

DECLARE @Factory TABLE (Fac_no nvarchar(10))
INSERT INTO @Factory
SELECT * from string_split(@pFactory,',')

DROP TABLE IF EXISTS #t_log
select t1.*
	,ISNULL(t2.Morning,0) Morning
	,ISNULL(t2.Afternoon,0) Afternoon
	,ISNULL(t2.Night,0) Night
	-- 2: on
	-- 1: late
	-- 0: off
into #t_log
from V_KTV_HRInfo t1
left join KTV_DailyPowerLog t2 on t1.KanbanID = t2.KanbanID and t2.DateShift = @pDate
where t1.TypeNo = @pType
and t1.Factory in (select * from @Factory)


IF @pType = 0
	BEGIN
		SELECT (
			SELECT *, case when (Morning = 2 AND Afternoon = 2) then 'OK' else 'NG' end as Result
			from #t_log
			for json path, include_null_values
		) as [Value]
	END

ELSE
	BEGIN
	WITH t_key as(
		select *, @pDate [Date]
		from V_KTV_KeyUploadPlan
	)
	,t1 as (
		select t_key.*
			,case when t1.UploadTime is null then 0 -- không upload kế hoạch hôm đó
				  when t1.UploadTime <= DATEADD(HOUR, 8, DATEDIFF(DAY, 0, t1.WorkDate)) then 2 --tải kế hoạch trước 8h sáng ngày có kế hoạch
				  else 1 end as UploadStatus
		from t_key
		left join KTV_UserUploadedPlanData t1
		on t_key.KanbanID = t1.KanbanID
		and t_key.ScreenID = t1.ScreenID
		and t_key.[Date] = t1.WorkDate
		and t_key.UploadName = t1.UploadName
		and t_key.KeyType = t1.KeyType
		and t_key.[Key] = t1.[Key]
	)
	,t2 as (
		select ta.*, t1.[Key], ISNULL(t1.UploadStatus,9) UploadStatus
		from #t_log ta
		left join t1 on ta.KanbanID = t1.KanbanID
	)
	SELECT (
		select *, case when (Morning = 2 AND Afternoon = 2 AND UploadStatus in (2,9)) then 'OK' else 'NG' end as Result
		from t2
		for json path, include_null_values
	) as [Value]
END
