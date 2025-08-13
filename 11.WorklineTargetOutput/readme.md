# Usage

- WorklineTargetOutput

# API 

- URL: /Data/GetWorkshopLineTargetOutput

## Input 

- [Required] string lines : Can input multiple workline , each workline is separated by a comma ','  
- [Required] string gxNo : Can input multiple gxNo , each gxNo is separated by a comma ','  
- [Optional] string gxName = "" : Can input multiple gxName , each gxName is separated by a straight line '|'    
- [Optional] string etsServer = "" : input single ETS Server Name ETSHY or ETSHP or ETSFW . Used to filter GxName Reference for specific ETS Server

## Output
	Return JSON string represent #Output Data

# Store Input Param 

 - @pWorkline nvarchar(max) = 'UPP1-L4', -- Required. Worklines to filter data  
 - @pQcGxNo nvarchar(max) = '5300', --Required. QcgxNo to filter Data  
 - @pGxName nvarchar(max) = '', -- Optional. GxName to filter data .   
 - @pETServer nvarchar(10) = '' -- Optional. Ignore if @pGxName = blank. Value must be : ETSHY ( Hung Yen ETS) , ETSHP ( Hai Phong ETS) , ETSFW ( Hai Phong Footware ETS)  


# Output Data 

- Workline nvarchar -- Workline 
- [TargetQty] int  -- Target  
- [OutputQty] int -- Output 
