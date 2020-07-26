/*******************************************************************************
|
| Program Name:    MS_TOOLS_EX1_MS_INCLUDE.sas
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
| 1. This example uses MS_TOOLs macro MS_INCLUDE to include the sas program
|    MS_TOOLS_EX1_MS_CODE.sas in multiple remote sessions. See this program for
|    the actual simulations performed in the remote sessions. This program sets
|    up the remote sessions and then calls them.
|
*********************************************************************************/;


*** UPDATE THE SEED USING AUTOMATIC SESSION MACRO VARIABLE _II_ ***;
%let rs_seed = %sysevalf(&mainseed. + &_ii_.);


*** CREATE PARAMETERS DATASET ***;
data parameters1 (keep = trtcd m1-m4 vc:);

  array vc[4,4] (1.00 0.70 0.60 0.30
                 0.70 1.00 0.60 0.40
                 0.60 0.60 1.00 0.60
                 0.30 0.40 0.60 1.00);

  array m_t1[4] (0.00 0.10 0.20 0.30);
  array m_t2[4] (0.00 0.25 0.50 0.75);
  array m[4];

  do i = 1 to 4;
    trtcd = 1;
    m[i]  = m_t1[i];
  end;
  output;

  do i = 1 to 4;
    trtcd = 2;
    m[i]  = m_t2[i];
  end;
  output;

run;


*** SIMULATE DATA USING MCMC AND CONSTANT LIKELIHOOD ***;
%odsoff(notesyn=Y);
proc mcmc data    = parameters1
          outpost = simulations1 (keep = trtcd iteration x1-x4)
          nbi     = 0
          thin    = 1
		  nmc     = %sysevalf(&nsims.*&nsubs.)
          seed    = &rs_seed.;
             
  by trtcd;

  array x[4];
  array m[4] m1-m4;
  array v[4,4] vc1-vc16;

  parms x;
  prior x ~ mvn(m,v);
  model general(0);

run;
%odson;



*** TRANSPOSE INTO REPEATED MEASURES FORMAT ***;
data simulations2;
  set simulations1;
  retain sub 0 sim 1;
  seed = &rs_seed.;
  sub = sub + 1;
  if sub > &nsubs. then do;
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

  keep trtcd sim sub seed time base chg;

run;
  

*** FIT MIXED MODEL WITH TYPE=CS ***;
%odsoff(notesyn=Y);
proc mixed data = simulations2;
  by sim;
  class trtcd time;
  model chg = trtcd*time;
  repeated time / subject=sub type=cs;
  lsmeans trtcd*time;
  ods output lsmeans=m1_lsm;
run;
%odson;

data m1_lsm;
  set m1_lsm;
  seed = &rs_seed.;
run;


*** FIT MIXED MODEL WITH TYPE=UN ***;
%odsoff(notesyn=Y);
proc mixed data = simulations2;
  by sim;
  class trtcd time sub;
  model chg = trtcd*time base*time;
  repeated time / subject=sub type=un;
  lsmeans trtcd*time;
  ods output lsmeans=m2_lsm;
run;
%odson;

data m2_lsm;
  set m2_lsm;
  seed = &rs_seed.;
run;
