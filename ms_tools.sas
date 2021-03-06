/*******************************************************************************
|
| Program Name:    MS_TOOLS.sas
|
| Program Version: 1.0
|
| Program Purpose: Creates a set of utility macros to help run code in parallel
|
| SAS Version:  9.4  
|
| Created By:   Thomas Drury
| Date:         13-03-20 
|
|-------------------------------------------------------------------------------
| Licence: MIT: Copyright (c) 2020 Thomas Drury (github: squiffystatto)
|
| Licence agreement copied from original:
|
| Permission is hereby granted, free of charge, to any person obtaining a copy
| of this software and associated documentation files (the "Software"), to deal
| in the Software without restriction, including without limitation the rights
| to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
| copies of the Software, and to permit persons to whom the Software is
| furnished to do so, subject to the following conditions:
|
| The above copyright notice and this permission notice shall be included in all
| copies or substantial portions of the Software.
|
| THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
| IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
| FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
| AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
| LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
| OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
| SOFTWARE.
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
| Arguments: 
|
| file_list [REQUIRED]: comma list of sas files to include in the sessions
| sess_list [OPTIONAL]: comma list of sessions to include the code into. If no 
|                       list given all sessions created by last signon macro call 
|                       are used (using global macro var list SAS_SIGNONS).
| mvar_list [OPTIONAL]: comma list of macro vars to copy to all sessions             
| keep_list [OPTIONAL]: comma list of work datasets to copy back to mainwork lib. 
|                       Default is all remote work datasets.            
| sign_off  [OPTIONAL]: Set to N to keep the remote sessions open. This allows 
|                       the user to pass more code to them once they have 
|                       finished. Default is Y and session closes once remote 
|                       code is complete.
| Notes
| ---------------------------------
| 
| 1. This macro copies data back from the work lib in the remote sessions
|    back into the parent work session and gives it a suffix label for the
|    remote session it came from. If no keep_list is specified it will
|    automatically copy all work data back. Proc datasets can also be used 
|    to delete unwanted datasets in the parallel code. 
|
| 2. The macro also copies the session number index into each remote session as 
|    a macro variable _ii_. This allow the user to update a main macro variable 
|    such as a seed to be different for each session. An example might be like
|    %LET SESS_SEED = %SYSEVALF(&MAINSEED. + &_ii_.); This means the user can 
|    simulate different data in parallel and have control over the seed used. 
|
|---------------------------------------------------------------------------------
| Name     : ms_macrocall 
| Purpose  : Calls compiled macro in specified remote sessions
| Arguments: 
|
| macro_name [REQUIRED]: name of compiled macro to include in the sessions
| mparm_list [OPTIONAL]: comma list of macro parameters (if any) for macro 
| sess_list [OPTIONAL]:  comma list of sessions to include the code into. If no 
|                        list given all sessions created by last signon macro  
|                        are used (using global macro var list SAS_SIGNONS).
| keep_list [OPTIONAL]:  comma list of work datasets to copy back to mainwork lib. 
|                        Default is all remote work datasets.            
| sign_off  [OPTIONAL]:  Set to N to keep the remote sessions open. This allows 
|                        the user to pass more code to them once they have 
|                        finished. Default is Y and session closes once remote 
|                        code is complete.
| Notes
| ---------------------------------
| 
| 1. This macro copies data back from the work lib in the remote sessions
|    back into the parent work session and gives it a suffix label for the
|    remote session it came from. If no keep_list is specified it will
|    automatically copy all work data back. Proc datasets can also be used 
|    to delete unwanted datasets in the parallel code. 
|
| 2. The macro also copies the session number index into each remote session as 
|    a macro variable _ii_. This allow the user to update a main macro variable 
|    such as a seed to be different for each session. An example might be like
|    %LET SESS_SEED = %SYSEVALF(&MAINSEED. + &_ii_.); This means the user can 
|    simulate different data in parallel and have control over the seed used. 
|
|---------------------------------------------------------------------------------
| Name     : ms_copydata 
| Purpose  : Copies a list of datasets to remote session work libraries
| Arguments: 
|
| sess_list [OPTIONAL]:  comma list of sessions to copy the datasets into. If no 
|                        list given all sessions created by last signon macro  
|                        are used (using global macro var list SAS_SIGNONS).
| data_list [REQUIRED]:  comma list of datasets to copy into remote work libs. 
|
|---------------------------------------------------------------------------------
| Name     : ms_splitdata 
| Purpose  : Splits up a dataset and copies to remote session work libraries
| Arguments: 
|
| sess_list [OPTIONAL]:  comma list of sessions to copy the split up dataset into. 
|                        If no sessions are specified all sessions created by last 
|                        signon macro are used (using global macro var list 
|                        SAS_SIGNONS).
| indata    [REQUIRED]:  dataset to split up and copy into remote work sessions. 
| inwhere   [OPTIONAL]:  where clause to apply to dataset before splitting up.
| bvar_list [OPTIONAL]:  comma list of by variables to ensure no splitting occurs
|                        across any particular by group. If no by vars specified
|                        then splitting occurs based on the rows of the dataset
|---------------------------------------------------------------------------------
| Development Ideas:
|---------------------------------------------------------------------------------
| 1. Ability to turn off macro specific notes.
| 2. Option to separate out the remote session logs into disctint log files.
|    (this would be an option to ms_signon. logfiles=<SEPARATE>/<INCLUDED>.
| 3. A tool to count the NOTES WARNINGS AND ERRORS for each logfile and report
|    this at the bottom of the main log.
|
*********************************************************************************/;


