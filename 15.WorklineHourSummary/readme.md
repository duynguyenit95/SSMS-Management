# Usage

- WorklineHourSummary

# API 

- URL: /ChartData/GetWorklineHourSummary

### Input 

- [Required] string lines : Can input multiple workline , each workline is separated by a comma ','  
- [Required] string gxNo : Can input multiple gxNo , each gxNo is separated by a comma ','  
- [Required] string qcGxNo : Can input multiple qcGxNo , each qcGxNo is separated by a comma ','  
- [Optional] string gxName = "" : Can input multiple gxName , each gxName is separated by a straight line '|'    
- [Optional] string etsServer = "" : input single ETS Server Name ETSHY or ETSHP or ETSFW . Used to filter GxName Reference for specific ETS Server

### Output
	Return JSON string represent #Output Data

# Store Input Param 

 - @pWorkline nvarchar(max) = 'UPP1-L4', -- Required. Worklines to filter data  
 - @pQcGxNo nvarchar(max) = '5300', --Required. QcgxNo to filter Data  
 - @pGxNo nvarchar(max) = '5213,5214', --Required. GxNo to filter Data   
 - @pGxName nvarchar(max) = '', -- Optional. GxName to filter data .   
 - @pETServer nvarchar(10) = '' -- Optional. Ignore if @pGxName = blank. Value must be : ETSHY ( Hung Yen ETS) , ETSHP ( Hai Phong ETS) , ETSFW ( Hai Phong Footware ETS)   


# Output Data 

- Workline nvarchar -- Workline    
- TimeString nvarchar -- Working time    
- [Target] int  -- Target    
- [Output] int -- Output 
- TotalSAM  decimal -- SAM   
- TotalWorkTime decimal -- WorkTime   