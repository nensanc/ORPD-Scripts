$ontext
Use given initial conditions for Rectangular ACOPF.
$offtext

$if not set timeperiod $abort "Time period not chosen, should default in model..."

$if not set filepath $setnames "%gams.i%" filepath filename fileextension
$call gams "%filepath%dcopf.gms" --genPmin=%genPmin% --allon=%allon% --linelimits=%linelimits% --case="%case%" --obj=%obj% gdx=dctemp.gdx lo=3 --timeperiod=%timeperiod% --verbose=%verbose%
if(errorlevel ne 0, abort "Failed to find a starting point using DCOPF!");

variables ic_Pg, ic_Va;

$GDXIN dctemp.gdx
$LOAD ic_Va = V_Theta
$GDXIN

execute 'rm "dctemp.gdx"' ;

Va(bus) = ic_Va.l(bus);

* Assume starting voltage magnitude of 1 p.u.
V_real.l(bus) = cos(Va(bus));
V_imag.l(bus) = sin(Va(bus));

$if %condensed% == 'no' $include '%filepath%ic_rect%sep%calc_derived_vars.gms'
* Set P(gen) and Q(gen) from AC power flow equations
scalar temp, count;
loop(i,
    count = sum(gen$(atBus(gen,i) and status(gen)), 1);
    temp = Pd(i)
$ifthen.ICcondensed %condensed% == 'no'
           + sum((j,c)$(branchstatus(j,i,c) or branchstatus(i,j,c)), V_LineP.l(i,j,c))
$elseif.ICcondensed %condensed% == 'yes'
           + sum((j,c)$(branchstatus(j,i,c) or branchstatus(i,j,c)),
                (g(i,j,c) / sqr(ratio(i,j,c)$branchstatus(i,j,c) + 1$branchstatus(j,i,c)))
                    * (sqr(V_real.l(i)) + sqr(V_imag.l(i)))
                - (1 / ratio(i,j,c))
                    * ( (g(i,j,c)*cos(angle(i,j,c)) - b(i,j,c)*sin(angle(i,j,c)))
                            * (V_real.l(i)*V_real.l(j) + V_imag.l(i)*V_imag.l(j))
                       +(b(i,j,c)*cos(angle(i,j,c)) + g(i,j,c)*sin(angle(i,j,c)))
                            * (V_real.l(j)*V_imag.l(i) - V_real.l(i)*V_imag.l(j)))
             )
$endif.ICcondensed
           + Gs(i) * (sqr(V_real.l(i)) + sqr(V_imag.l(i)));
    V_P.l(gen)$(atBus(gen,i) and status(gen)) = temp/count;

    temp = Qd(i)
$ifthen.ICcondensed2 %condensed% == 'no'
           + sum((j,c)$(branchstatus(j,i,c) or branchstatus(i,j,c)), V_LineQ.l(i,j,c))
$elseif.ICcondensed2 %condensed% == 'yes'
           + sum((j,c)$(branchstatus(j,i,c) or branchstatus(i,j,c)),
                - ((b(i,j,c) + bc(i,j,c)/2) / sqr(ratio(i,j,c)$branchstatus(i,j,c) + 1$branchstatus(j,i,c)))
                    * (sqr(V_real.l(i)) + sqr(V_imag.l(i)))
                - (1 / ratio(i,j,c))
                    * ( (g(i,j,c)*cos(angle(i,j,c)) - b(i,j,c)*sin(angle(i,j,c)))
                            * (V_real.l(j)*V_imag.l(i) - V_real.l(i)*V_imag.l(j))
                       -(b(i,j,c)*cos(angle(i,j,c)) + g(i,j,c)*sin(angle(i,j,c)))
                            * (V_real.l(i)*V_real.l(j) + V_imag.l(i)*V_imag.l(j)))
           )
$endif.ICcondensed2
           - Bs(i) * (sqr(V_real.l(i)) + sqr(V_imag.l(i)));
    V_Q.l(gen)$(atBus(gen,i) and status(gen)) = temp/count;
);

V_pw_cost.l(gen)$(status(gen) and (costmodel(gen) eq 1)) = max(0,
    smax(costptset$(ord(costptset) < numcostpts(gen)),
            ((costpts_y(gen,costptset+1) - costpts_y(gen,costptset))/
             (costpts_x(gen,costptset+1) - costpts_x(gen,costptset)))
              * (V_P.l(gen)*baseMVA - costpts_x(gen,costptset))
            + costpts_y(gen,costptset) - noloadcost(gen))$(numcostpts(gen) > 1))
;

V_objcost.l =
$ifthen.linear %obj% == "linear"
             sum(gen$(status(gen) and (costmodel(gen) eq 2)),
                             costcoef(gen,'0')
                           + costcoef(gen,'1')*P.l(gen)*baseMVA
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

