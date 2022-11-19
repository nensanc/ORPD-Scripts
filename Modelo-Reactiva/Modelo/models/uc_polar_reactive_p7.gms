$title "AC Optimal Power Flow with unit commitment"
*_______________________________________________________________________________
* Filename: uc_polar_reactive.gms
* Description: Polar AC Multi-Period Optimal reactive Power Flow model
*
* Usage: gams uc_ac --case=/path/case.gdx
*
* Options:
* --verbose: Supresses printout(0). Default=1
* --obj: Objective function, piecewise linear or quadratic. Default="pwl"
* --times: Select timeframe(s) to solve. Default provided by input file
* --linelimits: Type of line limit data to use. Default="given"
* --ramprates: Type of ramprate data to use. Default="given"
* --genPmin: Data for Generator lower limit. Default="given"
* --allon: Option to turn on all lines during solve. Default=none
* --slim: Option to turn on apparent power limits. Default=0
* --relax: Turn on relaxed integer option(1).Default=0.
* --savesol: Turn on save solution option(1). Default=0
*_______________________________________________________________________________

* System dependence
$if %system.filesys% == UNIX $set sep '/'
$if not %system.filesys% == UNIX $set sep '\'

*===== SECTION: OPTIONS & ENVIRONMENT VARIABLES
* Printout options
$ifthen %verbose% == 0
* Turn off print options
$offlisting
* Turn off solution printing
option solprint=off
option limrow=0, limcol=0
$endif

* Define filepath, name and extension.
$setnames "%gams.i%" filepath filename fileextension
* Define type of model
$set modeltype "AC"
* Define input case
$if not set case $abort "Model aborted. Please provide input case"
$setnames "%case%" casepath casename caseextension

* Default: Piecewise linear objective
$if not set obj $set obj "pwl"
* Default: elastic demand bidding turned off
$if not set demandbids $set demandbids 0
* Default: Use provided ramprates (as opposed to uwcalc)
$if not set ramprates $set ramprates "given"
* Default: Use provided line limits (as opposed to uwcalc)
$if not set linelimits $set linelimits "given"
* Default: Use provided generator lower limit
$if not set genPmin $set genPmin "given"
* Default: allon=0
$if not set allon $set allon 0
* Default: Use active power limits on line, instead of apparent limits
$if not set slim $set slim 0
* Default: Ignore D-curve constraints
$if not set qlim $set qlim 0
* Default: Relaxed MIP option turned off
$if not set relax $set relax 0
* Default: Save solution option turned off
$if not set savesol $set savesol 0


*===== SECTION: EXTRACT DATA
$batinclude "%filepath%extract_data_uc.gms" modeltype case times demandbids linelimits ramprates genPmin allon

*===== SECTION: DATA MANIPULATION


*--- Define load, gen buses and active lines
sets
    load(bus) "Load buses"
    isGen(bus) "Generator buses"
    isLine(i,j) "Active (i,j) line"
;

load(bus)$(sum(gen, atBus(gen,bus)) eq 0)  = 1;
isGen(bus)$(not(load(bus))) = 1;
option isLine < branchstatus;

*===== SECTION: VARIABLE DEFINITION
free variables
    V_P(gen,t)               "Real power generation of generator at time t"
    V_Q(gen,t)               "Reactive power generation of generator at time t"
    V_Theta(bus,t)           "Bus voltage angle"

    V_LineP(i,j,c,t)         "Real power flowing from bus i towards bus j on line c at time t"
    V_LineQ(i,j,c,t)         "Real power flowing from bus i towards bus j on line c at time t"
    V_interfaceP(i,j,c,t)    "Real power flow on interface (i,j,c) at time t"
;

binary variables
    V_genstatus(gen,t)       "Generator commitment status for time t"
    V_Uratio(i,j,c,t)        "(0,1) Maneuver Tap"
    V_Ushunt(bus,t)          "(0,1) Maneuver Shunt"

*    V_shunt(bus,t)    "Bus shunt susceptance"
;
*integer variables
*    V_shunt(bus,t)    "Bus shunt susceptance"
*;

