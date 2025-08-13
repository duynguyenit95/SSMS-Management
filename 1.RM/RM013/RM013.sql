-- Created in ETS Server 172.19.18.81

USE [ETSDB_Regina]
GO
/****** Object:  StoredProcedure [dbo].[SP_LL_ImportantOPCheck_InProduction]    Script Date: 10/8/2021 5:21:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SP_LL_ImportantOPCheck_InProduction]
 @pStartDate nvarchar(20) = '',
 @pEndDate nvarchar(20) = '',
 @pSaleNo nvarchar(20) = '',
 @pMO nvarchar(max) = '',
 @pStyleNo nvarchar(50) = '',
 @pFactory nvarchar(20) = '',
 @pDepartment nvarchar(MAX) = '',
 @pWorkshop nvarchar(MAX) = '',
 @pMixMaterialGxCode nvarchar(50) = '697,8289',
 @pTackGxCode nvarchar(50) = '698,8288',
 @pQAGxCode nvarchar(50) = '700,8290'
as
DECLARE @StartDate date = convert(date,@pStartDate);
DECLARE @EndDate date = convert(date,@pEndDate);
DECLARE @Department table(Department nvarchar(50));
DECLARE @Workshop table(Workshop nvarchar(50));
DECLARE @MixMaterialGxCode table(MixMaterialGxCode nvarchar(10));
DECLARE @TackGxCode table(TackGxCode nvarchar(10));
DECLARE @QAGxCode table(QAGxCode nvarchar(10));
DECLARE @AllGxCode table(GxCode nvarchar(10));

DECLARE @MO table(Zdcode nvarchar(20));
insert into @MO
select Name from SplitString(@pMO,',');


insert into @Department
select Name from SplitString(@pDepartment,',');

insert into @Workshop
select Name from SplitString(@pWorkshop,',');

insert into @MixMaterialGxCode
select Name from SplitString(@pMixMaterialGxCode,',');

insert into @TackGxCode
select Name from SplitString(@pTackGxCode,',');

insert into @QAGxCode
select Name from SplitString(@pQAGxCode,',');


insert into @AllGxCode
select * from (
select Name from SplitString(@pMixMaterialGxCode,',')
union all
select Name from SplitString(@pTackGxCode,',')
union all
select Name from SplitString(@pQAGxCode,',')
) ta;

-- MO Base
Select tmo.Take_Date,tmo.SaleNo,tmo.SOItemNo,tmo.STYLE_NO,tmo.ZDCODE,tmo.MY_COUNT,tcolor.COLOR_NO,SUM(tcolor.MY_COUNT) as MOQty 
into #MOPreBases
from T_SCZZD(nolock) tmo 
inner join TB_MK_ZD_COLOR_SIZE tcolor on tmo.SID = tcolor.CNID
where 1 = 1
and LEFT(tmo.Zdcode,5) in ('00007','00006','00004','00008')
and (convert(date,tmo.Take_Date) between @StartDate and @EndDate OR @pStartDate = '' OR @pEndDate = '' )
and ([state] != 'C' OR [state] is null)
and (tmo.SysZhuBie = @pFactory OR @pFactory = '')
and (tmo.SaleNo = @pSaleNo OR @pSaleNo = '')
and (tmo.ZDCODE in (select * from @MO) OR @pMO = '')
and (tmo.STYLE_NO = @pStyleNo OR @pStyleNo = '')
group by tmo.Take_Date,tmo.SaleNo,tmo.SOItemNo,tmo.STYLE_NO,tmo.ZDCODE,tmo.MY_COUNT,tcolor.COLOR_NO;


select Take_Date,SaleNo,SOItemNo,STYLE_NO,ZDCODE
      ,COLOR_NO = STUFF(
             (SELECT ',' + COLOR_NO 
              FROM #MOPreBases t1
              WHERE t1.ZDCODE = ta.ZDCODE
			  group by COLOR_NO
              FOR XML PATH (''))
        , 1, 1, '') 
	,SUM(MOQty) as MOQty
into #MOBases
from #MOPreBases  ta
where 1 = 1 
group by Take_Date,SaleNo,SOItemNo,STYLE_NO,ZDCODE;


select distinct Zdcode 
into #Zdcode
from #MOBases


-- Factory,Dept,Workshop,Line data
select distinct ZhuBie as Factory,ProductArea as Department,WorkShop,WorkLineName as Workline
into #HR_Org
from TWorkLine (nolock)
where 1 = 1
and (ZhuBie = @pFactory OR @pFactory = '')
and (ProductArea in (select * from  @Department) OR @pDepartment = '')
and (WorkShop in (select * from  @Workshop)  OR @pWorkshop = '')
and  ZhuBie is not null;

-- Production Data
select t2.Factory,t2.Department,t2.WorkShop
		,GxNo
		,ta.Zdcode
		,Sum(TotalQty) as TotalQty
into #ProductionData
from EmployeeEfficencyInfo(nolock) ta 
inner join #HR_Org t2 on t2.Workline = ta.WorkLine
inner join @AllGxCode tgx on tgx.GxCode = ta.GxNo
where 1 = 1
and ta.ZDCODE in (select * from #Zdcode)
group by t2.Factory,t2.Department,t2.WorkShop,ta.Zdcode,GxNo;

with 
t4 as(
	select t3.Factory,t3.Department,t3.WorkShop
		  ,t1.Take_Date as ShipDate,t1.SaleNo,t1.SOItemNo,t1.STYLE_NO as StyleNo,t1.Zdcode,t1.COLOR_NO,t1.MOQty
		  ,GxNo
		  ,Sum(TotalQty) as TotalQty
	from #ProductionData t3 
	inner join #MOBases t1 on t1.ZDCODE = t3.Zdcode
	where 1 = 1
	group by t3.Factory,t3.Department,t3.WorkShop,t1.Zdcode,GxNo,t1.Take_Date,t1.SaleNo,t1.SOItemNo,t1.STYLE_NO,t1.COLOR_NO,t1.MOQty
),
--Pivot Production Data
t5 as (
select * 
from (
	select t4.Factory,t4.Department,t4.WorkShop,t4.ShipDate,t4.SaleNo,t4.SOItemNo,t4.StyleNo,t4.Zdcode,t4.COLOR_NO,t4.MOQty,
		   case when t4.GxNo in (select * from @MixMaterialGxCode) then 'MixMaterialProcess'
				when t4.GxNo in (select * from @TackGxCode) then 'TackProcess'
				when t4.GxNo in (select * from @QAGxCode) then 'QAProcess'
				end as ProgessName
			,TotalQty
	from t4 
	) ta
	pivot(
		Max(TotalQty)
		for ProgessName in ([MixMaterialProcess],[TackProcess],[QAProcess])
	) as pvt
)
select t5.Factory,t5.Department,t5.Workshop
		,t5.ShipDate,t5.SaleNo,t5.StyleNo,t5.Zdcode,t5.SOItemNo,t5.COLOR_NO,t5.MOQty
		,isnull(t5.MixMaterialProcess,0) as MixMaterialProcess
		,isnull(t5.QAProcess,0) as QAProcess
		,isnull(t5.TackProcess ,0) as TackProcess
		
from t5
order by t5.Factory,ShipDate,t5.Zdcode
for json path ,include_null_values


