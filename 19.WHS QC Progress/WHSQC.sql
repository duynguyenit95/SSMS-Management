USE [ORP]
GO

/****** Object:  View [dbo].[V_DN_WHS_WarehouseQCProgress]    Script Date: 10/27/2021 1:48:23 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE SP_LL_WHS_QCProgress
@Factory nvarchar(5) = 'VNC',
@pExportDate nvarchar(10) = ''
as
	

DECLARE @ExportDate date = convert(date,ISNULL(cast(NULLIF(@pExportDate,'') as date),GetDate()));

select  ta.Factory 
	   ,ta.ExportDate 
       ,ta.CarOutTime
	   ,tb.PackNo
	   ,tb.SO
	   ,tb.SOItemNo
	   ,tb.PO	
	   ,tb.Color
	   ,tb.Customer
	   ,tb.StyleNo
	   ,tb.TotalPackBox
	   ,tb.TotalPackQuantity
	   ,tb.LackPackBox
	   ,tb.LastUpdateDate
	   ,tb.QABorrowBox
	   ,tb.PreCheck
	   ,tb.FinalCheck
	   ,tb.UpdatedTime
-- Insert into Temp Table to reduce total data 
into #Temp
from V_WHS_Car ta (nolock)
inner join V_WHS_PackPlan(nolock) tb on ta.ExportDate = tb.ExportDate and ta.Factory = tb.Factory and ta.Car = tb.Car
where 1 = 1 
and ta.ExportDate >= @ExportDate
and ta.Factory = @Factory
and PO != ''

select (
select Factory,ExportDate
	  ,Max(CarOutTime) as CarOutTime
	  ,SO,PO
	  ,Color = STUFF(
             (SELECT ',' + ta.Color 
              FROM #Temp ta 
              WHERE t1.PO = ta.PO
			  group by ta.Color
              FOR XML PATH (''))
        , 1, 1, '')
	  ,Customer,StyleNo
	  ,Sum(TotalPackBox) as TotalPackBox
	  ,Sum(TotalPackQuantity) as TotalPackQuantity
	  ,Sum(LackPackBox) as LackPackBox
	  ,Max(LastUpdateDate) as LastUpdateDate
	  ,Max(QABorrowBox) as QABorrowBox
			-- If has any fail ==> Fail 
	  ,case when Sum(case when PreCheck = 0 then 1 else 0 end) > 0 then 0 
			-- No Fail Check and has Pass ==> Pass
			when Sum(case when PreCheck = 1 then 1 else 0 end) > 0 then 1 
			-- No Infor
			else null 
		end as PreCheck

			-- Same as PreCheck
	  ,case when Sum(case when FinalCheck = 0 then 1 else 0 end) > 0 then 0 
			when Sum(case when FinalCheck = 1 then 1 else 0 end) > 0 then 1 
			else null 
		end as FinalCheck
	  ,Max(UpdatedTime) as UpdatedTime
from #Temp t1
group by Factory,ExportDate,PO,Customer,SO,StyleNo
for json path,include_null_values
) as [Value]
GO