positive variables
    V_V(bus,t)              "Voltage real part at bus at time t"
    V_ratio(i,j,c,t)        "transformer tap ratio at time t"

    V_shunt(bus,t)    "Bus shunt susceptance"

    V_pw_cost(gen,t) "Generator piecewise cost"
    V_Pd_elastic(demandbid,t) "Elastic incremental demand"
    V_demandbid_rev(demandbid,t) "Revenue from elastic incremental demand"


;

free variable V_objcost "Total cost of objective function";

parameter  atBusSwitchedBs(bus)    "atSwitchedBs";
parameter numBs;
atBusSwitchedBs(bus)$(businfo(bus,'Bs','given') ne 0) = 1;

numBs = 100;

*===== SECTION: EQUATION DEFINITION
equations
    c_SLimit(i,j,c,t)   "Apparent power limit on line ijc"
    c_LinePij(i,j,c,t)    "Real power flowing from bus i into bus j along line c"
    c_LinePji(i,j,c,t)    "Real power flowing from bus j into bus i along line c"
    c_LineQij(i,j,c,t)    "Reactive power flowing from bus i into bus j along line c"
    c_LineQji(i,j,c,t)    "Reactive power flowing from bus j into bus i along line c"

    c_BalanceP(bus,t) "Balance of real power for bus at time t"
    c_BalanceQ(bus,t) "Balance of reactive power for bus at time t"

    c_GenStatusMin(gen,t) "Generator minimum operating capacity"
    c_GenStatusMax(gen,t) "Generator maximum operating capacity"
    c_GenStatusQMin(gen,t) "Generator minimum operating capacity"
    c_GenStatusQMax(gen,t) "Generator maximum operating capacity"

    c_ManeuverTapP(i,j,c,t)   "Maneuver Tap Postive ABS"
    c_ManeuverTapN(i,j,c,t)   "Maneuver Tap Negative ABS"
    c_ManeuverShuntP(bus,t)   "Maneuver Shunt Negative ABS"
    c_ManeuverShuntN(bus,t)   "Maneuver Shunt Negative ABS"

    c_BinShunt(bus,t)         "Binary variable Shunt"
    c_BinTap(i,j,c,t)         "Binary variable Tap"

    c_InterfaceP(i,j,c,t) "Definition of real power on interfaces involving (i,j,c) at time"
    c_InterfaceLimit(interface,t) "Limit of real power on interface at time t"

    c_anglediffIJ(i,j,t) "Limit on (i,j) angle"
    c_anglediffJI(i,j,t) "Limit on (j,i) angle"

* If elastic bidding is turned on
$if %demandbids% ==1 c_demandbid_revenue(demandbid,t,demandbid_s) "Revenue from elastic demand"

    c_pw_cost(gen,t,costptset)
    c_obj
;



*===== SECTION: EQUATIONS PART 1
* Apparent power limit on line ijc
c_SLimit(i,j,c,t)$(branchstatus(i,j,c,t) or branchstatus(j,i,c,t))..
         sqr(V_LineP(i,j,c,t)) + sqr(V_LineQ(i,j,c,t)) =l= sqr(rateA(i,j,c));

* Real power flowing from bus i into bus j along line c
c_LinePij(i,j,c,t)$(branchstatus(i,j,c,t))..
         V_LineP(i,j,c,t) =e=
            (g(i,j,c) * sqr(V_V(i,t)) / sqr(V_ratio(i,j,c,t)))
            - (V_V(i,t) * V_V(j,t) / V_ratio(i,j,c,t)) *
                (  g(i,j,c) * cos(V_Theta(i,t) - V_Theta(j,t) - angle(i,j,c))
                 + b(i,j,c) * sin(V_Theta(i,t) - V_Theta(j,t) - angle(i,j,c)))
;

*Real power flowing from bus j into bus i along line c
c_LinePji(i,j,c,t)$(branchstatus(i,j,c,t))..
         V_LineP(j,i,c,t) =e=
           g(i,j,c) * sqr(V_V(j,t))
           - (V_V(i,t) * V_V(j,t) / V_ratio(i,j,c,t)) *
               (  g(i,j,c) * cos(V_Theta(j,t) - V_Theta(i,t) + angle(i,j,c))
                + b(i,j,c) * sin(V_Theta(j,t) - V_Theta(i,t) + angle(i,j,c)))
