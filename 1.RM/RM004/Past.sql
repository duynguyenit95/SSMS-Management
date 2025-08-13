USE [ROS]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[SP_LL_RM004_Past]
 @WorkDate date,
 @pFactory nvarchar(max) = '',
 @pDepartment nvarchar(max) = '',
 @pWorkShop nvarchar(max) = '',
 @StyleNo nvarchar(max) = ''
AS 

DECLARE @Workshop table(workshop nvarchar(10));
DECLARE @Department table(dept nvarchar(10));


insert into @Workshop
select * from string_split(@pWorkShop,',')

insert into @Department
select * from string_split(@pDepartment,',')

select * 
from RM004Data (nolock) 
where 1 = 1
and WorkDate = @WorkDate
and (Factory = @pFactory OR @pFactory = '')
and (Dept in (select * from @Department) OR @pDepartment = '')
and (Workshop in (select * from @Workshop) OR @pWorkShop = '')
and (StyleNo like N'%'+@StyleNo+'%' OR @StyleNo = '') 
for json path,include_null_values