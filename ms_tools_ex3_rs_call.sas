
proc datasets lib = work nolist kill;
quit;
run;

**********************************************************************************;
*** SIMPLE EXAMPLE USAGE                                                       ***;
**********************************************************************************;


*** INCLUDE SIMULATION TOOLS AND MULTI SESSION TOOLS ***;
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\sim_tools\sim_tools.sas";
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\ms_tools\ms_tools.sas";


%macro analysis(nsims =, mainseed =);

  %let seed = %sysevalf(&mainseed. + &_ii_.);

  *** CREATE PARAMETERS TO SIMULATE FROM ***;
  data parameters1;
    mu = 2; sigma = 5;
  run;

  *** SIMULATE THE DATA ***;
  %odsoff(notesyn=Y);
  proc mcmc data    = parameters1
            outpost = sample1
            seed    = &seed. 
            nbi     = 0
            nmc     = &nsims.
            thin    = 1;
    parms x1;
    prior x1 ~ normal(mu, sd=sigma, lower=2, upper=3); 
    model general(1);
  run;
  %odson;


  *** ADD THE SEED TO THE DATASET TO KEEP A RECORD ***;
  data sample2;
    set sample1;
    simseed = &seed. ;
  run;


%mend;


**********************************************************************************;
*** SPECIFYING 5 SESSIONS TO USE FOR 5 DIFFERENT PROGRAMS                      ***;
**********************************************************************************;

*** START TIMER ***;
%starttime();


*** OPEN MULTIPLE CHILD SAS SESSIONS AND RUN CODE IN EACH ***;
%ms_signon(sess_n=2);

%ms_macrocall(macro_name = analysis
		     ,mparm_list = %str(nsims=1000, mainseed=12340)
             ,sign_off  = Y);

*** STOP TIMER ***;
%stoptime();




%ms_signoff();





**********************************************************************************;
*** SPECIFYING 5 SESSIONS TO USE FOR 5 DIFFERENT PROGRAMS                      ***;
**********************************************************************************;

*** START TIMER ***;
%starttime(startid=example2);


*** OPEN MULTIPLE CHILD SAS SESSIONS ***;
%ms_signon(sess_n=5, prefix=%str(rsess));


*** INCLUDE SAS CODE IN CHILD SESSION 1 TO 3 ***;
%ms_include(sess_list = %str(rsess1, rsess2, rsess3)
           ,mvar_list = %str(nsims, mainseed)
		   ,file_list = %str("&sas_repo.\sim_tools\sim_tools.sas"
                            ,"&sas_repo.\ms_tools\ms_tools_ex1_rs_code.sas")
           ,sign_off = N);


*** INCLUDE SAS CODE IN CHILD SESSION 4 AND 5 ***;
%ms_include(sess_list = %str(rsess4, rsess5)
           ,mvar_list = %str(nsims, mainseed)
		   ,file_list = %str("&sas_repo.\sim_tools\sim_tools.sas"
                            ,"&sas_repo.\ms_tools\ms_tools_ex1_rs_code.sas")
           ,sign_off = Y);


*** CLOSE SESSIONS 1 TO 3 ***;
%ms_signoff(sess_list=%str(rsess1, rsess2, rsess3));



*** CLOSE SESSIONS 4 AND 5 ***;
%ms_signoff(sess_list=%str(rsess4, rsess5));



*** STOP TIMER ***;
%stoptime(startid=example2);