;

* Reactive power flowing from bus i into bus j along line c
c_LineQij(i,j,c,t)$(branchstatus(i,j,c,t))..
         V_LineQ(i,j,c,t) =e=
            - (sqr(V_V(i,t)) * (b(i,j,c) + bc(i,j,c)/2) / sqr(V_ratio(i,j,c,t)))
            - (V_V(i,t) * V_V(j,t) / V_ratio(i,j,c,t)) *
                (  g(i,j,c) * sin(V_Theta(i,t) - V_Theta(j,t) - angle(i,j,c))
                 - b(i,j,c) * cos(V_Theta(i,t) - V_Theta(j,t) - angle(i,j,c)))
;

* Reactive power flowing from bus j into bus i along line c
c_LineQji(i,j,c,t)$(branchstatus(i,j,c,t))..
         V_LineQ(j,i,c,t) =e=
            - (sqr(V_V(j,t)) * (b(i,j,c) + bc(i,j,c)/2))
            - (V_V(i,t) * V_V(j,t) / V_ratio(i,j,c,t)) *
                (  g(i,j,c) * sin(V_Theta(j,t) - V_Theta(i,t) + angle(i,j,c))
                 - b(i,j,c) * cos(V_Theta(j,t) - V_Theta(i,t) + angle(i,j,c)))
;


* Active power node balance eqn
c_BalanceP(i,t)$(type(i) ne 4)..
          sum(gen$(atBus(gen,i) and status(gen,t)), V_P(gen,t))
*          sum(gen$(atBus(gen,i) and status(gen,t) and (type(i) ne 3)), Pg(gen,t))
*          + sum(gen$(atBus(gen,i) and status(gen,t) and (type(i) eq 3)), V_P(gen,t))
          - Pd(i,t)
*          - sum(demandbid$demandbidmap(demandbid,i), V_Pd_elastic(demandbid,t))
            =e=
          sum((j,c)$(branchstatus(i,j,c,t)), V_LineP(i,j,c,t))
          + sum((j,c)$(branchstatus(j,i,c,t)), V_LineP(i,j,c,t))
          + sqr(V_V(i,t)) * Gs(i)
;

* Reactive power node balance eqn
c_BalanceQ(i,t)$(type(i) ne 4)..
          sum(gen$(atBus(gen,i) and status(gen,t)), V_Q(gen,t))
          - Qd(i,t)
            =e=
           sum((j,c)$(branchstatus(i,j,c,t)), V_LineQ(i,j,c,t))
          + sum((j,c)$(branchstatus(j,i,c,t)), V_LineQ(i,j,c,t))
          - (sqr(V_V(i,t)) * (Bs(i)/numBs) * V_shunt(i,t))$(atBusSwitchedBs(i))
*          -  ((Bs(i)/numBs) * V_shunt(i,t))
*          - sqr(V_V(i,t)) * sum(bus_s$(not sameas(bus_s,'given')), bswitched(i,bus_s) * V_shunt(i,bus_s,t))
;


* Definition of real power on interfaces involving (i,j,c) at time t
* Since we only care about interfaces in the specified direction, we don't need abs(LinePower)
c_InterfaceP(i,j,c,t)$((branchstatus(i,j,c,t) or branchstatus(j,i,c,t))
    and (sum(interface$interfacemap(interface,i,j), 1) ge 1))..
    V_interfaceP(i,j,c,t) =e= V_LineP(i,j,c,t);

* Limit of real power on interface at time t
c_InterfaceLimit(interface,t)..
sum((i,j,c)$(interfacemap(interface,i,j) and (branchstatus(i,j,c,t) or branchstatus(j,i,c,t))),
    V_interfaceP(i,j,c,t)) =l=  interfaceLimit(interface,t);

* Generator minimum operating capacity
c_GenStatusMin(gen,t)..
    V_genstatus(gen,t) * Pmin(gen) =l= V_P(gen,t)
;