%let mlib_name = MS_TOOLS;

%*********************************************************************************;
%** MS_TOOLS LOAD MESSAGES                                                     ***;
%*********************************************************************************;

%macro load_messages();
  %put NO%upcase(te: (&mlib_name.)) --------------------------------------;
  %put NO%upcase(te: (&mlib_name.)) Macro libaray &mlib_name. included.;
  %put NO%upcase(te: (&mlib_name.)) --------------------------------------;
%mend;
%load_messages()


**********************************************************************************;
*** MS_SIGNON                                                                  ***;
**********************************************************************************;
 
%macro ms_signon(sess_n=, prefix=);


  %let toolname = MS_SIGNON;


  %*** CHECK NUMBER OF SESSIONS ***;
  %if &sess_n. gt 10 %then %do;
      %put ER%upcase(ror:(&toolname.):) This macro is only designed to run a maximum of 10 remote sessions.;
      %put ER%upcase(ror:(&toolname.):) Running more than 10 sessions could overload the HPC servers. Macro will abort.;
      %abort cancel;
  %end;
  %let sess_n = %sysfunc(abs(&sess_n.));


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


  %*** CREATE GLOBAL MVAR LIST FOR NAMES OF PARALLEL SESSIONS CREATED ***;
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


  %*** CREATE SESSION LIST ***;
  %let sess_n = %sysfunc(countw(&sess_list.,%str(,)));
  %let sesslist=;
  %do _ii_ = 1 %to &sess_n.;
    %let rs&_ii_. = %scan(&sess_list.,&_ii_.,%str(,));
    %let sesslist = &sesslist. &&rs&_ii_.;
  %end;


  %*** COUNT SIGNON LIST IF PRESENT ***;
  %if %symexist(sas_signons) %then %do;
     %let signon_n = %sysfunc(countw(%bquote(&sas_signons.),%str(,)));
	 %let signonlist=;
     %do _ii_ = 1 %to &signon_n.;
        %let signon&_ii_. = %scan(%bquote(&sas_signons.),&_ii_.,%str(,));
        %let signonlist = &signonlist. &&signon&_ii_.;
     %end;
  %end;


  *** HALT SAS UNTIL ALL REMOTE SESSIONS COMPLETED ***;
  waitfor _all_ &sesslist.;


  *** SIGN OFF REMOTE SESSIONS AND MANAGE ANY SIGNON LIST ***;
  %if &sess_n. = 0 %then %do;

    signoff _all_;
    %if %symexist(sas_signons) %then %do;
      %symdel sas_signons; 
    %end;

  %end;
  %else %do;

    %do _ii_ = 1 %to &sess_n.;
      signoff &&rs&_ii_.;
    %end;

    %if %symexist(sas_signons) %then %do;
      %let remain_signons=;
	  %put %length(&remain_signons.);
      %do _ii_ = 1 %to &signon_n.;
        %let remove = N;
	    %do _jj_ = 1 %to &sess_n.;
          %if &&signon&_ii_. = &&rs&_jj_. %then %let remove = Y;
	    %end;
	    %if &remove. ne Y %then %do;
           %if %length(&remain_signons.) = 0 %then %let remain_signons = &&signon&_ii_.; 
           %else %let remain_signons = &remain_signons., &&signon&_ii_.; 
        %end;
      %end;
      %if %length(&remain_signons.) = 0 %then %symdel sas_signons;
      %else %let sas_signons = &remain_signons.;
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
  %if %upcase(&keep_list.) ne NONE %then %let keep_n = %sysfunc(countw(&keep_list.,%str(,)));


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


  %*** CREATE KEEP LIST AND EXTRA SQL CODE NEEDED - UNLESS TOLD TO KEEP NONE ***;
  %if %upcase(&keep_list.) ne NONE %then %do;
    %let keeplist=;
    %let keepcode=;
    %do _ii_ = 1 %to &keep_n.;
      %let keep&_ii_. = %scan(&keep_list.,&_ii_.,%str(,));
      %let keeplist = &keeplist. &&keep&_ii_.;
      %if &_ii_. = 1 %then %let keepcode = and ( ; 
      %if &_ii_. = &keep_n. %then %let keepcode = &keepcode. upcase(memname) = upcase("&&keep&_ii_") ); 
      %else %let keepcode = &keepcode. upcase(memname) = upcase("&&keep&_ii_") or ;
    %end;
  %end;


  %*** IF SIGN OFF NOT PROVIDED DEFAULT TO YES ***;
  %if %length(&sign_off.) = 0 | &sign_off. = Y %then %let persist = no;
  %else %if &sign_off. = N %then %let persist = yes; 


  %*** CREATE PARALLEL SESSION CALLS ***;
  %do _ii_ = 1 %to &sess_n.;


	 %*** TRANSFER KEY MACRO VARIABLES INTO REMOTE SESSION ***;
     %syslput ms_n      = &_ii_.              / remote = &&rs&_ii_.;
     %syslput _ii_      = &_ii_.              / remote = &&rs&_ii_.;
     %syslput rs&_ii_   = &&rs&_ii_.          / remote = &&rs&_ii_.;
	 %syslput mainwork  = %bquote(&mainwork.) / remote = &&rs&_ii_.;
     %syslput file_list = &file_list.         / remote = &&rs&_ii_.;
     %syslput keep_list = &keep_list.         / remote = &&rs&_ii_.;
     %if %upcase(&keep_list.) ne NONE %then %do; 
     %syslput keepcode  = &keepcode.          / remote = &&rs&_ii_.; 
     %end;


     %*** TRANSFER ANY SPECIFIED MACRO VARIABLES INTO REMOTE SESSIONS  ***;
     %do _jj_ = 1 %to &mvar_n.;
	   %syslput &&mvar&_jj_. = &&&&&&mvar&_jj_. / remote = &&rs&_ii_.;
     %end;


     *** CREATE RSUBMIT BLOCK WITH INCLUE FOR EACH REMOTE SESSION ***;
     rsubmit &&rs&_ii_. wait=no cpersist=&persist. inheritlib=( work=mainwork ); 


       *** INCLUDE CODE ***;
       %include &file_list.;


	   *** CREATE LISTS OF REMOTE WORK DATASETS ***;
       %if %upcase(&keep_list.) ne NONE %then %do;

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

	   %end;


     endrsubmit;


  %end;

  *** HALT SAS UNTIL ALL REMOTE SESSIONS COMPLETED ***;
  waitfor _all_ &sesslist.;

