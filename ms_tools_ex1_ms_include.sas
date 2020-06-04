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

**********************************************************************************;
*** SECTION 1: SET UP ENVIRONMENT                                              ***;
**********************************************************************************;
 

*** SET LOCATION OF THE SAS REPO FOR MS_TOOLS ***;
*%let sas_repo = /hpawrk/tad66240/repositories;
%let sas_repo = C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas;

*** INCLUDE SIMULATION TOOLS ***;
/**%include "/hpawrk/tad66240/repositories/sim_tools/sim_tools.sas";*/
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\sim_tools\sim_tools.sas";


*** INCLUDE MULTI SESSION TOOLS ***;
/**%include "/hpawrk/tad66240/repositories/ms_tools/ms_tools.sas";*/
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\ms_tools\ms_tools.sas";


*** SET SIMULATION OCS ***;
%let nsims    = 100;
%let nsubs    = 250;
%let mainseed = 12340;



**********************************************************************************;
*** SECTION 2: INCLUDE EXERNAL CODE IN REMOTE SESSIONS                         ***;
**********************************************************************************;


*** START TIMER ***;
%starttime();


*** OPEN MULTIPLE REMOTE SAS SESSIONS ***;
%ms_signon(sess_n=2);


*** INCLUDE EXTERNAL SIMULATION CODE IN ALL REMOTE SESSIONS ***;
%ms_include(file_list = %str("&sas_repo.\sim_tools\sim_tools.sas"
                            ,"&sas_repo.\ms_tools\ms_tools_ex1_ms_code.sas")
           ,mvar_list = %str(nsims, nsubs, mainseed)
           ,keep_list = %str(m1_lsm, m2_lsm)
           ,sign_off  = Y);


*** STOP TIMER ***;
%stoptime();


*** STACK ALL LSM FOR MODEL 1 ***;
data m1_lsm;
  set m1_lsm_:;
  by seed sim;
run;


*** STACK ALL LSM FOR MODEL 2 ***;
data m2_lsm;
  set m2_lsm_:;
  by seed sim;
run;


*** DELETE COMPONENT DATASETS ***;
proc datasets lib = work nolist;
  delete m1_lsm_: m2_lsm_: ;
run;
