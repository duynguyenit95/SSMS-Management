USE [ORP]
GO

/****** Object:  View [dbo].[V_KTV_KeyUploadPlan]    Script Date: 7/7/2023 11:30:02 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER view [dbo].[V_KTV_KeyUploadPlan]
as
select	t2.KanbanID
				,ta.ScreenID
				,td.[Value] as [Key]
				,t1.KeyType
				,t1.UploadName
		from KTV_ScreenKanbanMapping(nolock) ta 
		cross apply openjson(ta.JSONParamater) tc 
		cross apply string_split(tc.[Value],',') td
		inner join KTV_TemplateKeyMapping t1 
		on ta.KanbanID = t1.KanbanTemplateID 
		and t1.KeyType = tc.[Key] collate database_default
		inner join KTV_KanbanTVScreenMapping t2
		on ta.ScreenID = t2.ScreenID
		where td.[value] <> ''
GO


