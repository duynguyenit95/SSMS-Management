USE [ETSDB_Regina]
GO

/****** Object:  View [dbo].[V_LL_MOBase]    Script Date: 10/21/2021 9:59:03 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[V_LL_MOBase]
as 
select tb.SysZhubie as Factory,tb.ZDCODE,tb.SaleNo,tb.SOItemNo,tb.STYLE_NO,COLOR_NO = STUFF(
             (SELECT ',' + t1.COLOR_NO 
              FROM TB_MK_ZD_COLOR_SIZE t1
              WHERE t1.cnid = tb.sid
			  group by t1.COLOR_NO
              FOR XML PATH (''))
        , 1, 1, ''),tb.MY_COUNT as Quantity
		,tb.Take_Date as ShipDate
from  T_SCZZD (nolock) tb 
inner join TB_MK_ZD_COLOR_SIZE (nolock) tc on tc.cnid = tb.sid
inner join tbauGroupCard (nolock) td on td.ZDcode = tb.ZDCODE
where 1 = 1
and (tb.[State] is null or tb.[State] != 'C')
group by tb.SysZhubie,tb.ZDCODE,tb.SaleNo,tb.SOItemNo,tb.STYLE_NO,tb.MY_COUNT,tb.Take_Date,tb.SID;
GO


