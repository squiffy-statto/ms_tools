



**********************************************************************************;
*** SIMPLE EXAMPLE USAGE                                                       ***;
**********************************************************************************;


*** INCLUDE SIMULATION TOOLS AND MULTI SESSION TOOLS ***;
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\sim_tools\sim_tools.sas";
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\ms_tools\ms_tools.sas";


*** SET LOCATION OF THE SAS REPO ***;
%let sas_repo = C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas;


*** SET SIMULATION OCS ***;
%let nsims = 1000;
%let mainseed = 12340;


*** START TIMER ***;
%starttime();


*** OPEN MULTIPLE CHILD SAS SESSIONS AND RUN CODE IN EACH ***;
%ms_signon(sess_n=2);
%ms_include(mvar_list = %str(nsims, mainseed)
		   ,file_list = %str("&sas_repo.\sim_tools\sim_tools.sas"
                            ,"&sas_repo.\ms_tools\ms_tools_ex1_rs_code.sas"));
%ms_signoff();


*** STOP TIMER ***;
%stoptime();



**********************************************************************************;
*** SPECIFYING 5 SESSIONS TO USE FOR 5 DIFFERENT PROGRAMS                      ***;
**********************************************************************************;

*** START TIMER ***;
%starttime(startid=example2);


*** OPEN MULTIPLE CHILD SAS SESSIONS ***;
%ms_signon(sess_n=5, prefix=%str(mysess));


*** INCLUDE SAS CODE IN CHILD SESSIONS ***;
%ms_include(sess_list = %str(mysess1, mysess2, mysess3, mysess4, mysess5)
           ,mvar_list = %str(nsims, mainseed)
		   ,file_list = %str("&sas_repo.\sim_tools\sim_tools.sas"
                            ,"&sas_repo.\ms_tools\ms_tools_ex1_rs_code.sas"));


*** CLOSE MULTIPLE CHILD SESSIONS ***;
%ms_signoff(sess_list=%str(rsess1, rsess2, rsess3));


*** STOP TIMER ***;
%stoptime(startid=example2);





