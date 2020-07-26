
## The ms_tools macro library

The ms_tools library was developed based on a weekly need to perform simulation work faster. The macros have been developed as a set of utility tools that can be combined flexibly to run code in different ways. Whether you want to parallelize a single SAS program that simulates and analyses data all in one go, or you have a number of different programs or macros you want to call in remote sessions, these tools should allow you to do both easily. A table of the functions and their purpose is given below:


Macro         | Description                                                                        |
--------------|------------------------------------------------------------------------------------|
%ms_signon    | Sets up a number of remote sessions spawned from the current "parent" session.     |
%ms_macrocall | Calls a macro created in the parent session in all or specific remote sessions.    |
%ms_include   | Includes a list of external SAS programs in all or specified remote sessions.      |
%ms_signoff   | Closes all or specified remote sessions.                                           |
%ms_copydata  | Copies datasets into WORK library of each of the specific remote sessions.         |
%ms_splitdata | Splits up a dataset into sections and passes each to the specific remote sessions. |

The macros themselves have various arguments that are either required or optional which are explained below.

<hr>

**%MS_SIGNON()**


```sas

%ms_signon(sess_n = <-Number->              
          ,prefix = <-Session-Name->    
          );

```

Parameter | Type     | Description                                                                             |
----------|----------|-----------------------------------------------------------------------------------------|
sess_n    | Required | Number of remote sessions to create                                                     | 
prefix    | Optional | A prefix for the remote sessions. If no prefix is used they are named rs1 to rs&sess_n. |

<br>
<hr>

**%MS_MACROCALL()**

```sas 

%ms_macrocall(macro_name = <-NAME->
             ,mparm_list = %str(<-MPARM-1=MVAL-1->, ..., <-MPARM-J=MVAL-J->) 
             ,sess_list  = %str(<-SESS-1-> , ..., <-SESS-K->) 
             ,keep_list  = %str(<-DSET-1-> , ..., <-DSET-L->) 
             ,sign_off   = Y
             );

```

Parameter  | Type     | Description                                                                                                        |
-----------|----------|--------------------------------------------------------------------------------------------------------------------|
macro_name | Required | Name of macro to call in remote sessions                                                                           | 
mparm_list | Optional | Comma list of macro parameter arguments for the macro                                                              |
sess_list  | Optional | Comma list of sessions to include the external code in. If no sessions given all open remote sessions will be used |
keep_list  | Optional | Comma list of remote work datasets to copy back into the parent work. If not specified then all work data copied   |
sign_off   | Optional | If set to Y then the remote sessions close and sign off when the code has finished running. The default is Y.      |

<br>
<hr>

**%MS_INCLUDE()**

```sas 

%ms_include(file_list = %str("<-FILE-1->", ...,"<-FILE-J->")
           ,sess_list = %str(<-SESS-1->, ..., <-SESS-K->) 
           ,mvar_list = %str(<-MVAR-1->, ..., <-MVAR-L->) 
           ,keep_list = %str(<-DSET-1->, ..., <-DSET-M->) 
           ,sign_off  = Y
           );
           
```

Parameter | Type     | Description                                                                                                        |
----------|----------|--------------------------------------------------------------------------------------------------------------------|
file_list | Required | Comma list of quoted external files to include in remote sessions                                                  | 
sess_list | Optional | Comma list of sessions to include the external code in. If no sessions given all open remote sessions will be used |
mvar_list | Optional | Comma list of macro variables that exist in the parent session to be passed to each remote session                 |
keep_list | Optional | Comma list of remote work datasets to copy back into the parent work. If not specified then all work data copied   |
sign_off  | Optional | If set to Y then the remote sessions close and sign off when the code has finished running. The default is Y.      |

<br>
<hr>

**%MS_SIGNOFF()**

```sas

%ms_signoff(sess_list = %str(<-SESS-1-> ,..., <-SESS-J->));

```

Parameter | Type     | Description                                                                             |
----------|----------|-----------------------------------------------------------------------------------------|
sess_list | Optional | List of sessions to sign off. If no list supplied all active remote sessions are stopped| 

<br>
<hr>

**%MS_COPYDATA()**

```sas

%ms_copydata(data_list  = %str(<-DSET-1-> , ..., <-DSET-L->) 
            ,sess_list  = %str(<-SESS-1-> , ..., <-SESS-K->) 
            );
            
```

Parameter | Type     | Description                                                                                                  |
----------|----------|--------------------------------------------------------------------------------------------------------------|
sess_list | Optional | Comma list of sessions to copy the datasets into. If no sessions given all open remote sessions will be used | 
data_list | Required | Comma list of datasets to be copied to remote sessions. Datasets are placed in the remote WORK dataset       | 

<br>
<hr>

**%MS_SPLITDATA()**

Not built yet!

<br>
<hr>
