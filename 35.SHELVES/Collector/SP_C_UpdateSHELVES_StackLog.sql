USE [ORP]
GO
/****** Object:  StoredProcedure [dbo].[SP_C_UpdateSHELVES_StackLog]    Script Date: 4/19/2023 6:53:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[SP_C_UpdateSHELVES_StackLog]

AS
BEGIN


--drop table #temp
select StackId, Type, Time, Amount
into #temp
from SHELVES.dbo.StackLog (nolock) t1
where Time > (case when (select Max(Time) from SHELVES_StackLog) is null 
				then convert(date,getdate()) 
				else (select Max(Time) from SHELVES_StackLog) end)


insert into SHELVES_StackLog
select * from #temp;

delete from SHELVES_StackLog 
where CONVERT(date, Time) <= CONVERT(date, getdate()-1)
END
