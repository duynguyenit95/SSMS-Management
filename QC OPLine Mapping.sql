/****** Script for SelectTopNRows command from SSMS  ******/
with t1 as(
SELECT   tb.ID, ta.ID as QClineID,ta.Name as QCLine , tc.Name as ScreenName
  FROM [QCSYSTEM].[dbo].[OPLine] ta 
  inner join ORP.dbo.KTV_Screen tc on tc.Name = N''+ta.Name+' Light'
  inner join ORP.dbo.KTV_ScreenKanbanMapping tb on tb.ScreenID = tc.ID and tb.KanbanID = 23
  where ta.Type = 1
  --and ta.Name not like 'E%'
  and ta.IsDeleted = 0
  )
  Update ORP.dbo.KTV_ScreenKanbanMapping set JSONParamater = '{"URL":"http://ros:8085/show?id='+cast(t1.QClineID as nvarchar(10))+'"}'
  --select *  
  from ORP.dbo.KTV_ScreenKanbanMapping  ta
  inner join t1 on ta.ID = t1.ID 


  select * from [QCSYSTEM].[dbo].[OPLine]

  select JSONParamater,Count(1) 
  from ORP.dbo.KTV_ScreenKanbanMapping ta 
  inner join ORP.dbo.KTV_Screen tb on ta.ScreenID = tb.ID
  where KanbanID = 23
  group by JSONParamater
  having count(1) > 1

  with t1 as(
  select ta.ID
  from ORP.dbo.KTV_ScreenKanbanMapping ta 
  left join ORP.dbo.KTV_Screen tb on ta.ScreenID = tb.ID
  where tb.ID is null
  ) 
  delete from ORP.dbo.KTV_ScreenKanbanMapping where ID in (select ID from t1)
select * from [QCSYSTEM].[dbo].[OPLine] ta where Id in (2135,1022,2303,2199)

select * from [QCSYSTEM].[dbo].[OPLine] ta where Type =1 and Name in( 'A5-L16','A19-L15')