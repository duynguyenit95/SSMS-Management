USE [ORP]
GO

/****** Object:  View [dbo].[V_KTV_HRInfo]    Script Date: 7/7/2023 11:29:33 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER view [dbo].[V_KTV_HRInfo]
as
with t1 as(
	select *
	from KTV_KanbanTVGroup (nolock) 
	where 1 = 1 
	and (NOT ([Description] like N'%TEST%' OR Factory = 'Deleted'))
)
,t2 as (
	select t1.ID, t1.Factory, t1.GroupName, t1.Description, ParentID
	from t1 where ParentID = 0
	union all
	select t.ID, t.Factory, t.GroupName, cast(c.Description + ' / ' + t.Description as nvarchar(max)) Description, t.ParentID
	from t2 c
	inner join t1 t on t.ParentID = c.ID
)
,t3 as (
	select t2.*, ta.[Name], ta.ID KanbanID, ta.Department, ta.Workshop
	from t2
	inner join KTV_KanbanTV ta on ta.GroupID = t2.ID
)
select KanbanID, Factory, GroupName,  
		TypeKanban = case when [Description] like N'%Công đoạn sau%' OR GroupName in ('FWUPP1','FWS') then N'产线Kanban chuyền'
							--when [GroupName] = 'CuttingProcess' then 'CUT'
							--when [GroupName] = 'IMMQI' then 'LAB'
							when [GroupName] = 'MOD' then N'中控Kanban xưởng'
							else N'部门看板 Kanban bộ phận khác' end,
		[TypeNo] = case when [Description] like N'%Công đoạn sau%' OR GroupName in ('FWUPP1','FWS','MOD') then 0 else 1 end,
		[Description], Department, Workshop, Name KanbanName
from t3
GO