* Generator maximum operating capacity
c_GenStatusMax(gen,t)..
    V_P(gen,t) =l= V_genstatus(gen,t) * Pmax(gen)
;

* Generator minimum operating capacity
c_GenStatusQMin(gen,t)..
    V_genstatus(gen,t) * Qmin(gen) =l= V_Q(gen,t)
;

* Generator maximum operating capacity
c_GenStatusQMax(gen,t)..
    V_Q(gen,t) =l= V_genstatus(gen,t) * Qmax(gen)
;


** Relationship of binary (start,shut,status) variables
*c_StartupShutdown(bus,bus_s,t)..
*    V_startup(bus,bus_s,t) - V_shutdown(bus,bus_s,t) =e= V_shunt(bus,bus_s,t) - V_shunt(bus,bus_s,t-1)
*;

** Relationship of logic binary (start,shut) variables
*c_StartupShutdownLogic(bus,bus_s,t)..
*    V_startup(bus,bus_s,t) + V_shutdown(bus,bus_s,t) =l= 1
*;

*$(atBusSwitchedBs(i))

* ABS value shunt maneuver
c_ManeuverShuntP(bus,t)$(atBusSwitchedBs(bus) and ord(t) ge 2)..
    V_shunt(bus,t) - V_shunt(bus,t-1) =l= V_Ushunt(bus,t);
c_ManeuverShuntN(bus,t)$(atBusSwitchedBs(bus) and ord(t) ge 2)..
    V_shunt(bus,t-1) - V_shunt(bus,t) =l= V_Ushunt(bus,t);

* ABS value Tap ratio transformer maneuver
c_ManeuverTapP(i,j,c,t)$(transformer(i,j,c) and (ord(t) ge 2))..
    V_ratio(i,j,c,t) - V_ratio(i,j,c,t-1) =l= V_Uratio(i,j,c,t);
c_ManeuverTapN(i,j,c,t)$(transformer(i,j,c) and (ord(t) ge 2))..
    V_ratio(i,j,c,t-1) - V_ratio(i,j,c,t) =l= V_Uratio(i,j,c,t);

* Binary Shunt and Tap variables
c_BinShunt(bus,t)$(atBusSwitchedBs(bus))..
    V_Ushunt(bus,t) * (1 - V_Ushunt(bus,t)) =e= 0;
c_BinTap(i,j,c,t)$(transformer(i,j,c))..
    V_Uratio(i,j,c,t) * (1 - V_Uratio(i,j,c,t)) =e= 0;

* Limit on (i,j) angle
c_anglediffIJ(i,j,t)$isLine(i,j)..
    V_Theta(i,t)-V_Theta(j,t) =l= pi/3;

* Limit on (j,i) angle
c_anglediffJI(i,j,t)$isLine(i,j)..
    V_Theta(j,t)-V_Theta(i,t) =l= pi/3;



table Vnp(bus,t)

          1            2            3            4            5            6            7            8            9            10           11           12           13           14           15           16           17           18           19           20           21           22           23           24
