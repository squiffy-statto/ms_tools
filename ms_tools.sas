/*******************************************************************************
|
| Program Name:    MS_TOOLS.sas
|
| Program Version: 1.0
|
| Program Purpose: Creates a set of utility macros to help run code in parallel
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
|--------------------------------------------------------------------------------
| Macro List:
|--------------------------------------------------------------------------------
| Name     : ms_signon 
| Purpose  : Opens multiple child remote sessions in SAS 
| Arguments: nsess [REQ] = total number of remote sessions needed
|            prefix[OPT] = Prefix for the named sessions (default is rs)  
|
|---------------------------------------------------------------------------------
| Name     : ms_signoff 
| Purpose  : Closes remote sessions specified in SAS
| Arguments: sess_list[OPT] = comma list of specific sessions to end (default is
|                             all active child sessions).   
|
|---------------------------------------------------------------------------------
| Name     : ms_include 
| Purpose  : Includes external sas code files in specified remote sessions
| Arguments: sess_list[REQ] = comma list of sessions to include the code in
|            file_list[REQ] = comma list of sas files to include in the sessions
|            mvar_list[OPT] = comma list of macro vars to copy to all sessions
|            keep_list[OPT] = comma list of work datasets to copy back to main  
|                             work (default is all remote work datasets).
|            sign_off[OPT]  = set to N to keep the remote sessions open. This
|                             allows you to pass more code to them once they 
|                             have finished.
|
| Notes: This macro copies data back from the work lib in the remote sessions
|        back into the parent work session and gives it a suffix label for the
|        remote session it came from. If no keep_list is specified it will
|        automatically copy all work data back. Proc datasets can also be used 
|        to delete unwanted datasets in the parallel code. 
|
|---------------------------------------------------------------------------------
| Development Ideas:
|---------------------------------------------------------------------------------
|
|  
| *** CALL SAS MACRO IN CHILD SESSIONS ***;
| %ms_macrocall(sess_list  = %str(mysess1, mysess2)
|              ,macro_name = %str(sim_macro)
|              ,mvar_list  = %str(nsims, nsubs, nimps)
|              ,keep_list = %str());
|
|
| *** SPLIT UP EFFICACY DATASET AND PUT IN REMOTE SESSIONS ***;
| %ms_splitdata(sess_list  = %str(mysess1, mysess2)
|              ,indata     = %str(efficacydata)
|              ,inwhere    = %str(where paramcd = "BPSYS")
|              ,byvar_list = %str(paramcd, usubjid, avisitn))
|
| *** SPLIT UP POP DATASET BY SUBJECT AND PUT IN REMOTE SESSIONS ***;
| %ms_splitdata(sess_list  = %str(mysess1, mysess2)
|              ,indata     = %str(popdata)
|              ,inwhere    = %str(where ittfl = "Y")
|              ,byvar_list = %str(usubjid))
|
*********************************************************************************/;


**********************************************************************************;
*** MS_SIGNON                                                                  ***;
**********************************************************************************;
 
