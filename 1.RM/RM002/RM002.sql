USE [ETSDB_Regina]
GO
/****** Object:  StoredProcedure [dbo].[SP_LL_FacD_PRE]    Script Date: 11/22/2021 10:19:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[SP_RM002]
@SaleNo nvarchar(20) = 'A160119250'
as
SET nocount on;
-- SaleOrder Info
drop table if exists #OrderInfors;
select a.CUSTNAME,
	a.STYLE_NO,
	a.SaleNo,
	a.SOItemNo,
	a.ZDCODE,
	a.Take_Date,
	b.COLOR_NO,
	b.COLOR_NAME_C,
	b.CM,
	sum(b.MY_COUNT) as MO_qty 
into #OrderInfors
from T_SCZZD(nolock) a
inner join TB_MK_ZD_COLOR_SIZE(nolock) b on a.SID=b.CNID
where SaleNo= @SaleNo
and LEFT(ZDCODE,6) in ('000020','000077')
group by a.CUSTNAME,a.SaleNo,a.STYLE_NO,a.SOItemNo,a.ZDCODE,a.Take_Date,b.COLOR_NO,b.COLOR_NAME_C,b.CM;

-- Create ZDCode list
drop table if exists #Zdcodes;
select distinct ZDCODE 
into #Zdcodes
from #OrderInfors 


drop table if exists #StoreIOs;
select * 
into #StoreIOs
from T_StoreInOutFlow(nolock) 
where Zdcode in (select * from #Zdcodes where Zdcode like N'000077%')
and StoreNo in ('DCUT','DPMT-PRT-01','DMOD01','DMOD02','DTSW618','D618FQC','DTSW1');

with t0 as(
	select sid,ROW_NUMBER() over (partition by StoreNo,Zdcode,BundleId,State order by BillDate) as RN
	from #StoreIOs
)
delete from #StoreIOs where sid in (select sid from t0 where RN > 1);

drop table if exists #FoamStoreIOs;
select * 
into #FoamStoreIOs
from T_StoreInOutFlow(nolock) 
where Zdcode in (select * from #Zdcodes where Zdcode like N'000020%')
and StoreNo in ('DTSW1')
and WorklayerNo in (9000,9900)
and State = 1;

with t0 as(
	select sid,ROW_NUMBER() over (partition by StoreNo,Zdcode,BundleId,State order by BillDate) as RN
	from #FoamStoreIOs
)
delete from #FoamStoreIOs where sid in (select sid from t0 where RN > 1);


drop table if exists #CombinedOrderInfors;
select CUSTNAME as CustomerName
	,STYLE_NO as StyleNo
	,SaleNo,SOItemNo
	,Zdcode
	,cast('' as nvarchar(16)) as FoamZdcode
	,Take_Date as ShipDate
	,COLOR_NO as ColorNo
	,COLOR_NAME_C as  ColorName
	,CM as Size
	,MO_qty as MOQuantity
into #CombinedOrderInfors
from #OrderInfors
where ZDCODE like N'000077%'
order by SaleNo,SOItemNo,COLOR_NO,CM;


update #CombinedOrderInfors 
set FoamZDcode = tb.ZDCODE
from #CombinedOrderInfors ta 
inner join #OrderInfors tb on ta.SaleNo = tb.SaleNo and ta.SOItemNo = tb.SOItemNo and tb.ZDCODE not like N'000077%'
;

select (
select * 
from #CombinedOrderInfors
for json path
) as [Value]
union all 

select (
select StoreNo,Zdcode,ColorNo,CM as Size
	,Sum(case when State = 1 then Ccount else 0 end) as TotalIn 
	,Sum(case when State = 2 then Ccount else 0 end) as TotalOut
from #StoreIOs
group by StoreNo,Zdcode,ColorNo,CM 
order by Zdcode
for json path
) as [Value]
union all 
select (
select StoreNo,Zdcode,ColorNo,CM as Size
	,Sum(Ccount) as TotalIn
from #FoamStoreIOs
group by StoreNo,Zdcode,ColorNo,CM
order by Zdcode
for json path
) as [Value]
