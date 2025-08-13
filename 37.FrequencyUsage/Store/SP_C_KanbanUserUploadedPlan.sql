USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_C_KanbanUserUploadedPlan]    Script Date: 7/7/2023 11:26:12 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_C_KanbanUserUploadedPlan]
	@saveData bit = 1
AS
DECLARE @pDate date = convert(date, getdate())

BEGIN
drop table if exists #result;
with t_base as(
	select ScreenID,ta.KanbanID KanbanTemplateID
			,t1.KeyType 
			,td.[Value] as [Key]
			,t1.UploadName
	from KTV_ScreenKanbanMapping(nolock) ta 
	cross apply openjson(ta.JSONParamater) tc 
	cross apply string_split(tc.[Value],',') td
	inner join KTV_TemplateKeyMapping t1 
	on ta.KanbanID = t1.KanbanTemplateID 
	and t1.KeyType = tc.[Key] collate database_default
	where td.[value] <> ''
)
,t_hr as (
	select distinct Fac_no [Factory]
				   ,Dep_no [Dept]
				   ,Wrk_no WorkShop
				   ,Lin_no [WorkLine]
	from [Regina_User].dbo.HR_Org(nolock)
)
,t1 as (
	select [Date] WorkDate
		,'process' KeyType
		,'VNBWHSExp' [Key] 
		,'DM001' UploadName
		,MIN(UpdatedTime) UploadTime
	from DM001
	where [Date] = @pDate
	group by [Date]
)
,t4 as (
	select WorkDate
			,'Workshop' as KeyType
			,Workshop [Key]
			,'DM004' as UploadName
			,MIN(ImportedTime) UploadTime
	from [172.19.18.86].[ROS].[dbo].[T_WorkshopMatingPlanInfor]
	where WorkDate = @pDate
	group by WorkDate, Workshop
)
,t5 as (
	select  WorkDate
		,case when CutLine = '' then 'storeNo' else 'workline' end as KeyType
		,case when CutLine = '' then ETSStoreNo else CutLine end as [Key]
		,'DM005' as UploadName
		,MIN(LastUpdatedTime) UploadTime
	from [172.19.18.86].[ROS].dbo.[T_CUT_Plan]
	where (NightTargetQty > 0 or DayTargetQty > 0)
	and WorkDate = @pDate
	group by WorkDate
			,case when CutLine = '' then 'storeNo' else 'workline' end
			,case when CutLine = '' then ETSStoreNo else CutLine end 
)
,t8 as (
	select [Date] WorkDate
			,'Department' as KeyType
			,t_hr.Dept
			,'DM008' as UploadName
			,MIN(ImportedDate) UploadTime
	from T_FWTSWMExportPlan ta
	inner join t_hr
	on ta.Workline = t_hr.WorkLine collate database_default
	where [Date] = @pDate
	group by [Date], t_hr.Dept
)
,t9 as (
	select ta.[Date] WorkDate
			,'Workline' as KeyType
			,t_hr.WorkLine as [Key]
			,'DM009' as UploadName
			,MIN(ImportedDate) UploadTime
	from T_SANTONI_PlanQty ta
	inner join t_hr 
	on ta.Workline = t_hr.WorkLine collate database_default
	where [Date] = @pDate
	group by [Date], t_hr.WorkLine
)
,t10 as (
	select [Date] WorkDate
		  ,'workshop' as KeyType
		  ,Workline as [Key]
		  ,'DM010' as UploadName
		  ,MIN(ImportedDate) UploadTime
	from DM010
	where [Date] = @pDate
	group by [Date], Workline
)
,t_ppmix as(
	SELECT  ta.[WorkDate]
			,'Workshop' as KeyType
			,t_hr.WorkShop as [Key]
			,'PPMIX' as UploadName
			,MIN(ImportedDate) UploadTime
   FROM [ORP].[dbo].[T_R_OldMatingPlan] ta
   inner join t_hr on ta.Workline = t_hr.WorkLine collate database_default
   where ta.[WorkDate] = @pDate
   group by ta.WorkDate, t_hr.WorkShop
)
,t_whs as (
	select ExportDate [WorkDate]
			,'Factory' as KeyType
			,Factory as [Key]
			,'FGExport' as UploadName
			,MIN(ImportedTime) UploadTime
	from WHS_PackPlan
	where ExportDate = @pDate
	group by ExportDate, Factory
)
,t_combine as (
	select * from t_ppmix
	union all select * from t_whs
	union all select * from t1
	union all select * from t4
	union all select * from t5
	union all select * from t8
	union all select * from t9
	union all select * from t10
)

select tc.KanbanID, ta.*, tb.WorkDate, tb.UploadTime
into #result
from t_base ta
left join t_combine tb 
on ta.UploadName = tb.UploadName and ta.[Key] = tb.[Key] and ta.[KeyType] = tb.[KeyType]
inner join KTV_KanbanTVScreenMapping tc
on ta.ScreenID = tc.ScreenID

IF @saveData = 1
	BEGIN
		DELETE [KTV_UserUploadedPlanData]
		where WorkDate = @pDate;

		INSERT INTO [KTV_UserUploadedPlanData]
		select *, getdate() SyncTime
		from #result
		where WorkDate is not null;
	END
ELSE
	BEGIN
		select (
			select t2.Factory
			    ,GroupName = case when t2.GroupName = 'CuttingProcess' then N'裁床Cắt'
								  when t2.GroupName = 'Export/Import' then N'出入货进度Xuất/nhập hàng'
								  when t2.GroupName = 'ExportPlan' then N'成品仓Kho thành phẩm'
								  when t2.GroupName = 'FabricMaterialPreparing' then N'原料仓Kho nguyên liệu'
								  when t2.GroupName = 'FWTSWC' then N'鞋部Xưởng giày'
								  when t2.GroupName = 'MaterialBatchingProgress' then N'配料中心Trung tâm phối liệu'
								  else t2.GroupName end
								  --MaterialBatchingProgress
				,t2.KanbanName, t2.Department, t1.[Key], t1.UploadName, t1.UploadTime,
				   case when t1.UploadTime is null then 'NG' else 'OK' end as Result
			from #result t1
			inner join V_KTV_HRInfo t2
			on t1.KanbanID = t2.KanbanID
			order by Factory, GroupName, KanbanName, [Key]
			for json path, include_null_values
		) AS [Value]
	END
END

---EXEC [SP_C_KanbanUserUploadedPlan] @saveData = 0