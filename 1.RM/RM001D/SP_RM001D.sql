CREATE OR ALTER Procedure SP_RM001D 
 @inpZDCODE nvarchar(max) = '000077032488,000077026102',
 @inpStartStoreNo nvarchar(16) = 'DCUT'
as
SET NOCOUNT ON;

DECLARE @ZDCodes Table(Zdcode nvarchar(16))
insert into @ZDCodes
select * from tom_splitstring(@inpZDCODE,',')


-- SaleOrder Info
drop table if exists #OrderInfors;
select a.CUSTNAME CustomerName
	,a.STYLE_NO StyleNo
	,a.SaleNo,a.SOItemNo
	,a.ZDCODE Zdcode
	,a.Take_Date ShipDate
	,COLOR_NO as ColorNo
	,COLOR_NAME_C as  ColorName
	,CM as Size
	,sum(b.MY_COUNT) as MOQuantity 
into #OrderInfors
from T_SCZZD(nolock) a
inner join TB_MK_ZD_COLOR_SIZE(nolock) b on a.SID=b.CNID
where Zdcode in (select * from @ZDCodes)
group by a.CUSTNAME,a.SaleNo,a.STYLE_NO,a.SOItemNo,a.ZDCODE,a.Take_Date,b.COLOR_NO,b.COLOR_NAME_C,b.CM;


-- Get Store IOs
drop table if exists #StoreIOs;
select cast('' as nvarchar(16)) as StoreGroup,* 
into #StoreIOs
from T_StoreInOutFlow(nolock) 
where Zdcode in (select * from @ZDCodes)
and StoreNo in (
'DCUT','DCUT-LAS1','DMOD01','DMOD02'
,'DPMT-PRT-01','DPMT-STR-01','DPMT-WIG1'
,'DCUT618','DTSW618','618DMOD1','618DMOD2','618DMOD3'
,'DMOD123','618DMDI1','618DMDI2','618DMDI3','D618FQC'
);
-- Remove Duplication in/out bundle by Store/Bundle/State -
with t1 as(
	select *,ROW_NUMBER() over (partition by StoreNo,Zdcode,BundleId,[State] order by BillDate) as RN
	from #StoreIOs
)
delete from #StoreIOs
where sid in (select sid from t1 where RN > 1);

update #StoreIOs set StoreGroup = case when StoreNo like N'%DCUT%' then N'DCUT'
									   when StoreNo like N'%618MOD%' then N'618MOD'
									   when StoreNo = 'DTSW618' then StoreNo
									   when StoreNo like N'%DMOD%' then N'DMOD'
									   when StoreNo like N'%TSW%' then N'TSW'
									   else StoreNo end 

-- Summary IO data
select StoreNo
	,Zdcode
	,ColorNo
	,CM as Size
	,WorklayerNo
	,WorklayerName
	,Sum(case when State = 1 then Ccount else 0 end) as TotalIn
	,Sum(case when State = 2 then Ccount else 0 end) as TotalOut
into #StoreIOSummaries
from #StoreIOs
group by StoreNo,Zdcode,ColorNo,CM,WorklayerNo,WorklayerName;

-- Store Group Summary
select  StoreGroup,StoreNo
	,Zdcode
	,ColorNo
	,CM as Size
	,WorklayerNo
	,WorklayerName
	,Sum(case when State = 1 then Ccount else 0 end) as TotalIn
	,Sum(case when State = 2 then Ccount else 0 end) as TotalOut
into #StoreGroupIOSummaries
from #StoreIOs
group by StoreGroup,StoreNo,Zdcode,ColorNo,CM,WorklayerNo,WorklayerName;


-- Analyze Other Stores In from Input Store No
with t1 as(
select Bundleid,Billdate
from #StoreIOs
where StoreNo like N'%'+@inpStartStoreNo+'%' 
and State = 2
)
select 'Other' as StoreGroup 
	,'Other' as StoreNo
	,Zdcode
	,ColorNo
	,CM as Size
	,WorklayerNo
	,WorklayerName
	,Sum(Ccount) as TotalIn
	,0 as TotalOut
into #GroupOtherStoreIOs
from #StoreIOs ta 
inner join t1 on t1.Bundleid = ta.Bundleid and ta.Billdate >= t1.Billdate and ta.StoreNo != @inpStartStoreNo and ta.State = 1
group by Zdcode
	,ColorNo
	,CM
	,WorklayerNo
	,WorklayerName;

select distinct WorklayerNo,WorklayerName
into #Worklayers
from #StoreIOs
where StoreNo like N'%'+@inpStartStoreNo+'%' 

select (select * from #OrderInfors for json path) as [Value]
union all
select (
	select * 
	from (
		select * from #StoreGroupIOSummaries 
		union all
		select * from #GroupOtherStoreIOs
	) as ta for json path
) as [Value]
union all
select (select * from #StoreIOSummaries for json path) as [Value]
union all
select (select * from #Worklayers for json path) as [Value]