69        1.034        1.034        1.034        1.034        1.034        1.034        1.035        1.035        1.035        1.034        1.034        1.034        1.034        1.035        1.035        1.035        1.034        1.036        1.037        1.036        1.034        1.034        1.034        1.034
5         1.001        1.001        1.001        1.001        1.001        1.001        1.002        1.002        1.002        1.001        1.001        1.001        1.001        1.002        1.002        1.002        1.001        1.003        1.004        1.003        1.001        1.001        1.001        1.001
37        0.991        0.991        0.991        0.991        0.991        0.991        0.992        0.992        0.992        0.991        0.991        0.991        0.991        0.992        0.992        0.992        0.991        0.993        0.994        0.993        0.991        0.991        0.991        0.991
56        0.953        0.953        0.953        0.953        0.953        0.953        0.954        0.954        0.954        0.953        0.953        0.953        0.953        0.954        0.954        0.954        0.953        0.955        0.956        0.955        0.953        0.953        0.953        0.953
77        1.005        1.005        1.005        1.005        1.005        1.005        1.006        1.006        1.006        1.005        1.005        1.005        1.005        1.006        1.006        1.006        1.005        1.007        1.008        1.007        1.005        1.005        1.005        1.005
66        1.049        1.049        1.049        1.049        1.049        1.049        1.050        1.050        1.050        1.049        1.049        1.049        1.049        1.050        1.050        1.050        1.049        1.051        1.052        1.051        1.049        1.049        1.049        1.049
46        1.004        1.004        1.004        1.004        1.004        1.004        1.005        1.005        1.005        1.004        1.004        1.004        1.004        1.005        1.005        1.005        1.004        1.006        1.007        1.006        1.004        1.004        1.004        1.004
23        0.999        0.999        0.999        0.999        0.999        0.999        1.000        1.000        1.000        0.999        0.999        0.999        0.999        1.000        1.000        1.000        0.999        1.001        1.002        1.001        0.999        0.999        0.999        0.999
12        0.989        0.989        0.989        0.989        0.989        0.989        0.990        0.990        0.990        0.989        0.989        0.989        0.989        0.990        0.990        0.990        0.989        0.991        0.992        0.991        0.989        0.989        0.989        0.989
70        0.983        0.983        0.983        0.983        0.983        0.983        0.984        0.984        0.984        0.983        0.983        0.983        0.983        0.984        0.984        0.984        0.983        0.985        0.986        0.985        0.983        0.983        0.983        0.983
17        0.994        0.994        0.994        0.994        0.994        0.994        0.995        0.995        0.995        0.994        0.994        0.994        0.994        0.995        0.995        0.995        0.994        0.996        0.997        0.996        0.994        0.994        0.994        0.994
63        0.968        0.968        0.968        0.968        0.968        0.968        0.969        0.969        0.969        0.968        0.968        0.968        0.968        0.969        0.969        0.969        0.968        0.970        0.971        0.970        0.968        0.968        0.968        0.968
80        1.039        1.039        1.039        1.039        1.039        1.039        1.040        1.040        1.040        1.039        1.039        1.039        1.039        1.040        1.040        1.040        1.039        1.041        1.042        1.041        1.039        1.039        1.039        1.039
8         1.014        1.014        1.014        1.014        1.014        1.014        1.015        1.015        1.015        1.014        1.014        1.014        1.014        1.015        1.015        1.015        1.014        1.016        1.017        1.016        1.014        1.014        1.014        1.014
49        1.024        1.024        1.024        1.024        1.024        1.024        1.025        1.025        1.025        1.024        1.024        1.024        1.024        1.025        1.025        1.025        1.024        1.026        1.027        1.026        1.024        1.024        1.024        1.024
32        0.963        0.963        0.963        0.963        0.963        0.963        0.964        0.964        0.964        0.963        0.963        0.963        0.963        0.964        0.964        0.964        0.963        0.965        0.966        0.965        0.963        0.963        0.963        0.963
;

* Objective functions and pwl costs are listed in a separate file
$batinclude "%filepath%cost_objective_uc.gms" obj

*===== SECTION: MODEL DEFINITION
model feas /c_LinePij, c_LinePji, c_LineQij, c_LineQji,
            c_BalanceP, c_BalanceQ, c_GenStatusMin, c_GenStatusMax, c_GenStatusQMin, c_GenStatusQMax,
*            c_StartupShutdown, c_StartupShutdownLogic,
**            c_ManeuverShuntP, c_ManeuverShuntN, c_ManeuverTapP, c_ManeuverTapN,
*            c_BinShunt,
*            c_BinTap,
            c_InterfaceP, c_InterfaceLimit,
            c_anglediffIJ, c_anglediffJI
$if %slim% == 1 , c_SLimit
$if %demandbids% == 1 , c_demandbid_revenue
      /;
model uc_ac /feas, c_obj/;

*===== SECTION: VARIABLE BOUNDS
* Generator active power generation limits
V_P.lo(gen,t) = 0;
V_P.up(gen,t) = Pmax(gen);

$ifthen %wind%==1
* Needed to avoid compilation error. Puts strings into UEL
set winddesc /
'PrimeMover', 'pm_WT'/;
* Wind turbines are not reliable sources of power, treated differently
parameter windTurbine(gen);
windTurbine(gen)$(geninfo(gen, 'PrimeMover', 'pm_WT') eq 1) = 1;
V_P.fx(gen,t)$(windTurbine(gen)) = 0;
$endif

