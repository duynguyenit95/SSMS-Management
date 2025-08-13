USE [ETSDB_Regina]
GO
/****** Object:  StoredProcedure [dbo].[SP_DN_RM052B]    Script Date: 8/18/2023 9:23:29 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- CREATED IN 172.19.18.81.ETSDB_Regina
ALTER PROCEDURE [dbo].[SP_DN_RM052B]
 @pWorkshop nvarchar(10) = 'D1',
 @pStyleNo nvarchar(50) = '',
 @pSaleNo nvarchar(50) = '',
 @pMO nvarchar(50) = ''
as

drop table if exists #t_orderDetails
select t1.ZDCODE Zdcode
	  ,t2.MY_COUNT Quantity
      ,t1.SaleNo
	  ,t1.STYLE_NO StyleNo
	  ,convert(date,t1.Take_Date) ExportDate
	  ,t2.COLOR_NO ColorNo
	  ,t2.ColorSequence
	  ,t2.CM Size
into #t_orderDetails
from T_SCZZD (nolock) t1
inner join TB_MK_ZD_COLOR_SIZE (nolock) t2
on t1.[SID] = t2.CNID
where SUBSTRING(t1.SaleNo,1,3) = 'A16'
and (t1.ZDCODE = @pMO or @pMO = '')
and (t1.STYLE_NO = @pStyleNo or @pStyleNo = '')
and (t1.SaleNo = @pSaleNo or @pSaleNo = '')

drop table if exists #t_output
select t2.WorkShop Workshop
	 , t1.WorkDate
	 , UPPER(t1.WorkLine) Workline
	 , t1.ZDCode Zdcode
	 , t1.ColorSequence
	 , t1.Ssize Size
	 , t1.GxNo
	 , Sum(t1.Qty) Quantity
into #t_output
from EmployeeDayData (nolock) t1
inner join TWorkline (nolock) t2 on t1.WorkLine = t2.WorkLineName
where 1=1
and t1.ColorSequence <> 0 
and LEFT(t1.WorkLine,1) = 'D'
and RIGHT(t1.WorkLine,3) <> '-L0'
and GxNo in ('697','698','700')
and Qty > 0
and ZDCode in (select distinct Zdcode from #t_orderDetails)
and (t2.WorkShop = @pWorkshop or @pWorkshop = '')
group by t2.WorkShop, t1.WorkDate, t1.WorkLine, t1.ZDCode, t1.ColorSequence, t1.Ssize, t1.GxNo


select Workshop, Workline, Zdcode, ColorSequence, Size, GxNo, SUM(Quantity) Quantity ,[Type] = 'Accumulated'
into #t_outputs
from #t_output
group by Workshop, Workline, Zdcode, ColorSequence, Size, GxNo

insert into #t_outputs
select Workshop, Workline, Zdcode, ColorSequence, Size, GxNo, SUM(Quantity) Quantity, [Type] = 'Today'
from #t_output
where WorkDate = convert(date,getdate())
group by Workshop, Workline, Zdcode, ColorSequence, Size, GxNo 

select [Key] = 'OrderDetail',
( select * from #t_orderDetails for json path,include_null_values) as [Value]
union
select [Key] = 'Output',
( select * from #t_outputs for json path,include_null_values) 
as [Value]