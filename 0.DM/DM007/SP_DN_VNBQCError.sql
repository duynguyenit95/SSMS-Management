USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_VNBQCError]    Script Date: 4/19/2023 7:28:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/
ALTER PROCEDURE [dbo].[SP_DN_VNBQCError]
 @pWorkshop nvarchar(20) = 'FNG-B'
as

with ta as (
	select ReturnWorkCode, SUM(ReturnWorkCount) ReturnWorkCount from DM007_ETS_QC
	where Workshop = @pWorkshop
	and BillDate = convert(date, getdate())
	group by ReturnWorkCode
)
,tb as (
	select isnull(t1.GroupName,t1.RWName) GroupName, t1.RWName, t1.RWCode, ta.ReturnWorkCount
	from DM007_ErrorCode t1
	inner join ta on t1.RWCode = ta.ReturnWorkCode collate database_default
	where WorkshopType = SUBSTRING(@pWorkshop,1,3)
)
	select GroupName as [Param]
	,Cast(SUM(ReturnWorkCount) as decimal(18,4))as [Value]
	from tb
	group by GroupName




