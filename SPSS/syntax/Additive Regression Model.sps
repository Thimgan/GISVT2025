* Encoding: windows-1252.
     
OUTPUT NEW.

DEFINE !BASE () 'C:\Users\Brad\GISVT2025\SPSS\' !ENDDEFINE.
DEFINE !SINTAX () !BASE + 'Syntax\' !ENDDEFINE.
DEFINE !DATA() !BASE + 'Data\' !ENDDEFINE.
DEFINE !TEMPLATE() !BASE + 'Template\' !ENDDEFINE.

GET FILE= !DATA + 'GISValTechSampleData.sav'.
DATASET NAME DataSet1 WINDOW=FRONT.

COMPUTE SPPSF =  SalesPrice /  Sqft.

MEANS TABLES=SPPSF BY Quality NBHD
  /CELLS=COUNT MEAN MEDIAN STDDEV.

COMPUTE SYEAR = XDATE.YEAR(SaleDate).
COMPUTE SMONTH = XDATE.MONTH(SaleDate).
FORMATS SYEAR (F4.0) SMONTH (F2.0).
COMPUTE SDATE = DATE.MOYR(SMONTH,SYEAR).
FORMATS SDATE  (MOYR6).

CROSSTABS SMONTH BY SYEAR.

*ENTER YOUR STARTING DATE, BASE VALUATION DATE - FORMAT IS MONTH THEN YEAR.
COMPUTE #STARTDATE = DATE.MOYR(1,2023).
COMPUTE #BASEDATE = DATE.MOYR(12,2023).
COMPUTE #TIMEPERIOD = DATEDIFF(#BASEDATE,#STARTDATE,"MONTHS") .
COMPUTE MONTHS = DATEDIFF(SDATE,#STARTDATE,"MONTHS") .
COMPUTE MONTH = #TIMEPERIOD - MONTHS.

COMPUTE MONTHSSF = MONTHS * SQFT.

* LandSize.
IF(LandSize GT 0)LN_LandSize = LN(LandSize).
IF(LandSize GT 0)LandSize25 = LandSize**.25.
IF(LandSize GT 0)LandSize50 = LandSize**.50. /* this transformation is best.
IF(LandSize GT 0)LandSize75 = LandSize**.75.
RECODE LN_LandSize TO LandSize75 (SYSMIS = 0).

* Quality Grade.
RECODE Quality("Poor" = 1)(ELSE=0) INTO Quality_Poor. /* 64 SALES. 
RECODE Quality("BelowAverage" = 1)(ELSE=0) INTO Quality_BelowAverage. /* 247 SALES. 
RECODE Quality("Average" = 1)(ELSE=0) INTO Quality_Average. /* 271 SALES - Base. 
RECODE Quality("AboveAverage" = 1)(ELSE=0) INTO Quality_AboveAverage. /* 180 SALES. 
RECODE Quality("Superior" = 1)(ELSE=0) INTO Quality_Superior. /* 60 SALES.

* Sqft.
COMPUTE SQFT_Poor = Sqft * Quality_Poor.
COMPUTE SQFT_BelowAverage = Sqft * Quality_BelowAverage.
COMPUTE SQFT_Average = Sqft * Quality_Average.
COMPUTE SQFT_AboveAverage = Sqft * Quality_AboveAverage.
COMPUTE SQFT_Superior = Sqft * Quality_Superior.

*Bathrooms.

COMPUTE EffageADJ = Effage.
RECODE Effage EffageADJ(LOWEST THRU 0 EQ 0).  
RECODE EffageADJ(60 THRU HIGHEST EQ 60).  

COMPUTE EffageSF75 = EffageADJ * Sqft**.75. /* this transformation is best.

* Normally, would tie quality grade to bathrooms, effective age and garage, but kept model simple.

*GarageSize.

*NBHD.
* Note:  Had to go with NBHD 105 to get constant positive - normally would have used 103.
RECODE NBHD (101 = 1)(ELSE=0) INTO NBHD101. /* 137 SALES. 
RECODE NBHD (102 = 1)(ELSE=0) INTO NBHD102. /* 215 SALES. 
RECODE NBHD (103 = 1)(ELSE=0) INTO NBHD103. /* 258 SALES. 
RECODE NBHD (104 = 1)(ELSE=0) INTO NBHD104. /* 124 SALES.
 * RECODE NBHD (105 = 1)(ELSE=0) INTO NBHD105. /* 88 SALES - Base. 

*REGRESSION RUN. 

oms select tables
 /destination format = sav numbered = 'table_number' outfile = !DATA + "RegressionSummaryAdditive.sav"
 /if commands = ['regression'] subtypes = ['Model Summary']
 /tag = "model_summary".

oms select tables
 /destination format = sav numbered = 'table_number' outfile = !DATA + "RegressionCoeficientsAdditive.sav"
 /if commands = ['regression'] subtypes = ['Coefficients','Excluded Variables']
 /tag = "reg".

REGRESSION
    /VARIABLES = SalesPrice MONTHSSF
         SQFT_Poor SQFT_BelowAverage SQFT_Average SQFT_AboveAverage SQFT_Superior
         LandSize50 EffageSF75 Bathrooms GarageSize
         NBHD101 NBHD102 NBHD103 NBHD104
    /CRITERIA=PIN(.10) POUT (.20)
    /DESCRIPTIVES=MEAN STDDEV
  /STATISTICS COEFF OUTS CI(95) R ANOVA
    /DEPENDENT=SalesPrice
    /METHOD=BACKWARD
    /SAVE PRED(ESP) RESID ZRESID.
omsend.

COMPUTE RATIO = ESP / SalesPrice.

FORMATS ESP (COMMA10.0).

SAVE OUTFILE !DATA + 'REGRESSIONAdditive.SAV'.

******************************************************************************.
* PRB FOR OVERALL MODEL.
DEFINE !VARIABLE2() SalesPrice !ENDDEFINE.
DEFINE !VARIABLE3() ESP !ENDDEFINE.
DEFINE !VARIABLE4() RATIO !ENDDEFINE.

COMPUTE OVERALL = 1.
AGGREGATE
  /OUTFILE=* MODE=ADDVARIABLES
  /BREAK=OVERALL
  /RATIO_MEDIAN=MEDIAN(!VARIABLE4).

COMPUTE VALUE=.50*!VARIABLE2+.50*(!VARIABLE3/RATIO_MEDIAN).
COMPUTE Ln_value=LN(VALUE)/.693.
COMPUTE pct_diff=(!VARIABLE4-RATIO_MEDIAN)/RATIO_MEDIAN.

REGRESSION /DEPENDENT = pct_diff /METHOD = ENTER Ln_value.

GRAPH  /SCATTERPLOT(BIVAR)= Ln_value WITH pct_diff
  /MISSING=LISTWISE.

******************************************************************************.
*REGRESSION SUMMARY.
GET FILE= !DATA + 'RegressionSummaryAdditive.sav'.
DATASET NAME DataSet1 WINDOW=FRONT.

AGGREGATE
  /OUTFILE=* MODE=ADDVARIABLES
  /BREAK=
  /MaxRun=MAX(Var1).
*Select If(var1 EQ maxrun).
RENAME VARIABLES var1 = Model.
EXECUTE.

SUMMARIZE
  /TABLES=Model R RSquare AdjustedRSquare Std.ErroroftheEstimate 
  /FORMAT=VALIDLIST NOTOTAL NOCASENUM 
  /cells = NONE
  /TITLE='Model Summary'
  /MISSING=VARIABLE.

GET FILE= !DATA + 'RegressionCoeficientsAdditive.sav'.
DATASET NAME DataSet1 WINDOW=FRONT.

VARIABLE LABELS  B ' ' Std.Error ' ' Beta ' ' t ' ' Sig ' '.

AGGREGATE
  /OUTFILE=* MODE=ADDVARIABLES
  /BREAK=
  /MaxRun=MAX(Var1).

RENAME VARIABLES var2 = Name.
Select If(var1 EQ maxrun).
Execute.

TEMPORARY .
  Select If(label_ EQ 'Coefficients').
  SUMMARIZE
  /TABLES=Name B Std.Error Beta t Sig
  /FORMAT=VALIDLIST NOTOTAL NOCASENUM
  /cells = NONE
  /TITLE='Coefficients'
  /MISSING=VARIABLE.

SORT CASES by name.

TEMPORARY .
Select If(label_ EQ 'Excluded Variables').
SUMMARIZE
  /TABLES=Name t
  /FORMAT=VALIDLIST NOTOTAL NOCASENUM
  /cells = NONE
  /TITLE='Excluded Coefficients'
  /MISSING=VARIABLE.

OMSEND.

DATASET ACTIVATE DataSet1.

******************************************************************************.
GET FILE= !DATA + 'REGRESSIONAdditive.SAV'.
DATASET NAME DataSet1 WINDOW=FRONT.


RATIO STATISTICS ESP WITH SalesPrice BY SYEAR 
 /Print = MEAN MEDIAN WGTMEAN MIN MAX COD PRD.

GRAPH  /SCATTERPLOT(BIVAR)=SDATE WITH RATIO
  /MISSING=LISTWISE
  /TEMPLATE = !TEMPLATE + 'Loess2019.sgt'.

GRAPH  /SCATTERPLOT(BIVAR)=Sqft WITH RATIO
  /MISSING=LISTWISE
  /TEMPLATE = !TEMPLATE + 'Loess2019.sgt'.

GRAPH  /SCATTERPLOT(BIVAR)=LandSize WITH RATIO
  /MISSING=LISTWISE
  /TEMPLATE = !TEMPLATE + 'Loess2019.sgt'.

GRAPH  /SCATTERPLOT(BIVAR)=EFFAGE WITH RATIO
  /MISSING=LISTWISE
  /TEMPLATE = !TEMPLATE + 'Loess2019.sgt'.

GRAPH  /SCATTERPLOT(BIVAR)=Bathrooms WITH RATIO
  /MISSING=LISTWISE
  /TEMPLATE = !TEMPLATE + 'Loess2019.sgt'.

TEMPORARY.
SELECT IF(GarageSize GT 0).
GRAPH  /SCATTERPLOT(BIVAR)=GarageSize WITH RATIO
  /MISSING=LISTWISE
  /TEMPLATE = !TEMPLATE + 'Loess2019.sgt'.

MEANS RATIO BY Quality NBHD /CELLS MEAN MEDIAN MIN MAX COUNT.

TEMPORARY.
SELECT IF(SYEAR GE 2022).
MEANS RATIO BY SDATE /CELLS MEAN MEDIAN MIN MAX COUNT.

SORT CASES BY NBHD (A) RATIO (A).

TEMPORARY.
SELECT IF(RATIO GE 1.5).
SUMMARIZE
  /TABLES= ParcelId SaleDate SalesPrice RATIO ESP Sqft LandSize Bathrooms Quality GarageSize EFFAGE NBHD  
  /FORMAT=VALIDLIST NOCASENUM TOTAL
  /TITLE='RATIO GT 1.5'
  /MISSING=VARIABLE
  /CELLS=COUNT.

TEMPORARY.
SELECT IF(RATIO LT .65).
SUMMARIZE
  /TABLES= ParcelId SaleDate SalesPrice RATIO ESP Sqft LandSize Bathrooms Quality GarageSize EFFAGE NBHD  
   /FORMAT=VALIDLIST NOCASENUM TOTAL
  /TITLE='RATIO LT .65'
  /MISSING=VARIABLE
  /CELLS=COUNT.

