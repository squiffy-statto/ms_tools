/*******************************************************************************
| Name       : ms_tools_example1.sas
| Purpose    : Example of parallel coding using MS_TOOLS.
| SAS Version: 9.4 
| Created By : T Drury (squiffy-statto)
| Date       : 01JUN19
| Notes      : Very simple example simulating type 1 error for two MMRM models
********************************************************************************/;

*****************************************************************************;
*** SET UP ENVIRONMENT                                                    ***;
*****************************************************************************;

*** INCLUDE SAS FUNCTIONS AND MACROS IF NOT BEHIND A PROXY ***;
options nosource2;
filename codelib1 url "https://raw.githubusercontent.com/squiffy-statto/sim_tools/master/sim_tools.sas";
filename codelib2 url "https://raw.githubusercontent.com/squiffy-statto/ms_tools/master/ms_tools.sas";
%inc codelib1;
%inc codelib2;


*****************************************************************************;
*** CREATE WRAPPER MACRO WITH SIMULATION AND ANALYSIS CODE                ***;
*****************************************************************************;

%macro analysis_code(nsim=, nsub=, mainseed=);

*** UPDATE SEED USING MS_TOOLS AUTO MVAR MS_N (MS SESSION NUMBER) ***;
%let seed = %sysevalf(&mainseed. + &ms_n.);

*** SIMULATE REPEATED MEASURES DATA ***;
proc iml;

 m1 = {0, 0, 0, 0};              *** MEAN VECTOR FOR PLACEBO ***;
 m2 = {0, 0, 0, 0};              *** MEAN VECTOR FOR ACTIVE  ***;
 s  = {1, 2, 3, 4};              *** SAME SD VECTOR ***;
 r  = {1.0 0.7 0.5 0.3, 
       0.7 1.0 0.6 0.4,
       0.5 0.6 1.0 0.5,
       0.3 0.4 0.5 1.0};         *** SAME CORRELATION MATRIX ***;
 vc = diag(s) * r * diag(s);     *** SAME VC MATRIX ***;

 call randseed(&seed.);

 plb  = randnormal(&nsim.*&nsub., m1, vc);       *** CREATE PLACEBO DATA VECTOR ***;
 act  = randnormal(&nsim.*&nsub., m2, vc);       *** CREATE ACTIVE DATA VECTOR ***;
 sub  = colvec(repeat(t(1:&nsub.),&nsim.));      *** CREATE SUBJECT VECTOR ***;
 sim  = colvec(repeat(t(1:&nsim.), 1, &nsub.));  *** CREATE SIMULATION VECTOR ***;

 trt  = colvec(repeat(1, &nsim.*&nsub.));        *** CREATE FIRST TREATMENT VECTOR ***;
 mvn1 = (trt || sim || sub || plb);              *** CONCATENATE VECTORS INTO MATRIX ***;

 trt  = colvec(repeat(2, &nsim.*&nsub.));        *** CREATE SECOND TREATMENT VECTOR ***;
 mvn2 = (trt || sim || sub || act);              *** CONCATENATE VECTORS INTO MATRIX ***;
 mvn  = mvn1 // mvn2;                            *** STACK BOTH TREATMENT MATRICES ***;

 create simulations1 from mvn[c={"trt" "sim" "sub" "y1" "y2" "y3" "y4"}];  *** CREATE DATASET ***;
 append from mvn;

quit;

*** TRANSPOSE INTO REPEATED MEASURES FORMAT ***;
data simulations2 (keep = trt sim sub seed time base chg);
  set simulations1;
  by trt;

  seed  = &seed.;
  array y[3] y2 y3 y4;
  do i = 1 to 3;
    base = y1;
    chg  = y[i] - base;
    time = i;
    output;
  end; 

run;

*** SORT BY SIM FOR ANALYSIS ***;
proc sort data = simulations2;
  by sim trt sub;
run;

ods select none;
ods results off;
ods graphics off;
options nonotes;

*** FIT RM MODEL WITH COMPOUND SYMMETRY VC ***;
proc mixed data = simulations2;
  by sim;
  class trt time;
  model chg = trt*time base*time / noint ddfm=kr;
  repeated time / subject=sub type=cs;
  lsmeans trt*time / diff=all;
  ods output diffs=dif1;
run;

*** FIT RM MODEL WITH UNSTRUCTURED VC ***;
proc mixed data = simulations2;
  by sim;
  class trt time;
  model chg = trt*time base*time / noint ddfm=kr;
  repeated time / subject=sub type=un;
  lsmeans trt*time / diff=all;
  ods output diffs=dif2;
run;

options notes;
ods select all;
ods results on;
ods graphics on;

*** STACK DIFFS AND CALCULATE SUCCESS AT FINAL TIMEPOINT ***;
data dif;
  set dif1 (in = in1 where=(time=3 and _time=3))
      dif2 (in = in2 where=(time=3 and _time=3));
  if in1 then do;
    modelcd = 1;
	model   = "CS VC Matrix";
  end;
  else if in2 then do;
    modelcd = 2;
    model   = "UN VC Matrix";
  end;
  success = ifn((probt lt 0.05) and estimate>0, 1, 0);
run;

%mend;


*****************************************************************************;
*** SET UP 4 REMOTE SESSION AND CALL THE MACRO IN EACH TO RUN 12500  SIMS ***;
*****************************************************************************;

%starttime(startid=PARALLEL);


*** OPEN MULTIPLE REMOTE SAS SESSIONS ***;
%ms_signon(sess_n=4);

*** CALL ANALYSIS MACRO IN ALL REMOTE SESSIONS ***;
%ms_macrocall(macro_name = analysis_code                                /*** MACRO TO CALL IN REMOTE SESSIONS ***/
             ,mparm_list = %str(nsim=12500, nsub=50, mainseed=12345000) /*** PARAMETERS FOR MACRO CALLS ***/
             ,keep_list  = %str(dif)                                    /*** REMOTE WORK DATASETS TO COPY BACK INTO MAIN WORK ***/
             ,sign_off   = Y);                                          /*** SIGN OFF AND CLOSE REMOTE SESSION WHEN COMPLETED ***/


*****************************************************************************;
*** STACK ALL 4 DIF DATA RESULTS INTO A SINGLE DATASET                    ***;
*****************************************************************************;

data dif_all2;
  set dif_rs1
      dif_rs2
      dif_rs3
      dif_rs4;
run;

*** AVERAGE OVER SUCCESS TO CALCULATE THE TYPE 1 ERROR FOR EACH MODEL ***;
proc means data = dif_all2 nway noprint;
  class model;
  var success;
  output out  = results2 
         n    = nsims 
         mean = type1; 
run;

%stoptime(startid=PARALLEL);


*****************************************************************************;
*** SHOW RESULTS                                                          ***;
*****************************************************************************;

*** PRINT SERIAL RESULTS ***;
proc print data = results1 noobs;
  var model nsims type1;
  title1 h=5 "Simulation of type 1 error - serial";
run;

*** PRINT PARALLEL RESULTS ***;
proc print data = results2 noobs;
  var model nsims type1;
  title1 h=5 "Simulation of type 1 error - parallel";
run;

title;
