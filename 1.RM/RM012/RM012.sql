-- Created in ETS Server 172.19.18.81

USE [ETSDB_Regina]
GO
/****** Object:  StoredProcedure [dbo].[SP_LL_ImportantOPCheck_CompletedMO]    Script Date: 10/8/2021 4:19:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SP_LL_ImportantOPCheck_CompletedMO]
 @pStartDate nvarchar(20) = '2022-04-16',
 @pEndDate nvarchar(20) = '2022-04-16',
 @pSaleNo nvarchar(20) = '',
 @pSoItemNo nvarchar(20) = '',
 @pMO nvarchar(MAX) = '',
 @pStyleNo nvarchar(50) = '',
 @pFactory nvarchar(20) = '',
 @pDepartment nvarchar(MAX) = '',
 @pWorkshop nvarchar(MAX) = '',
 @pMixMaterialGxCode nvarchar(50) = '697',
 @pTackGxCode nvarchar(50) = '698',
 @pQAGxCode nvarchar(50) = '700',
 @pPackGxCode nvarchar(50) = '682'
as
DECLARE @StartDate date = convert(date,@pStartDate);
DECLARE @EndDate date = convert(date,@pEndDate);
DECLARE @Department table(Department nvarchar(50));
DECLARE @Workshop table(Workshop nvarchar(50));
DECLARE @MixMaterialGxCode table(MixMaterialGxCode nvarchar(10));
DECLARE @TackGxCode table(TackGxCode nvarchar(10));
DECLARE @QAGxCode table(QAGxCode nvarchar(10));
DECLARE @PackGxCode table(PackGxCode nvarchar(10));
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

insert into @PackGxCode
select Name from SplitString(@pPackGxCode,',');

insert into @AllGxCode
select * from (
select Name from SplitString(@pMixMaterialGxCode,',')
union all
select Name from SplitString(@pTackGxCode,',')
union all
select Name from SplitString(@pQAGxCode,',')
union all
select Name from SplitString(@pPackGxCode,',')
) ta;

--Related ZdCode - MO
select ZDCODE,ComDate,SaleNo,SOItemNo,STYLE_NO as StyleNo,COLOR_NO,SUM(tb.MY_COUNT) as MOQty
into #MOPreBases
from T_SCZZD(nolock) ta
inner join TB_MK_ZD_COLOR_SIZE tb on ta.SID = tb.CNID
where 1 = 1 
and LEFT(ZDCODE,6) in ('000077','000060','000043','000083')
and ([state] = 'C')
and (convert(date,ComDate) between @StartDate and @EndDate OR @pStartDate = '' OR @pEndDate = '')
and (ta.SysZhuBie = @pFactory OR @pFactory = '')
and (ta.SaleNo = @pSaleNo OR @pSaleNo = '')
and (ta.ZDCODE in (select * from @MO) OR @pMO = '')
and (ta.SOItemNo = @pSoItemNo OR @pSoItemNo = '')
and (ta.STYLE_NO = @pStyleNo OR @pStyleNo = '')
group by ZDCODE,ComDate,SaleNo,SOItemNo,STYLE_NO,tb.COLOR_NO;


select ZDCODE,ComDate,SaleNo,SOItemNo,StyleNo
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
group by ZDCODE,ComDate,SaleNo,SOItemNo,StyleNo;

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

-- Production Data
select t2.Factory,t2.Department,t2.WorkShop,ta.Zdcode,GxNo,Sum(TotalQty) as TotalQty
into #ProductionData
from EmployeeEfficencyInfo(nolock) ta 
inner join #HR_Org t2 on t2.Workline = ta.WorkLine
inner join @AllGxCode tgx on tgx.GxCode = ta.GxNo
where Zdcode in (select * from #Zdcode)
group by t2.Factory,t2.Department,t2.WorkShop,ta.ZDCODE,GxNo;

--Ship Data
select Zdcode,Sum(Qty) as TotalShipQty
into #ShipData
from t_Sap_MoShipOutQty_RM(nolock) ta 
where Zdcode in (select * from #Zdcode)
group by Zdcode;

with 
--Pivot Production Data
t5 as (
select * 
from (
	select t4.Factory,t4.Department,WorkShop,t4.ZDCODE,
		   case when t4.GxNo in (select * from @MixMaterialGxCode) then 'MixMaterialProcess'
				when t4.GxNo in (select * from @TackGxCode) then 'TackProcess'
				when t4.GxNo in (select * from @QAGxCode) then 'QAProcess'
				when t4.GxNo in (select * from @PackGxCode) then 'PackProcess'
				end as ProgessName
			,TotalQty
	from #ProductionData t4 
	) ta
	pivot(
		Max(TotalQty)
		for ProgessName in ([MixMaterialProcess],[TackProcess],[QAProcess],[PackProcess])
	) as pvt
)
select t5.Factory,t5.Department,t5.Workshop
		,t1.ComDate,t1.SaleNo,t1.StyleNo,t1.ZDCODE,t1.SOItemNo,t1.COLOR_NO,t1.MOQty
		,isnull(t6.TotalShipQty,0) as TotalShipQty
		,isnull(t5.MixMaterialProcess,0) as MixMaterialProcess
		,isnull(t5.PackProcess,0) as PackProcess
		,isnull(t5.QAProcess,0) as QAProcess
		,isnull(t5.TackProcess ,0) as TackProcess
		
from #MOBases t1
left join #ShipData t6 on t1.ZDCODE = t6.ZDCODE
left join t5 on t1.ZDCODE = t5.ZDCODE
--where Factory is not null
order by t1.ZDCODE
for json path ,include_null_values
--,GxNo

--000060047349	2
--000060048004	2
--000060048375	2
--000060049165	3
--000060049174	2
--000060049199	2
--000060049408	4
--000060049763	2
--000060050041	2
--000060050049	3
--000060050238	2
--000060050535	2
--000060050890	2
--000060051034	2
--000060051512	2
--000060051513	2
--000060051548	2
--000060051607	2
--000060051609	2
--000060051642	2
--000060051749	2
--000060051847	2
--000060051906	3
--000060052141	2
--000060052369	2
--000060052431	2
--000060052456	2
--000060052484	2
--000060052540	2
--000060052541	2
--000060052811	2
--000060053068	2
--000060053597	2
--000060053820	2