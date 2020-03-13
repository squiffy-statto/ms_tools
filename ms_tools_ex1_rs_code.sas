


%let seed&_ii_. = %sysevalf(&mainseed. + &_ii_.);
%put seed = &&seed&_ii_.;

data parameters;
  mu = 2; sigma = 5;
run;

%odsoff(notesyn=Y);
proc mcmc data    = parameters
          outpost = sample
          seed    = &&seed&_ii_. 
          nbi     = 0
          nmc     = &nsims.
          thin    = 1;
  parms x1;
  prior x1 ~ normal(mu, sd=sigma, lower=2, upper=3); 
  model general(1);
run;
%odson;

data sample;
  set sample;
  simseed = &&seed&_ii_.;
run;

proc datasets lib = work nolist;
  delete parameters;
run;