%macro ms_signon(sess_n=, prefix=);


  %let toolname = MS_SIGNON;


  %*** PREVENT FROM RUNNING ON PRODUCTION HARP SERVERS ***;
  %if %upcase(&syshostname.) = UK1SALX00175 | %upcase(&syshostname.) = US1SALX00259 %then %do;
      %put ER%upcase(ror:(&toolname.):) This macro is only designed to run on the HPC servers or local versions of PC SAS.;
      %put ER%upcase(ror:(&toolname.):) It is not designed to run on HARP servers (UK1SALX00175 or US1SALX00259). Macro will abort.;
      %abort cancel;
  %end;


  %*** CHECK IF PREFIX SUPPLIED ***;
  %let rs = rs;
  %if %length(&prefix.) ne 0 %then %let rs = &prefix.;


  %*** CREATE PARALLEL SESSIONS ***;
  %do _ii_ = 1 %to &sess_n.;
    signon &rs.&_ii_. sascmd="!sascmd" signonwait=no connectwait=no cmacvar=status&_ii_.;
  %end;


  %*** CHECK SIGN ON STATUS IF ONGOING SLEEP UNTIL AN OUTCOME RC IS SUPPLIED ***;
  %do _ii_ = 1 %to &sess_n.;
    %if &&status&_ii_. = 3 %then %do;
      %put NO%upcase(te:(&toolname.):) Waiting for connection to remote session to complete.;
      %do %until (&&status&_ii_. ne 3); 
         %let rc=%sysfunc(sleep(0.1,1)); 
      %end;
    %end;
    %if &&status&_ii_. = 0 %then %do;
      %put NO%upcase(te:(&toolname.):) Connection to remote session &rs&_ii_. successful.;     
    %end;
    %else %if &&status&_ii_. = 2 %then %do;
       %put NO%upcase(te:(&toolname.):) Connection to remote session &rs&_ii_. already established.;     
    %end;
    %else %if &&status&ii. = 1 %then %do;
      %put ER%upcase(ror:(&toolname.):) Connection to remote session &rs&_ii_. failed. All remote sessions initiated in this call terminated. Macro will abort.;
      signoff %do _jj_ = 1 %to &sess_n.; &rs&_jj_. %end;;
      %abort cancel;
    %end;
  %end;


  %*** CREATE GLOBAL MVAR FOR NAMES OF PARALLEL SESSIONS CREATED ***;
  %global sas_signons;
  %let sas_signons =;
  %do _ii_ = 1 %to &sess_n.;
     %if &_ii_. = 1 %then %let sas_signons = &rs.&_ii_.;
     %else %let sas_signons = &sas_signons., &rs.&_ii_.;
  %end;


%mend;



**********************************************************************************;
*** MS_SIGNOFF                                                                  ***;
**********************************************************************************;
 
%macro ms_signoff(sess_list=);


  %let toolname = MS_SIGNOFF;


  %*** PREVENT FROM RUNNING ON PRODUCTION HARP SERVERS ***;
  %if %upcase(&syshostname.) = UK1SALX00175 | %upcase(&syshostname.) = US1SALX00259 %then %do;
      %put ER%upcase(ror:(&toolname.):) This macro is only designed to run on the HPC servers or local versions of PC SAS.;
      %put ER%upcase(ror:(&toolname.):) It is not designed to run on HARP servers (UK1SALX00175 or US1SALX00259). Macro will abort.;
      %abort cancel;
  %end;


  %*** COUNT SESSION LIST ***;
  %let sess_n = %sysfunc(countw(&sess_list.,%str(,)));


  %*** CREATE SESSION LIST ***;
  %let sesslist=;
  %do _ii_ = 1 %to &sess_n.;
    %let rs&_ii_. = %scan(&sess_list.,&_ii_.,%str(,));
    %let sesslist = &sesslist. &&rs&_ii_.;
  %end;


  *** HALT SAS UNTIL ALL REMOTE SESSIONS COMPLETED ***;
  waitfor _all_ &sesslist.;


  *** SIGN OFF REMOTE SESSIONS  ***;
  %if &sess_n. = 0 %then %do;
    signoff _all_;
  %end;
  %else %do;
    %do _ii_ = 1 %to &sess_n.;
      signoff &&rs&_ii_.;
    %end;
  %end;

 
%mend;



**********************************************************************************;
*** MS_INCLUDE                                                                 ***;
**********************************************************************************;
 