*set  BusSlack(bus)    "slack" ;
*parameter BusSl    "slack" ;
* Bus type
*BusSlack.fx(bus)$(type(bus) eq 3) = ord(bus);
*BusSlack(bus) = no;


*BusSlack(bus) = yes $ (type(bus) eq 3);
*BusSl = card(BusSlack);


*transformer_s(i,j,c)$transformer(i,j,c) = 1*24;



parameter  atBusSlack(gen)    "atslack";
parameter  Slack;

parameter Vg(bus,t);

*Vg(bus,gen,t)$((businfo(bus,'type','given') ne 1) and (geninfo(gen,'atBus','given'))) = Vm(bus,t);

Vg(bus,t)$(businfo(bus,'type','given') ne 1) = Vm(bus,t);



**






*atBusNodePilot(bus)$(businfo(bus,'atBus','given') eq Vnp(bus,t)) = 1;


**

* Voltage magnitude solution
*    Vm(bus,t)  = V_V.l(bus,t);


Slack = 69;



atBusSlack(gen)$(geninfo(gen,'atBus','given') eq Slack) = 1;
V_P.fx(gen,t)$(not atBusSlack(gen)) = Pg(gen,t);



* Generator reactive power generation limits
V_Q.lo(gen,t) = min(Qmin(gen),0);
V_Q.up(gen,t) = Qmax(gen);

* Bus voltage magnitude limits
V_V.lo(bus,t) = MinVm(bus);
V_V.up(bus,t) = MaxVm(bus);

* Ratio tap transformer limits
V_ratio.lo(i,j,c,t)$(transformer(i,j,c)) = 0.9;
V_ratio.up(i,j,c,t)$(transformer(i,j,c)) = 1.1;

* Fix swing bus angle
V_Theta.fx(bus,t)$(type(bus) eq 3) = 0;

$ifthene %slim%<>1
* Line real power flow limits
V_LineP.lo(i,j,c,t)$branchstatus(i,j,c,t) = -rateA(i,j,c);
V_LineP.up(i,j,c,t)$branchstatus(i,j,c,t) =  rateA(i,j,c);
V_LineP.lo(j,i,c,t)$(branchstatus(i,j,c,t)) = -rateA(i,j,c);
V_LineP.up(j,i,c,t)$(branchstatus(i,j,c,t)) =  rateA(i,j,c);
$endif

* Bus shunt susceptance
V_shunt.up(bus,t) = numBs;

*V_Ushunt.up(bus,t) = 1;
*V_Uratio.up(i,j,c,t) = 1;
V_Uratio.l(i,j,c,t) = 0;
V_Ushunt.l(bus,t) = 0;


*--- Elastic demand
* If user chooses option --demandbids=0, no elastic demand is considered
* Otherwise, set bounds on elastic demand
$ifthen.nobids %demandbids% == 0
  V_Pd_elastic.fx(demandbid,t) = 0;
  V_demandbid_rev.fx(demandbid,t) = 0;
$else.nobids
  V_Pd_elastic.lo(demandbid,t) = smin(demandbid_s, demandpts_x(demandbid,t,demandbid_s))/baseMVA;
  V_Pd_elastic.up(demandbid,t) = smax(demandbid_s, demandpts_x(demandbid,t,demandbid_s))/baseMVA;
  V_demandbid_rev.lo(demandbid,t) = smin(demandbid_s, demandpts_y(demandbid,t,demandbid_s));
  V_demandbid_rev.up(demandbid,t) = smax(demandbid_s, demandpts_y(demandbid,t,demandbid_s));
$endif.nobids


*===== SECTION: VARIABLE INITIAL STARTING POINTS
V_shunt.l(bus,t)  = numBs;

* Starting values may be provided in the data file
* Startup and shutdown variables are binary {0,1} via equations



V_genstatus.fx(gen,t) = status(gen,t);
V_genstatus.l(gen,t) = status(gen,t);


