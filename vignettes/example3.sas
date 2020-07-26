/*******************************************************************************
|
| Program Name   : example2.sas
| Program Purpose: demonstrates using ms_tools macros to parallel process
| SAS Version    : 9.4  
| Created By     : Thomas Drury
| Date           : 25-07-20 
|
|-------------------------------------------------------------------------------
| Notes:
|
| Code uses example data from missingdata.org website hosted by from London 
| School of Hygiene and Tropical Medicine (LSHTM). 
|
| Performs MI and then splits data between multiple remote sessions for analysis
|
*********************************************************************************/;

*********************************************************************************;
*** SECTION 1: SET UP                                                         ***;
*********************************************************************************;


*** INCLUDE MULTI SESSION TOOLS ***;
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\ms_tools\ms_tools.sas";


*** SET UP LIBNAME ***;
libname adata "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\ms_tools\data" access=readonly;



*********************************************************************************;
*** SECTION 2: READ IN AND PERFORM MAR MULTIPLE IMPUTATION DATA               ***;
*********************************************************************************;

*** READ IN DATA ***;
proc sort data = adata.high1
          out  = ds1;
  by patient trt basval week;
run;


*** TRANSPOSE DATA FOR MI ***;
proc transpose data   = ds1
               out    = ds1t
               prefix = week;
  by patient trt basval;
  var change;
  id week;
run;


*** PERFORM MAR MI IMPUTATION ***;
ods select none;
proc mi data    = ds1t
        out     = mi1 (rename=(_imputation_ = imputation))
        nimpute = 1000;
  var week:;
run;
ods select all;

*** TRANSPOSE BACK TO ANALYSIS STRUCTURE ***;
proc transpose data = mi1
               out  = mi1t;
  by imputation patient trt basval;
  var week:;
run;


*** CREATE ANALYSIS VARIABLES ***;
data ds2;
  set mi1t;
  week = input(tranwrd(_name_, "week", ""),best8.);
run;


*********************************************************************************;
*** SECTION 3: CREATE ANALYSIS CODE TO RUN IN PARALLEL IN A WRAPPER MACRO     ***;
*********************************************************************************;

%macro mmrm1();
 
  ods select none;
  ods graphics off;
  ods results off;

  proc mixed data = ds2;
    by imputation;
    class trt week;
    model change = trt*week basval*week / noint;
    repeated week / subject = patient type = un;
    lsmeans trt*week / diff=all;
    ods output lsmeans = lsm;
	ods output diffs = dif (where = (week = _week));
  run;

  ods select all;
  ods graphics on;
  ods results on;

%mend;



*********************************************************************************;
*** SECTION 4: SET UP MUTLIPLE SESSIONS AND RUN CODE IN PARALLEL              ***;
*********************************************************************************;

*** SET UP 4 REMOTE SESSIONS ***;
%ms_signon(sess_n = 4
          ,prefix = ms);


*** SPLIT ANALYSIS DATA INTO EACH SESSION ***;
%ms_splitdata(indata    = ds2
             ,sess_list = %str(ms1, ms2, ms3, ms4)
             ,bvar_list = %str(imputation));


*** CALL WRAPPER MACRO IN EACH SESSION ***;
%ms_macrocall(macro_name = mmrm1
             ,keep_list  = %str(lsm, dif));



*********************************************************************************;
*** SECTION 5: STACK LSM AND DIF DATA AND COMBINE USING RUBINS RULES          ***;
*********************************************************************************;

*** STACK DATASETS ***;
data lsm1;
  set lsm_ms1
      lsm_ms2
      lsm_ms3
      lsm_ms4;
  by imputation;
run;

data dif1;
  set dif_ms1
      dif_ms2
      dif_ms3
      dif_ms4;
  by imputation;
run;


*** SORT FOR MI ANALYZE ***; 
proc sort data = lsm1;
  by trt week imputation;      
run;       
       
proc sort data = dif1;
  by trt _trt week _week imputation;      
run;       


ods select none;
proc mianalyze data = lsm1;
  by trt week;
  modeleffects estimate;
  stderr stderr;
  ods output parameterestimates = lsm_mia;   
run;

proc mianalyze data = dif1;
  by trt _trt week _week;  
  modeleffects estimate;
  stderr stderr;
  ods output parameterestimates = dif_mia;   
run;
ods select all;


*********************************************************************************;
*** SECTION 6: PRINT RESULTS AND TIDY UP MAIN WORK LIBRARY                    ***;
*********************************************************************************;


*** PRINT RESULTS ***;
proc print data = lsm_mia;
  var trt week nimpute estimate stderr lclmean uclmean;  
  title1 "RM LSM estimates with MAR MI performed";
run;  

proc print data = dif_mia;
  var trt _trt week _week nimpute estimate stderr lclmean uclmean;  
  title1 "RM LSM differences with MAR MI performed";
run;  
  

*** TIDY UP MAIN WORK AREA ***;
proc datasets lib = work nolist;
  delete ds: mi: lsm: dif:;
quit;

