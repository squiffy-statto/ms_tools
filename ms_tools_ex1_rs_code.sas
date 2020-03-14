

*** UPDATE THE SEED BASED ON THE SESSION ***;
%let seed&_ii_. = %sysevalf(&mainseed. + &_ii_.);
%put seed = &&seed&_ii_.;


*** CREATE PARAMETERS TO SIMULATE FROM ***;
data parameters1;
  mu = 2; sigma = 5;
run;


*** SIMULATE THE DATA ***;
%odsoff(notesyn=Y);
proc mcmc data    = parameters1
          outpost = sample1
          seed    = &&seed&_ii_. 
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
  simseed = &&seed&_ii_.;
run;

/**/
/**** DELETE THE PARAMETERS DATA AS WE DONT WANT TO KEEP ***;*/
/*proc datasets lib = work nolist;*/
/*  delete parameters1;*/
/*run;*/