%mend;



**********************************************************************************;
*** MS_MACROCALL                                                               ***;
**********************************************************************************;
 

%macro ms_macrocall(sess_list  =
                   ,macro_name =
                   ,mparm_list =
                   ,keep_list  =
                   ,sign_off   =);


  %let toolname = MS_MACROCALL;


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
  %let sess_n  = %sysfunc(countw(&sess_list.,%str(,)));
  %if %upcase(&keep_list.) ne NONE %then %let keep_n = %sysfunc(countw(&keep_list.,%str(,)));


  %*** CREATE SESSION LIST ***;
  %let sesslist=;
  %do _ii_ = 1 %to &sess_n.;
    %let rs&_ii_. = %scan(&sess_list.,&_ii_.,%str(,));
    %let sesslist = &sesslist. &&rs&_ii_.;
  %end;


  %*** CREATE CALL TO MACRO WITH PARAMETERS IF SPECIFIED ***;
  %let macro_call = &macro_name.;
  %if %length(&mparm_list.) ne 0 %then %do;
    %let mparm_n = %sysfunc(countw(&mparm_list.,%str(,)));
    %let mparm_list_tidy =;
    %do _ii_ = 1 %to &mparm_n.;
      %let mparm&_ii_. = %scan(&mparm_list.,&_ii_.,%str(,));
      %if &_ii_. = 1 %then %let mparm_list_tidy = &&mparm&_ii_.;
      %else %let mparm_list_tidy = &mparm_list_tidy., &&mparm&_ii_.;
    %end;
    %let macro_call = &macro_call.(&mparm_list_tidy.);
	%put &macro_call.;
  %end;


  %*** WORK OUT TYPE OF SAS EVIRONMENT ***;
  %if %upcase(&sysscp.) = WIN %then %do;
    %let runenv = PCSAS;
  %end;
  %else %if %upcase(&sysscp.) = LIN X64 %then %do;
    %if %symexist(_clientapp) %then %do;
      %if %upcase(&_clientapp.) = 'SAS STUDIO' %then %do;
        %let runenv = SASSTUDIO;
      %end;
      %else %do;
        %put ER%upcase(ror: (&toolname.):) Unable to determine the SAS Environment. Macro will abort.;
        %abort cancel;
      %end;
    %end;
    %else %do;
      %let runenv = LINUXSAS;
    %end;
  %end;
  %else %do;
    %put ER%upcase(ror: (&toolname.):) Unable to determine the SAS Environment. Macro will abort. &=sysscp;
    %abort cancel;
  %end;


  %*** CREATE CATALOG MACROS STORED IN ***;
  %if &runenv. = PCSAS or &runenv. = LINUXSAS %then %let macrocat = work.sasmacr;
  %else %if &runenv. = SASSTUDIO %then %let macrocat = work.sasmac1;


  %*** CREATE KEEP LIST AND EXTRA SQL CODE NEEDED ***;
  %if %upcase(&keep_list.) ne NONE %then %do;
    %let keeplist=;
    %let keepcode=;
    %do _ii_ = 1 %to &keep_n.;
      %let keep&_ii_. = %scan(&keep_list.,&_ii_.,%str(,));
      %let keeplist = &keeplist. &&keep&_ii_.;
      %if &_ii_. = 1 %then %let keepcode = and ( ; 
      %if &_ii_. = &keep_n. %then %let keepcode = &keepcode. upcase(memname) = upcase("&&keep&_ii_") ); 
      %else %let keepcode = &keepcode. upcase(memname) = upcase("&&keep&_ii_") or ;
    %end;
  %end;


  %*** IF SIGN OFF NOT PROVIDED DEFAULT TO YES ***;
  %if %length(&sign_off.) = 0 | &sign_off. = Y %then %let persist = no;
  %else %if &sign_off. = N %then %let persist = yes; 


  *** OPTION TO MAKE DIRECTORIES ***;
  options dlcreatedir;
  
     
  *** CHECK IF SHARED MACRO CATALOG EXISTS ***; 
  data _null_;
    copymacs = cexist("shared.sasmacr");
    call symput("copymacs", strip(put(copymacs,8.)));
  run;  


  %*** IF NEEDED COPY MACRO CATALOG TO SEPERATE AREA ***;
  %if &copymacs. ne 1 %then %do;
  
    libname shared "&mainwork./shared";  
    
    proc catalog cat = &macrocat. ;
      copy out = shared.sasmacr;
    run;
    quit;

  %end;


  %*** CREATE PARALLEL SESSION CALLS ***;
  %do _ii_ = 1 %to &sess_n.;


	 %*** TRANSFER KEY MACRO VARIABLES INTO REMOTE SESSION ***;
     %syslput ms_n       = &_ii_.       / remote = &&rs&_ii_.;
     %syslput _ii_       = &_ii_.       / remote = &&rs&_ii_.;
     %syslput rs&_ii_    = &&rs&_ii_.   / remote = &&rs&_ii_.;
	 %syslput mainwork   = &mainwork.   / remote = &&rs&_ii_.;
     %syslput macro_call = &macro_call. / remote = &&rs&_ii_.;
     %syslput copymacs   = &copymacs.   / remote = &&rs&_ii_.;
     %syslput keep_list  = &keep_list.  / remote = &&rs&_ii_.;
     %if %upcase(&keep_list.) ne NONE %then %do; 
     %syslput keepcode  = &keepcode.    / remote = &&rs&_ii_.; 
     %end;   

     *** CREATE RSUBMIT BLOCK WITH MACRO CALL FOR EACH REMOTE SESSION ***;
     rsubmit &&rs&_ii_. wait=no cpersist=&persist. inheritlib=( work=mainwork ); 


       %*** IF NEW REMOTE SESSION SET UP SHARED MACRO LIBNAME ***;
       %if &copymacs. ne 1 %then %do;
         libname shared "&mainwork./shared";
       %end;


   	   *** CALL MACRO ***;
       options mstored source sasmstore=shared;
       %&macro_call.;


       *** CREATE LISTS OF REMOTE WORK DATASETS ***;
       %if %upcase(&keep_list.) ne NONE %then %do;

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

	   %end;


       *** REMOVE ANY REMAINING WORK DATA ***;
       proc datasets lib = work nolist kill;
       quit;
       run;
       

     endrsubmit;

 
  %end;


  *** HALT SAS UNTIL ALL REMOTE SESSIONS COMPLETED ***;
  waitfor _all_ &sesslist.;


  %*** IF SIGNOFF THEN REMOVE SHARED CATALOG AND LIBNAME ***;
  %if %length(&sign_off.) = 0 | &sign_off. = Y %then %do;
  
    proc datasets lib = shared nolist;
      delete sasmacr / mt=cat;
    quit;
  
    libname shared clear;
  
  %end;
  