*V_startup.l(gen,t)  = max(0, status(gen,t)-status(gen,t-1));
*V_shutdown.l(gen,t) = max(0, status(gen,t-1)-status(gen,t));

V_P.l(gen,t) = Pg(gen,t);
V_Q.l(gen,t) = Qg(gen,t);
V_V.l(bus,t) = Vm(bus,t);
V_Theta.l(bus,t)$(type(bus) ne 3) = Va(bus,t);
V_ratio.fx(i,j,c,t)$(not transformer(i,j,c)) = ratio(i,j,c);
V_ratio.l(i,j,c,t) = ratio(i,j,c);

* Derived variables
V_LineP.l(i,j,c,t)$branchstatus(i,j,c,t) =  (g(i,j,c) * sqr(V_V.l(i,t)) / sqr(V_ratio.l(i,j,c,t)))
            - (V_V.l(i,t) * V_V.l(j,t) / V_ratio.l(i,j,c,t)) *
                (  g(i,j,c) * cos(V_Theta.l(i,t) - V_Theta.l(j,t) - angle(i,j,c))
                 + b(i,j,c) * sin(V_Theta.l(i,t) - V_Theta.l(j,t) - angle(i,j,c)));

 V_LineP.l(j,i,c,t)$branchstatus(i,j,c,t) = g(i,j,c) * sqr(V_V.l(j,t))
           - (V_V.l(i,t) * V_V.l(j,t) / V_ratio.l(i,j,c,t)) *
               (  g(i,j,c) * cos(V_Theta.l(j,t) - V_Theta.l(i,t) + angle(i,j,c))
                + b(i,j,c) * sin(V_Theta.l(j,t) - V_Theta.l(i,t) + angle(i,j,c)));

 V_LineQ.l(i,j,c,t)$branchstatus(i,j,c,t) = - (sqr(V_V.l(i,t)) * (b(i,j,c) + bc(i,j,c)/2) / sqr(V_ratio.l(i,j,c,t)))
            - (V_V.l(i,t) * V_V.l(j,t) / V_ratio.l(i,j,c,t)) *
                (  g(i,j,c) * sin(V_Theta.l(i,t) - V_Theta.l(j,t) - angle(i,j,c))
                 - b(i,j,c) * cos(V_Theta.l(i,t) - V_Theta.l(j,t) - angle(i,j,c)));

 V_LineQ.l(j,i,c,t)$branchstatus(i,j,c,t) =  - (sqr(V_V.l(j,t)) * (b(i,j,c) + bc(i,j,c)/2))
            - (V_V.l(i,t) * V_V.l(j,t) / V_ratio.l(i,j,c,t)) *
                (  g(i,j,c) * sin(V_Theta.l(j,t) - V_Theta.l(i,t) + angle(i,j,c))
                 - b(i,j,c) * cos(V_Theta.l(j,t) - V_Theta.l(i,t) + angle(i,j,c)));

V_interfaceP.l(i,j,c,t)$((branchstatus(i,j,c,t) or branchstatus(j,i,c,t))
    and (sum(interface$interfacemap(interface,i,j), 1) ge 1)) = V_LineP.l(i,j,c,t);

* Derived objective function
V_pw_cost.l(gen,t) = max(0,smax((costptset)$((ord(costptset) < numcostpts(gen)) and (costmodel(gen) eq 1)),
    ((costpts_y(gen,costptset+1) - costpts_y(gen,costptset))/
     (costpts_x(gen,costptset+1) - costpts_x(gen,costptset)))
      * (V_P.l(gen,t)*baseMVA - costpts_x(gen,costptset))
    + costpts_y(gen,costptset)*V_genstatus.l(gen,t)))
;


V_objcost.l =
$iftheni.obj0L %obj% == 0
    0
$else.obj0L
    + sum((gen,t),V_startup.l(gen,t)*startupcost(gen) + V_shutdown.l(gen,t)*shutdowncost(gen))
$iftheni.solL %obj% == "pwl"
* Piecewise linear objective function
    + sum((gen,t)$(costmodel(gen) eq 1), V_pw_cost.l(gen,t))
