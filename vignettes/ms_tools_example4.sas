




**********************************************************************************;
*** SECTION 1: SET UP ENVIRONMENT                                              ***;
**********************************************************************************;
 

*** SET LOCATION OF THE SAS REPO FOR MS_TOOLS ***;
%let sas_repo = /hpawrk/tad66240/repositories;


*** INCLUDE SIMULATION TOOLS ***;
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\sim_tools\sim_tools.sas";

*** INCLUDE MULTI SESSION TOOLS ***;
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\ms_tools\ms_tools.sas";





*** INCLUDE MULTI SESSION TOOLS ***;
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\ms_tools\ms_tools.sas";

data pop;
  set sashelp.cars;
run;

%ms_signon(sess_n=10);

%ms_copydata(data_list = %str(pop, sashelp.class));

%ms_signoff();




