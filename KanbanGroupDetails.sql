CREATE OR ALTER PROCEDURE SP_GetKanbanGroupInfo
as
set nocount on;
--drop table if exists #G;

with t1 as(
select *
from KTV_KanbanTVGroup (nolock) 
where 1 = 1 
and (NOT ([Description] like N'%TEST%' OR Factory = 'Deleted'))
),
t2 as(
	select t1.Factory,t1.ID as RootId,t1.GroupName,t1.Description, t1.ID as GroupID,t1.ParentID as ParentID
	from t1 
	union all 
	select t2.Factory,t2.RootId,t2.GroupName,t2.Description, ta.ID as GroupID,t2.ParentID as ParentID
	from t2 
	inner join t1 ta on ta.ParentID = t2.GroupID
)
select t2.Factory
	 ,N'G'+cast(t2.RootId as nvarchar(16)) as [Key]
	 ,t2.RootId
	 ,GroupName
	 ,Description
	 ,ta.GroupID
	 ,N'G'+cast(t2.ParentID as nvarchar(16)) as [ParentKey]
	 ,ta.ID as KanbanID
	 ,ta.Name as KanbanName --,Count(1)
into #G
from t2
inner join KTV_KanbanTV ta on ta.GroupID = t2.GroupID
where  1 = 1 
order by Factory,RootId;

--select *
--from #G
--where RootId = 1;

with t1 as(
select Factory
	  ,[ParentKey]
	  ,[Key]
	  ,RootId
	  ,GroupName
	  ,[Description]
	  ,ChildGroups = STUFF((
            SELECT distinct ',' + cast(GroupID as nvarchar(16))
            FROM #G tb
			where ta.RootId = tb.RootId
            FOR XML PATH('')
            ), 1, 1, '')
	 ,Count(1) as TotalKanban
from #G ta
group by Factory,[ParentKey],[Key],RootId,GroupName,[Description]
),
t2 as(
select * 
from t1
union all
select N'Kanban' as Factory
	, 'G' + cast(GroupID as nvarchar(16)) as [ParentKey]
	, 'K' + cast(ID as nvarchar(16)) as [Key]
	, ID as RootId
	, Name as GroupName
	, Name as Description
	, N'' as ChildGroups
	, 1 as TotalKanban
from KTV_KanbanTV
)
select(
	select * from t2
	order by Factory,len(GroupName),GroupName,RootId desc
for json path) as [Value]