$elseifi.solL %obj% == "quad"
* Quadratic objective function
    + sum((gen,t)$(costmodel(gen) eq 2),costcoef(gen,'0')*V_genstatus.l(gen,t)
        + costcoef(gen,'1')*V_P.l(gen,t)*baseMVA
        + costcoef(gen,'2')*sqr(V_P.l(gen,t)*baseMVA))
$elseifi.solL %obj% == "linear"
* Linear objective function
    + sum((gen,t)$(costmodel(gen) eq 2),costcoef(gen,'0')*V_genstatus.l(gen,t)
        + costcoef(gen,'1')*V_P.l(gen,t)*baseMVA)
$endif.solL
$endif.obj0L
;

*display rampup, rampdown, minuptime, mindowntime;

*===== SECTION: MODEL OPTIONS AND SOLVE
*---- Basic options



$ifthen.rminlp %relax% == 1
    solve uc_ac min V_objcost using rminlp;
$else.rminlp
    solve uc_ac min V_objcost using minlp;
$endif.rminlp



*==== SECTION: Solution Analysis
* See if model is solved
parameter
    infeas "Number of infeasibilities from model solve";





infeas = uc_ac.numInfes;
display infeas;

* Declaration needs to be made outside loop
set
    lines_at_limit(i,j,c,t) "lines at their bound"
;
parameters
    total_cost "Cost of objective function"
    LMP(bus,t) "Locational marginal price"
    LineSP(i,j,c,t) "Marginal price of active power on line (i,j,c)"
    shuntB(i,t)
    Tap(i,j,c,t)
    UTap(i,j,c,t)
    UshuntB(i,t)
    shuntStep(i,t)
;




if(infeas eq 0,
* Final Objective function value
    total_cost = V_objcost.l;
* Status information
    status(gen,t) = V_genstatus.l(gen,t);
* Generator real power solution
    Pg(gen,t) = V_P.l(gen,t);
* Generator reactive power solution
    Qg(gen,t) = V_Q.l(gen,t);
* Voltage magnitude solution
    Vm(bus,t)  = V_V.l(bus,t);
* Voltage angle solution
    Va(bus,t)  = V_Theta.l(bus,t)/pi*180;
* Bus shunt solution
    shuntB(i,t)$(atBusSwitchedBs(i))  = Bs(i) * V_shunt.l(i,t) / numBs;

    shuntStep(i,t)$(atBusSwitchedBs(i)) = V_shunt.l(i,t);

    UshuntB(i,t) = V_Ushunt.l(i,t);

* Locational marginal price of bus at time t
    LMP(bus,t) = c_BalanceP.m(bus,t);
* Marginal for active power on a line
    LineSP(i,j,c,t)$branchstatus(i,j,c,t) = V_LineP.m(i,j,c,t)$(abs(V_LineP.m(i,j,c,t)) > Eps);
    LineSP(j,i,c,t)$branchstatus(i,j,c,t) = V_LineP.m(j,i,c,t)$(abs(V_LineP.m(j,i,c,t)) > Eps);
* Ratio tap transformer
    Tap(i,j,c,t)$transformer(i,j,c) =  V_ratio.l(i,j,c,t);

    UTap(i,j,c,t) = V_Uratio.l(i,j,c,t);




* Find which lines are at their limits
lines_at_limit(i,j,c,t)$branchstatus(i,j,c,t) = yes$(abs(LineSP(i,j,c,t)) gt 1e-8);
display lines_at_limit;




*==== SECTION: Solution Save
$ifthen %savesol% == 1
execute_unload '%filepath%ALL_solution.gdx';
execute_unload '%filepath%temp_solution.gdx', t, Pg, Qg, Vm, Va, shuntB, total_cost, LMP, LineSP, status, Tap, UTap, UshuntB, shuntStep;
execute 'gams %filepath%save_solution_uc.gms gdxcompress=1 --ac=1 --uc=1 --timeperiod=%timeperiod% --case=%case% --solution=%filepath%temp_solution.gdx --out=%filepath%%casename%_AC_UC_solution.gdx lo=3'
if(errorlevel ne 0, abort "Saving solution failed!");
execute 'rm %filepath%temp_solution.gdx'
$endif

* END IF-loop if(infeas eq 0)
);
