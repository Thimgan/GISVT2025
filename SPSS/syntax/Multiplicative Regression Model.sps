* Encoding: windows-1252.
     
OUTPUT NEW.

DEFINE !BASE () 'C:\Users\Brad\GISVT2025\SPSS\' !ENDDEFINE.
DEFINE !SYNTAX () !BASE + 'Syntax\' !ENDDEFINE.
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

* Sqft.
COMPUTE LN_Sqft = LN(Sqft).

* LandSize.
IF(LandSize GT 0)LN_LandSize = LN(LandSize).

RECODE LN_LandSize (SYSMIS = 0).

* Quality Grade.
RECODE Quality("Poor" = 1)(ELSE=0) INTO Quality_Poor. /* 64 SALES. 
RECODE Quality("BelowAverage" = 1)(ELSE=0) INTO Quality_BelowAverage. /* 247 SALES. 
 * RECODE Quality("Average" = 1)(ELSE=0) INTO Quality_Average. /* 271 SALES - Using this as the Base quality grade. 
RECODE Quality("AboveAverage" = 1)(ELSE=0) INTO Quality_AboveAverage. /* 180 SALES. 
RECODE Quality("Superior" = 1)(ELSE=0) INTO Quality_Superior. /* 60 SALES.

*Bathrooms.
 * LN Bathrooms slightly outperforms straight bathrooms - I prefer this because bathrooms as is, is an exponential increase in value - natural log depreciates additional bathrooms.

IF(Bathrooms GT 0)LN_Bathrooms = LN(Bathrooms).
RECODE LN_Bathrooms (SYSMIS = 0). 

* Statistically, effective age works slightly better, but bias-wise, capping at 60 performs better.

COMPUTE EffageADJ = Effage.
RECODE Effage EffageADJ(LOWEST THRU 0 EQ 0).  
RECODE EffageADJ(60 THRU HIGHEST EQ 60).  

 * COMPUTE DEPRECIATION=Effage/100.
COMPUTE DEPRECIATION=EffageADJ/100.
COMPUTE PCT_GOOD=1-DEPRECIATION.
VARIABLE LABELS PCT_GOOD 'PERCENTAGE OF VALUE LEFT IN UNIT'.

COMPUTE LN_PCT_GOOD = LN(PCT_GOOD).
EXECUTE.

*GarageSize.
IF(GarageSize GT 0)LN_GarageSize = LN(GarageSize).
RECODE LN_GarageSize (SYSMIS = 0). /* This variable is best.

COMPUTE GarageSize_RATIO = 1 + (GarageSize / 480).
COMPUTE LN_GarageSize_RATIO = LN(GarageSize_RATIO).

*NBHD.
RECODE NBHD (101 = 1)(ELSE=0) INTO NBHD101. /* 137 SALES. 
RECODE NBHD (102 = 1)(ELSE=0) INTO NBHD102. /* 215 SALES. 
 * RECODE NBHD (103 = 1)(ELSE=0) INTO NBHD103. /* 258 SALES - Base.  
RECODE NBHD (104 = 1)(ELSE=0) INTO NBHD104. /* 124 SALES.
RECODE NBHD (105 = 1)(ELSE=0) INTO NBHD105. /* 88 SALES.

*REGRESSION RUN. 
Compute LN_SalesPrice = LN(SalesPrice).
EXECUTE .

oms select tables
 /destination format = sav numbered = 'table_number' outfile = !DATA + "RegressionSummary.sav"
 /if commands = ['regression'] subtypes = ['Model Summary']
 /tag = "model_summary".

oms select tables
 /destination format = sav numbered = 'table_number' outfile = !DATA + "RegressionCoeficients.sav"
 /if commands = ['regression'] subtypes = ['Coefficients','Excluded Variables']
 /tag = "reg".

REGRESSION
    /VARIABLES = 
        LN_SalesPrice
        MONTHS
        LN_Sqft Quality_Poor
        Quality_BelowAverage
        Quality_AboveAverage
        Quality_Superior
        LN_PCT_GOOD
        LN_Bathrooms
        LN_GarageSize
        NBHD101
        NBHD102
        NBHD104
        NBHD105
    /CRITERIA=PIN(.10) POUT (.20)
    /DESCRIPTIVES=MEAN STDDEV
  /STATISTICS COEFF OUTS CI(95) R ANOVA
    /DEPENDENT=LN_SalesPrice
    /METHOD=BACKWARD
    /SAVE PRED(PRED) RESID ZRESID.
omsend.

COMPUTE ESP = EXP(PRED).

COMPUTE RATIO = ESP / SalesPrice.

FORMATS ESP (COMMA10.0).

SAVE OUTFILE !DATA + 'REGRESSION.SAV'.

******************************************************************************.
* PRB FOR OVERALL MODEL.
DEFINE !VARIABLE2() SALESPRICE !ENDDEFINE.
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
  /MISSING=LISTWISE
  /TEMPLATE = !TEMPLATE + 'Loess2019.sgt'.

******************************************************************************.
*REGRESSION SUMMARY.
GET FILE= !DATA + 'RegressionSummary.sav'.
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

GET FILE= !DATA + 'RegressionCoeficients.sav'.
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
GET FILE= !DATA + 'REGRESSION.SAV'.
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
SELECT IF(RATIO LT .75).
SUMMARIZE
  /TABLES= ParcelId SaleDate SalesPrice RATIO ESP Sqft LandSize Bathrooms Quality GarageSize EFFAGE NBHD  
   /FORMAT=VALIDLIST NOCASENUM TOTAL
  /TITLE='RATIO LT .80'
  /MISSING=VARIABLE
  /CELLS=COUNT.