%macro ms_include(sess_list =
                 ,file_list =
                 ,mvar_list =
                 ,keep_list =
                 ,sign_off  =);


  %let toolname = MS_INCLUDE;


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
  %let file_n = %sysfunc(countw(&file_list.,%str(,)));
  %let mvar_n = %sysfunc(countw(&mvar_list.,%str(,)));
  %let keep_n = %sysfunc(countw(&keep_list.,%str(,)));


  %*** CREATE SESSION LIST ***;
  %let sesslist=;
  %do _ii_ = 1 %to &sess_n.;
    %let rs&_ii_. = %scan(&sess_list.,&_ii_.,%str(,));
    %let sesslist = &sesslist. &&rs&_ii_.;
  %end;


  %*** CREATE FILE LIST ***;
  %let filelist=;
  %do _ii_ = 1 %to &file_n.;
    %let file&_ii_. = %scan(&file_list.,&_ii_.,%str(,));
    %let filelist = &filelist. &&file&_ii_.;
  %end;


  %*** CREATE MVAR LIST ***;
  %let mvarlist=;
  %do _ii_ = 1 %to &mvar_n.;
    %let mvar&_ii_. = %scan(&mvar_list.,&_ii_.,%str(,));
    %let mvarlist = &mvarlist. &&mvar&_ii_.;
  %end;


  %*** CREATE KEEP LIST AND EXTRA SQL CODE NEEDED ***;
  %let keeplist=;
  %let keepcode=;
  %do _ii_ = 1 %to &keep_n.;
    %let keep&_ii_. = %scan(&keep_list.,&_ii_.,%str(,));
    %let keeplist = &keeplist. &&keep&_ii_.;
	%if &_ii_. = 1 %then %let keepcode = and ( ; 
    %if &_ii_. = &keep_n. %then %let keepcode = &keepcode. upcase(memname) = upcase("&&keep&_ii_") ); 
    %else %let keepcode = &keepcode. upcase(memname) = upcase("&&keep&_ii_") or ;
  %end;

  %put &=keepcode;


  %*** IF SIGN OFF NOT PROVIDED DEFAULT TO YES ***;
  %if %length(&sign_off.) = 0 | &sign_off. = Y %then %let persist = no;
  %else %if &sign_off. = N %then %let persist = yes; 


  %*** CREATE PARALLEL SESSION CALLS ***;
  %do _ii_ = 1 %to &sess_n.;


	 %*** TRANSFER KEY MACRO VARIABLES INTO REMOTE SESSION ***;
     %syslput _ii_      = &_ii_.              / remote = &&rs&_ii_.;
     %syslput rs&_ii_   = &&rs&_ii_.          / remote = &&rs&_ii_.;
	 %syslput mainwork  = %bquote(&mainwork.) / remote = &&rs&_ii_.;
     %syslput file_list = &file_list.         / remote = &&rs&_ii_.;
     %syslput keepcode  = &keepcode.          / remote = &&rs&_ii_.;


     %*** TRANSFER ANY SPECIFIED MACRO VARIABLES INTO REMOTE SESSIONS  ***;
     %do _jj_ = 1 %to &mvar_n.;
	   %syslput &&mvar&_jj_. = &&&&&&mvar&_jj_. / remote = &&rs&_ii_.;
     %end;


     *** CREATE RSUBMIT BLOCK WITH INCLUE FOR EACH REMOTE SESSION ***;
     rsubmit &&rs&_ii_. wait=no cpersist=&persist.; 


       *** LOCATION OF MAIN WORK LIBRARY ***;
       libname mainwork "&mainwork.";


       *** INCLUDE CODE ***;
       %include &file_list.;


	   *** CREATE LISTS OF REMOTE WORK DATASETS ***;
       proc sql noprint;

         select distinct memname into :dsetlist separated by ' '
         from sashelp.vmember 
         where libname = "WORK" and memtype = "DATA" &keepcode. ;

         select distinct cats(memname,'=',memname,"_&&rs&_ii_") into :renamelist separated by ' '
         from sashelp.vmember 
         where libname = "WORK" and memtype = "DATA" &keepcode. ;

         select cats(memname,"_&&rs&_ii_") into :copylist separated by ' '
         from sashelp.vmember 
         where libname = "WORK" and memtype = "DATA" &keepcode. ;

       quit;
       run;


	   *** ADD SUFFIX TO EACH DATASET AND COPY BACK TO MAIN WORK LIBRARY ***;
       proc datasets lib = work nolist;
         change &renamelist.;
         copy out = mainwork; 
         select &copylist.;
         delete &dsetlist.;
       quit;
       run;


     endrsubmit;


  %end;


%mend;



**********************************************************************************;
*** MS_MACROCALL                                                               ***;
**********************************************************************************;
 
