




**********************************************************************************;
*** SECTION 1: SET UP ENVIRONMENT                                              ***;
**********************************************************************************;
 

*** SET LOCATION OF THE SAS REPO FOR MS_TOOLS ***;
%let sas_repo = /hpawrk/tad66240/repositories;


*** INCLUDE SIMULATION TOOLS ***;
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\sim_tools\sim_tools.sas";

*** INCLUDE MULTI SESSION TOOLS ***;
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\ms_tools\ms_tools.sas";






%macro ms_copydata(sess_list =
                  ,data_list =
                  );


  %let toolname = MS_COPYDATA;


  %*** PREVENT FROM RUNNING ON PRODUCTION HARP SERVERS ***;
  %if %upcase(&syshostname.) = UK1SALX00175 | %upcase(&syshostname.) = US1SALX00259 %then %do;
      %put ER%upcase(ror:(&toolname.):) This macro is only designed to run on the HPC servers or local versions of PC SAS.;
      %put ER%upcase(ror:(&toolname.):) It is not designed to run on HARP servers (UK1SALX00175 or US1SALX00259). Macro will abort.;
      %abort cancel;
  %end;


  %*** GET LOCATION OF MAIN WORK ***;
  %let mainwork = %sysfunc(pathname(work));


  %*** CHECK EITHER EXPLICIT SESSIONS GIVEN OR SAS_SIGNONS EXISTS ***;
  %if %length(&sess_list.) = 0 %then %do;
    %if %symexist(sas_signons) %then %do; 
      %let sess_list = %bquote(&sas_signons.);
    %end;
	%else %do;
	  %put ER%upcase(ror: (&toolname.):) No session list given and no remote sessions found. Macro will abort.;
      %abort cancel;
	%end;
  %end;


  %*** COUNT LISTS ***;
  %let sess_n = %sysfunc(countw(&sess_list.,%str(,)));
  %let data_n = %sysfunc(countw(&data_list.,%str(,)));


  %*** CREATE SESSION LIST ***;
  %let sesslist=;
  %do _ii_ = 1 %to &sess_n.;
    %let rs&_ii_. = %scan(&sess_list.,&_ii_.,%str(,));
    %let sesslist = &sesslist. &&rs&_ii_.;
  %end;


  %*** CREATE DATA AND COPY LISTS ***;
  %let datalist=;
  %let copylist=;
  %do _ii_ = 1 %to &data_n.;

    %let data&_ii_. = %scan(&data_list.,&_ii_.,%str(,));
    %let datalist = &datalist. &&data&_ii_.;

    %let datatype = %sysfunc(countw(&&data&_ii_.,%str(.)));
    %if &datatype. = 1 %then %let copy&_ii_. = &&data&_ii_.;
	%else %if &datatype. = 2 %then %let copy&_ii_. = %scan(&&data&_ii_.,2,%str(.));
	%else %do;
      %put ER%upcase(ror:(&toolname.):) Problem with dataset list. Macro will abort.;
      %abort cancel;
    %end;

    %let copylist = &copylist. &&copy&_ii_.;

  %end;


  *** OPTION TO MAKE DIRECTORIES ***;
  options dlcreatedir;

  
  *** CREATE LOCATION TO HOLD ALL DATASETS TO COPY ***;
  libname copydata "&mainwork./copydata";  
    

  *** CREATE COPIES OF DATA IN SAME LOCATION  ***;
  %do _ii_ = 1 %to &data_n.; 
    data copydata.&&copy&_ii_.;
      set &&data&_ii_.;
    run;
  %end;


  %do _ii_ = 1 %to &sess_n.;

    %*** MAKE MACRO VARIABLES AVAILABLE IN REMOTE SESSION ***;
    %syslput copylist = &copylist. / remote = &&rs&_ii_.;

    *** CREATE RSUBMIT BLOCK WITH PROC DATASETS FOR EACH REMOTE SESSION ***;
    rsubmit &&rs&_ii_. wait=no cpersist=yes inheritlib=( work=mainwork copydata ); 

      *** COPY DATA TO REMOTE SESSIONS AND DELETE COPIES ***;
      proc datasets lib = copydata nolist;
        copy out = work; 
        select &copylist.;
      quit;
      run;

    endrsubmit;

  %end;

  waitfor _all_ &sesslist.;

  proc datasets lib = copydata nolist;
    delete &copylist.;
  quit;

  libname copydata clear;  

%mend;


*** INCLUDE MULTI SESSION TOOLS ***;
%include "C:\Users\tad66240\OneDrive - GSK\statistics\repositories\sas\ms_tools\ms_tools.sas";

data pop;
  set sashelp.cars;
run;

%ms_signon(sess_n=2
          ,prefix=td);

%ms_copydata(sess_list = %str(td1,td2)
            ,data_list = %str(pop, sashelp.class)
            );

%ms_signoff();




