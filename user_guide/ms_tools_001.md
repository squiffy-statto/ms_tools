---
title: "User Guide: ms_tools"
author: Thomas Drury, ABDA CoE
date: 01-07-20
output:
  html_document:
    include:
      in_header: setup/header.html
    keep_md: yes
    toc: false
---




### Overview

This is a user guide for a suite of macro tools to help users run SAS code in parallel. **These tools are not designed to work on the HARP servers. They should only be used on the SAS GPC and HPC servers, or on local PC SAS.** 

There is a vignette with examples of using these tools [here](<https://myconnect.gsk.com/sites/bds/Biostatistics/Documents/Forms/ABDA_Vignettes.aspx?View={15e95c8d-31a4-42aa-b767-2f6d87cee50e}&RootFolder=%2Fsites%2Fbds%2FBiostatistics%2FDocuments%2FABDA%2Fvignettes&SortField=LinkFilenameNoMenu&SortDir=Asc>). 

The macros are published on the GDrive [here](<https://gdrive.gsk.com/gdrive/drive/ECS/biostats/dGFkNjYyNDAvbXNfdG9vbHMv>). To view the files you will need access to the Biostatistics code area on GDrive which can be obtained by completing the training [here](<https://us1salxhpe0011.corpnet2.com:3939/content/33/>).

### Background

Since SAS 9.2 it has been possible to programatically spawn "child" remote SAS sessions. These can be used to simulate and analyse data in parallel. The remote sessions are tied to the original "parent" session and accept code from the parent using `RSUBMIT` blocks. This allows the user to simultaneously set a number of jobs running and reduce the run time of tasks that normally proceed linearly.

The creation and management of remote sessions from scratch is not hard, but requires a lot of operational SAS code. The ms_tools macros are designed to automate these tasks and therefore make it easy for users to create sessions and submit code in parallel. For more information on how to create remote sessions from scratch there are slides and examples on from the 2019 SAS HPC course on GDrive 
[here](<https://gdrive.gsk.com/gdrive/drive/ECS/biostatistics-verified/QUJEQS9Nb2RlbGxpbmcgYW5kIFNpbXVsYXRpb24gVXNpbmcgdGhlIEdTSyBIaWdoIFBlcmZvcm1hbmNlIENvbXB1dGluZyBGYWNpbGl0aWVzLw%3D%3D>). 

There is also full documentation on the SAS institute webpages.  


### The ms_tools macro library

The ms_tools library has been developed as a set of utility macro tools that can be combined flexibly to run code in different ways. Whether you want to parallelize a single SAS program to simulate and analyse data in one go, or you have a number of different programs (or macros) you want to call in remote sessions, ms_tools should allow you to do both. A table of the functions and their purpose is given below:


Macro         | Description                                                                        |
--------------|------------------------------------------------------------------------------------|
%ms_signon    | Sets up a number of remote sessions spawned from the current "parent" session.     |
%ms_macrocall | Calls a macro created in the parent session in all or specific remote sessions.    |
%ms_include   | Includes a list of external SAS programs in all or specified remote sessions.      |
%ms_signoff   | Closes all or specified remote sessions.                                           |
%ms_copydata  | Copies datasets into WORK library of each of the specific remote sessions.         |
%ms_splitdata | Splits up a dataset into sections and passes each to the specific remote sessions. |

Each macro has various arguments that are either required or optional explained below.

<hr>

**%MS_SIGNON()**

<!--html_preserve--><pre><code class="language-sas">%ms_signon(sess_n = <-Number->              
          ,prefix = <-Session-Name->    
          );</code></pre><!--/html_preserve-->


Parameter | Type     | Description                                                                             |
----------|----------|-----------------------------------------------------------------------------------------|
sess_n    | Required | Number of remote sessions to create.                                                    | 
prefix    | Optional | A prefix for the remote sessions. If no prefix is used they are named rs1 to rs&sess_n. |

<hr>


**%MS_MACROCALL()**

<!--html_preserve--><pre><code class="language-sas">%ms_macrocall(macro_name = <-NAME->
             ,mparm_list = %str(<-MPARM-1=MVAL-1->, ..., <-MPARM-J=MVAL-J->) 
             ,sess_list  = %str(<-SESS-1-> , ..., <-SESS-K->) 
             ,keep_list  = %str(<-DSET-1-> , ..., <-DSET-L->) 
             ,sign_off   = Y
             );</code></pre><!--/html_preserve-->


Parameter  | Type     | Description                                                                                                        |
-----------|----------|--------------------------------------------------------------------------------------------------------------------|
macro_name | Required | Name of macro to call in remote sessions                                                                           | 
mparm_list | Optional | Comma list of macro parameter arguments for the macro                                                              |
sess_list  | Optional | Comma list of sessions to include the external code in. If no sessions given all open remote sessions will be used |
keep_list  | Optional | Comma list of remote work datasets to copy back into the parent work. If not specified then all work data copied   |
sign_off   | Optional | If set to Y then the remote sessions close and sign off when the code has finished running. The default is Y.      |

<hr>


**%MS_INCLUDE()**

<!--html_preserve--><pre><code class="language-sas">%ms_include(file_list = %str("<-FILE-1->", ...,"<-FILE-J->")
           ,sess_list = %str(<-SESS-1->, ..., <-SESS-K->) 
           ,mvar_list = %str(<-MVAR-1->, ..., <-MVAR-L->) 
           ,keep_list = %str(<-DSET-1->, ..., <-DSET-M->) 
           ,sign_off  = Y
           );</code></pre><!--/html_preserve-->


Parameter | Type     | Description                                                                                                        |
----------|----------|--------------------------------------------------------------------------------------------------------------------|
file_list | Required | Comma list of quoted external files to include in remote sessions.                                                 | 
sess_list | Optional | Comma list of sessions to include the external code in. If no sessions given all open remote sessions will be used.|
mvar_list | Optional | Comma list of macro variables that exist in the parent session to be passed to each remote session.                |
keep_list | Optional | Comma list of remote work datasets to copy back into the parent work. If not specified then all work data copied.  |
sign_off  | Optional | If set to Y then the remote sessions close and sign off when the code has finished running. The default is Y.      |

<hr>


**%MS_SIGNOFF()**

<!--html_preserve--><pre><code class="language-sas">%ms_signoff(sess_list = %str(<-SESS-1-> ,..., <-SESS-J->)           
                            );</code></pre><!--/html_preserve-->


Parameter | Type     | Description                                                                             |
----------|----------|-----------------------------------------------------------------------------------------|
sess_list | Optional | List of sessions to sign off. If no list supplied all active remote sessions are stopped| 

<hr>


**%MS_COPYDATA()**

<!--html_preserve--><pre><code class="language-sas">%ms_copydata(data_list  = %str(<-DSET-1-> ,..., <-DSET-L->) 
            ,sess_list  = %str(<-SESS-1-> ,..., <-SESS-K->) 
            );</code></pre><!--/html_preserve-->


Parameter | Type     | Description                                                                                                  |
----------|----------|--------------------------------------------------------------------------------------------------------------|
sess_list | Optional | Comma list of sessions to copy the datasets into. If no sessions given all open remote sessions will be used.| 
data_list | Required | Comma list of datasets to be copied to remote sessions. Datasets are placed in the remote WORK libraries.    | 

<hr>


**%MS_SPLITDATA()**


<!--html_preserve--><pre><code class="language-sas">%ms_splitdata(indata    = <-DSET-> 
             ,inwhere   = <-SAS-WHERE-CLAUSE->
             ,sess_list = %str(<-SESS-1-> ,..., <-SESS-K->) 
             ,bvar_list = %str(<-BVAR-1-> ,..., <-BVAR-K->));</code></pre><!--/html_preserve-->


Parameter | Type     | Description                                                                                                  |
----------|----------|--------------------------------------------------------------------------------------------------------------|
indata    | Required | Dataset to be split up and copied to remote sessions. Datasets are placed in the remote WORK libraries.      | 
inwhere   | Optional | Where clause to subset dataset before being split up and copied into remote sessions.                        | 
sess_list | Optional | Comma list of sessions to copy the datasets into. If no sessions given all open remote sessions will be used.| 
bvar_list | Optional | Comma list of by variables to observe when splitting. No splitting will occur within these variables.        | 

<hr>

<br>