%mend;



**********************************************************************************;
*** MS_COPYDATA                                                                ***;
**********************************************************************************;
 
%macro ms_copydata(sess_list =
                  ,data_list =);


  %let toolname = MS_COPYDATA;


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




**********************************************************************************;
*** MS_SPLITDATA                                                               ***;
**********************************************************************************;
 
%macro ms_splitdata(sess_list =
                   ,indata    = 
                   ,inwhere   = 
                   ,bvar_list =);


  %let toolname = MS_SPLITDATA;


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
  %let bvar_n = %sysfunc(countw(&bvar_list.,%str(,)));


  %*** CREATE SESSION LIST ***;
  %let sesslist=;
  %do _ii_ = 1 %to &sess_n.;
    %let rs&_ii_. = %scan(&sess_list.,&_ii_.,%str(,));
    %let sesslist = &sesslist. &&rs&_ii_.;
  %end;


  %*** CREATE BY VARS LIST ***;
  %let bvarlist=;
  %if &bvar_n. = 0 %then %do;
    %let bvarlist=NONE;
  %end;
  %else %do;
    %do _ii_ = 1 %to &bvar_n.;
      %let bvar&_ii_. = %scan(&bvar_list.,&_ii_.,%str(,));
      %let bvarlist = &bvarlist. &&bvar&_ii_.;
    %end;
  %end;


  %*** WORK OUT IF DATASET HAS PERM LIBRARY OR IS A WORK DATASET ***;
  %let intype = %sysfunc(countw(&indata.,%str(.)));
  %if &intype. = 1 %then %do;
    %let dlib = WORK;
    %let dset = &indata.;
  %end;
  %else %if &intype. = 2 %then %do;
    %let dlib = %scan(&indata.,1,%str(.));
    %let dset = %scan(&indata.,2,%str(.));;
  %end;
  %else %do;
    %put ER%upcase(ror:(&toolname.):) Problem with input dataset. Macro will abort.;
    %abort cancel;
  %end;


  *** OPTION TO MAKE DIRECTORIES ***;
  options dlcreatedir;

  
  *** CREATE LOCATION TO HOLD DATASET TO SPLIT ***;
  libname split "&mainwork./splitdata";  
    

  *** CREATE COPY OF THE INPUT DATASET FOR SPLITTING ***;
  %if &bvarlist. ne NONE %then %do; 
    proc sort data = &dlib..&dset.
	          out  = split.&dset.;
	  by &bvarlist.;
	  &inwhere.;
	run;
  %end;
  %else %do;
    data split.&dset.;
      set &dlib..&dset.;
      &inwhere.;
    run;
  %end;
 

  *** COUNT TOTAL GROUPS BASED ON LAST BY VAR IF SPECIFIED OR EACH ROW IF NO BY VARS ***;
  data _null_; 
    set split.&dset. end = _eof_;
    %if &bvarlist. ne NONE %then %do; 
      by &bvarlist.;
      if first.&&bvar&bvar_n. then _total_ + 1;
    %end;
    %else %do;
    _total_ + 1;
    %end;
    if _eof_ then call symput("group_n",strip(put(_total_,8.)) );
  run;


  *** CREATE GROUPINGS ***; 
  data split.&dset.;
    set split.&dset.;
    retain _count_ 0;
    %if &bvarlist. ne NONE %then %do; 
      by &bvarlist.;
      if first.&&bvar&bvar_n. then _count_ + 1;
    %end;
    %else %do;
    _count_ + 1;
    %end;
    
    %if &group_n. lt &sess_n. %then %do;
      %put NO%upcase(te:(&toolname.):) The number of distinct by groups (&=group_n.) is less than the number;
      %put NO%upcase(te:(&toolname.):) of sessions (&=sess_n.). Therefore only the first &group_n. sessions will be used.;
      _group_ = _count_ - 1;
    %end;
    %else %do;
      _group_ = floor( (_count_*(&sess_n.)) / (&group_n.+1) );
    %end;
 
  run;


  %*** IF LESS GROUPS THAN SESSIONS UPDATE REMOTE SESSION NUMBER ***;
  %if &group_n. lt &sess_n. %then %do;
    %let rsess_n = %sysfunc(min(&group_n.,&sess_n.));
  %end;
  %else %do;
    %let rsess_n = &sess_n.;
  %end;


  %do _ii_ = 1 %to &rsess_n.;

    %*** MAKE MACRO VARIABLES AVAILABLE IN REMOTE SESSION ***;
	%syslput _ii_ = &_ii_. / remote = &&rs&_ii_.;
    %syslput dset = &dset. / remote = &&rs&_ii_.;

    *** CREATE RSUBMIT BLOCK WITH DATA STEP FOR EACH REMOTE SESSION ***;
    rsubmit &&rs&_ii_. wait=no cpersist=yes inheritlib=( work=mainwork split ); 

      data &dset.;
	    set split.&dset.;
		where _group_ = %eval(&_ii_. - 1);
	  run;

    endrsubmit;

  %end;

  waitfor _all_ %do _ii_ = 1 %to &rsess_n.; &&rs&_ii_. %end;;

  proc datasets lib = split nolist;
    delete &dset.;
  quit;

  libname split clear;  

%mend;

