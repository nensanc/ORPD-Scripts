$ontext
Use given initial conditions for Polar ACOPF.
$offtext

$if not set timeperiod $abort "Time period not chosen, should default in model..."

$if not set filepath $setnames "%gams.i%" filepath filename fileextension
$call gams "%filepath%polar_acopf.gms" --genPmin=%genPmin% --allon=%allon% --linelimits=%linelimits% --case="%case%" --obj=%obj% gdx=polartemp.gdx lo=3 --timeperiod=%timeperiod% reslim=3600 nlp=ipopth --verbose=%verbose% 
if(errorlevel ne 0, abort "Failed to find a starting point using rec-ACOPF!");

variables V_V, V_Theta, ic_Pg, ic_Qg, ic_shunt;

$GDXIN polartemp.gdx
$LOAD ic_Pg=V_P, ic_Qg=V_Q, V_V, V_Theta, ic_shunt=V_shunt
$GDXIN

execute 'rm "polartemp.gdx"' ;

V_P.l(gen) = ic_Pg.l(gen);
V_Q.l(gen) = ic_Qg.l(gen);
V_real.l(bus) = V_V.l(bus)*cos(V_Theta.l(bus));
V_imag.l(bus) = V_V.l(bus)*sin(V_Theta.l(bus));
V_shunt.l(bus,bus_s) = ic_shunt.l(bus,bus_s);


$if %condensed% == 'no' $include '%filepath%ic_iv%sep%calc_derived_vars.gms'
* Set cost level from decoupled solution point
V_pw_cost.l(gen)$(status(gen) and (costmodel(gen) eq 1)) = max(0,
    smax(costptset$(ord(costptset) < numcostpts(gen)),
            ((costpts_y(gen,costptset+1) - costpts_y(gen,costptset))/
             (costpts_x(gen,costptset+1) - costpts_x(gen,costptset)))
              * (V_P.l(gen)*baseMVA - costpts_x(gen,costptset))
            + costpts_y(gen,costptset) - noloadcost(gen)))
;

V_objcost.l =
$ifthen.linear %obj% == "linear"
             sum(gen$(status(gen) and (costmodel(gen) eq 2)),
                             costcoef(gen,'0')
                           + costcoef(gen,'1')*V_P.l(gen)*baseMVA
                )
$else.linear
             sum(gen$(status(gen) and (costmodel(gen) eq 2)),
                             costcoef(gen,'0')
                           + costcoef(gen,'1')*V_P.l(gen)*baseMVA
                           + costcoef(gen,'2')*sqr(V_P.l(gen)*baseMVA)
                )
$endif.linear
           + sum(gen$(status(gen) and (costmodel(gen) eq 1)), V_pw_cost.l(gen)
                                                              + noloadcost(gen))
;

