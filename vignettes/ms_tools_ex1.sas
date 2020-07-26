/*******************************************************************************
|
| Program Name:    MS_TOOLS_EX1.sas
|
| Program Version: 1.0
|
| Program Purpose: Example of using MS_TOOLS library to parralel process code
|
| Program Notes:   !!!!!!!!!!!!!!! DO NOT USE OF HARP SERVERS !!!!!!!!!!!!!!!!!! 
|                  THIS CODE SETS MULTIPLE SESSIONS RUNNING IF MANY USERS DO 
|                  THIS IT COULD OVERWHELM THE SERVERS AND CAUSE IT TO CRASH. 
| 
| SAS Version:  9.4 HPC Servers & Remote Desktop or user version of PC SAS 
|
| Created By:   Thomas Drury: tad66240
| Date:         13-03-20 
|
|-------------------------------------------------------------------------------
| Notes:
| 1. This example uses MS_TOOLs macro MS_MACROCALL to call a sas macro
|    in multiple remote sessions. 
|
*********************************************************************************/;

**********************************************************************************;
*** SECTION 1: EXAMPLE USING STANDARD LINEAR PROCESSING                        ***;
**********************************************************************************;


*** INCLUDE SIMULATION TOOLS ***;
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\sim_tools\sim_tools.sas";
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\mvd_tools\mvd_tools.sas";

*** SET SIMULATION PARAMETERS ***;
%let seed = 12345;
%let nsim = 10000;


*** START SIMULATION TIMER ***;
%starttime(startid=LINEAR_START);

*** SIMULATE MVN DATA ***;
data simulations1;

  length sim size sub trt y1-y4 8;
  array y[4];
  array m1[4] _temporary_ (0 0 0 0);          *** MEAN VECTOR FOR PLACEBO ***;
  array m2[4] _temporary_ (0 0 0 0);          *** MEAN VECTOR FOR ACTIVE  ***;
  array vc[4,4] _temporary_ (1.0  1.4  1.5  1.2
                             1.4  4.0  3.6  3.2
                             1.5  3.6  9.0  6.0
                             1.2  3.2  6.0 16.0);  *** SAME VC MATRIX ***;

  do sim  = 1 to &nsim. by 1;
  do size = 5 to 50 by 5; 
  do sub  = 1 to size by 1; 

    trt = 1;
    call rand_mvn(y,m1,vc);
    output;
    trt = 2;
    call rand_mvn(y,m2,vc);
    output;

  end;
  end;
  end;
 
run;

*** TRANSPOSE INTO REPEATED MEASURES FORMAT ***;
data simulations2 (keep = sim size sub trt seed usub time base chg);
  set simulations1;
  by sim size sub trt;

  seed  = &seed.;
  usub  = ifn(trt=1, 1000 + sub, 2000 + sub);
  array y[3] y2 y3 y4;
  do i = 1 to 3;
    base = y1;
    chg  = y[i] - base;
	time = i;
	output;
  end; 

run;


*** FIT MIXED MODEL WITH TYPE=CS ***;
%odsoff(notesyn=N);
proc mixed data = simulations2;
  by sim size;
  class trt time;
  model chg = trt*time / noint;
  repeated time / subject=usub type=cs;
  estimate "Primary A vs. P" trt*time 0 0 -1 0 0 1 / alpha=0.05;
  ods output estimates = est_m1;
run;
%odson;

*** FIT MIXED MODEL WITH TYPE=UN ***;
%odsoff(notesyn=N);
proc mixed data = simulations2;
  by sim size;
  class trt time;
  model chg = trt*time base*time / noint;
  repeated time / subject=usub type=un;
  estimate "Primary A vs. P" trt*time 0 0 -1 0 0 1 / alpha=0.05;
  ods output estimates = est_m2;
run;
%odson;

*** STACK MODEL ESTIMATES AND FLAG THE SUCCESSES ***;
data est;
  set est_m1 (in = in1)
      est_m2 (in = in2);
  by sim size;
  if in1 then model = 1;
  else if in2 then model = 2;
  success = ifn(estimate > 0 and probt < 0.05, 1, 0);  *** SIGNIFICANT AND CORRECT DIRECTION ***;
  seed    = &seed.;
run;


*** SUMMARISE THE RESULTS ***;
proc means data = est;
  class size model;
  var success;
run;


*** DELETE UNWANTED WORK DATA ***;
proc datasets lib=work nolist;
  delete parameters1 simulations1 est_m1 est_m2;
quit;


*** STOP SIMULATION TIMER ***;
%stoptime(startid=LINEAR_START);






































*** SIMULATE DATA USING MCMC AND CONSTANT LIKELIHOOD ***;
%odsoff(notesyn=Y);
proc mcmc data    = parameters1
          outpost = simulations1 (keep = trt iteration x1-x4)
          nbi     = 0 
          nmc     = %sysevalf(&nsim.*&nsub.)
          seed    = &seed.;

  by trt;
  array x[4];
  array m[4];   
  array t1[4] (0 0 0 0);
  array t2[4] (0 1 2 3);
  array v[4,4] ( 1.0  1.4  1.5  1.2
                 1.4  4.0  3.6  3.2
                 1.5  3.6  9.0  6.0
                 1.2  3.2  6.0 16.0 );
  do i = 1 to 4;
    m[i] = t1[i]*(trt=1) + t2[i]*(trt=2);
  end;

  parms x;
  prior x ~ mvn(m,v);
  model general(1);

run;
%odson;


*** TRANSPOSE INTO REPEATED MEASURES FORMAT ***;
data simulations2 (keep = trt sim sub seed time base chg);
  set simulations1;
  by trt;

  seed  = &seed.;

  retain sub 0 sim 1;
  if first.trt then do;
    sim = 1;
	sub = 0;
  end;
  sub = sub + 1;
  if sub > 100 then do;
    sub = 1;
	sim = sim + 1;
  end;

  array x[3] x2 x3 x4;
  do i = 1 to 3;
    base = x1;
    chg  = x[i] - base;
	time = i;
	output;
  end; 

run;

proc sort data = simulations2;
  by sim trt time;
run;

/*proc print data = simulations2 (obs=10);*/
/*run;*/


*** STACK LSM MODEL RESULTS AND FLAG THE SUCCESSES ***;
data est;
  set est_m1 (in = in1)
      est_m2 (in = in2);
  by sim;
  if in1 then model = 1;
  else if in2 then model = 2;

  success = ifn(estimate > 0 and probt < 0.05, 1, 0);
  seed    = &seed.;

run;


*** DELETE UNWANTED WORK DATA ***;
proc datasets lib=work nolist;
  delete parameters1 simulations1 lsm_m1 lsm_m2;
quit;


*** SUMMARISE THE RESULTS ***;
proc means data = est;
  by 


