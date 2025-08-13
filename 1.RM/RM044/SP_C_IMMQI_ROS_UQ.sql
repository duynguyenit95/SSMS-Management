USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_C_IMMQI_ROS_UQ]    Script Date: 4/19/2023 7:06:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[SP_C_IMMQI_ROS_UQ]
AS

DECLARE @Date date = convert(date, getdate()-1)

---------- SAP COLOR -----------------
DROP TABLE IF EXISTS #t_color
SELECT SAPColorCode, DSClass, CreateDate, ModifyDate, DeleteMark
into #t_color
from [172.18.18.36].Reginaimmqibase.dbo.QI_ColorSample with (nolock)
where (CreateDate >= @Date or ModifyDate >= @Date)
and SAPColorCode ! = ''

MERGE [IMMQI_SAPColorCode] as TARGET
USING #t_color as SOURCE
ON TARGET.SAPColorCode = SOURCE.SAPColorCode --AND TARGET.CreateDAte = SOURCE.CreateDate
WHEN MATCHED AND TARGET.DSClass <> SOURCE.DSClass AND SOURCE.DeleteMark = 0 AND (TARGET.ModifyDate < SOURCE.ModifyDate OR TARGET.ModifyDate is null)
THEN UPDATE SET TARGET.DSClass = SOURCE.DSClass, TARGET.ModifyDate = SOURCE.ModifyDate, TARGET.UpdatedTime = GETDATE()
WHEN NOT MATCHED BY TARGET AND SOURCE.DeleteMark = 0
THEN INSERT (SAPColorCode, DSClass, CreateDate, ModifyDate, UpdatedTime) VALUES (SOURCE.SAPColorCode, SOURCE.DSClass, SOURCE.CreateDate, SOURCE.ModifyDate, GETDATE())
WHEN MATCHED AND SOURCE.DeleteMark = 1
THEN DELETE;
---------- END SAP COLOR -----------------




---------- Barcode CreateDate -----------------
DROP TABLE IF EXISTS #t_inspect
SELECT * into #t_inspect from openquery([172.18.18.36],'
	DECLARE  @Date date = convert(date, getdate()-1)
	select t1.EnCode, t2.Barcode, t1.CreateDate, t1.ModifyDate, t1.DeleteMark T1DeleteMark, t2.DeleteMark T2DeleteMark,
		   t3.ZBATCH1_MASTER_DIMENSION_NAME as GridDescription, t3.DeleteMark T3DeleteMark
	from ReginaImmqiBase.dbo.QAFI_Inspect (nolock) t1
	inner join ReginaImmqiBase.dbo.QAFI_InspectDetail (nolock) t2 on t1.InspectId = t2.InspectId
	inner join ReginaImmqiBase.dbo.QI_SAPInspectData (nolock) t3 on t2.SAPInspectDataId = t3.SAPInspectDataId
	where (t1.CreateDate >= @Date or t1.ModifyDate >= @Date)
	and t1.InspectType in (0,2)'
)
--- Phân tích

drop table if exists #t_barcode
select EnCode,Barcode, CreateDate,GridDescription, ModifyDate
,MAX(ModifyDate) OVER (PARTITION BY Barcode) NewModifyDate
,MAX(CreateDate) OVER (PARTITION BY Barcode) NewCreateDate
,T1DeleteMark, T2DeleteMark
into #t_barcode
from #t_inspect

drop table if exists #t_barcodeResult
select Barcode, CreateDate, GridDescription
,CASE WHEN T1DeleteMark = 0 then 0 else 1 end DeleteMark
into #t_barcodeResult
from #t_barcode
--- Chỉ lấy dữ liệu có ngày tạo mới nhất
where CreateDate = NewCreateDate
and ModifyDate = NewModifyDate


-- Cập nhật bảng  IMMQI_BarcodeCreateDate
MERGE [IMMQI_BarcodeCreateDate] as TARGET
USING #t_barcodeResult as SOURCE
ON TARGET.Barcode = SOURCE.Barcode --AND TARGET.CreateDAte = SOURCE.CreateDate
WHEN MATCHED AND (TARGET.CreateDate <> SOURCE.CreateDate OR TARGET.GridDescription <> SOURCE.GridDescription) AND SOURCE.DeleteMark = 0
THEN UPDATE SET TARGET.CreateDate = SOURCE.CreateDate, TARGET.GridDescription = SOURCE.GridDescription, TARGET.UpdatedTime = GETDATE()
WHEN NOT MATCHED BY TARGET AND SOURCE.DeleteMark = 0
THEN INSERT (Barcode, CreateDate,GridDescription, UpdatedTime) VALUES (SOURCE.Barcode, SOURCE.CreateDate, SOURCE.GridDescription, GETDATE())
WHEN MATCHED AND SOURCE.DeleteMark = 1
THEN DELETE;

----------END Barcode CreateDate -----------------