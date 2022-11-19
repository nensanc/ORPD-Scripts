$title "AC Optimal Power Flow with unit commitment"
*_______________________________________________________________________________
* Filename: uc_polar_reactive.gms
* Description: Polar AC Multi-Period Optimal reactive Power Flow model
*
* Usage: gams uc_ac --case=/path/case.gdx
* --case=C:\Users\Jairo\Downloads\Prueba\models\case118_spring_wday_AC_UC_solution.gdx --obj=0 --times=1*24  --savesol=1
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

    V_shunt(bus,t)    "Bus shunt susceptance"
;
*integer variables
*    V_shunt(bus,t)    "Bus shunt susceptance"
*;

positive variables
    V_V(bus,t)              "Voltage real part at bus at time t"
    V_ratio(i,j,c,t)        "transformer tap ratio at time t"
*    V_shunt(bus,t)          "Bus shunt susceptance"

    V_pw_cost(gen,t)             "Generator piecewise cost"
    V_Pd_elastic(demandbid,t)    "Elastic incremental demand"
    V_demandbid_rev(demandbid,t) "Revenue from elastic incremental demand"


;

free variable V_objcost "Total cost of objective function";

parameters
    atBusSwitchedBs(bus)    "atSwitchedBs"
    atBusSlack(gen)         "atslack"
    numBs                   "step number of Bd"
    Slack                   "slack bus (swing)"
;


Slack = 1;
numBs = 1;

* Map gen in BusSlack
atBusSlack(gen)$(geninfo(gen,'atBus','given') eq Slack) = 1;

* Map Bs BusSwitched
atBusSwitchedBs(bus)$(businfo(bus,'Bs','given') ne 0) = 1;


* Voltage setpoint nodes pilot 1*24

table Vref(bus,t)  "Voltage reference of nodes pilot"
          1            2            3            4            5            6            7            8            9            10           11           12           13           14           15           16           17           18           19           20           21           22           23           24
1         0.980        0.980        0.980        0.980        0.980        0.980        1.020        1.020        1.020        1.040        1.040        1.040        1.020        1.020        1.020        1.020        1.020        1.020        1.040        1.040        1.040        0.990        0.990        0.990
2         0.980        0.980        0.980        0.980        0.980        0.980        1.020        1.020        1.020        1.040        1.040        1.040        1.020        1.020        1.020        1.020        1.020        1.020        1.040        1.040        1.040        0.990        0.990        0.990
3         0.980        0.980        0.980        0.980        0.980        0.980        1.020        1.020        1.020        1.040        1.040        1.040        1.020        1.020        1.020        1.020        1.020        1.020        1.040        1.040        1.040        0.990        0.990        0.990
15        0.980        0.980        0.980        0.980        0.980        0.980        1.020        1.020        1.020        1.040        1.040        1.040        1.020        1.020        1.020        1.020        1.020        1.020        1.040        1.040        1.040        0.990        0.990        0.990
4         0.921        0.921        0.921        0.921        0.921        0.921        0.961        0.961        0.961        0.981        0.981        0.981        0.961        0.961        0.961        0.961        0.961        0.961        0.981        0.981        0.981        0.931        0.931        0.931
5         0.921        0.921        0.921        0.921        0.921        0.921        0.961        0.961        0.961        0.981        0.981        0.981        0.961        0.961        0.961        0.961        0.961        0.961        0.981        0.981        0.981        0.931        0.931        0.931
6         0.921        0.921        0.921        0.921        0.921        0.921        0.961        0.961        0.961        0.981        0.981        0.981        0.961        0.961        0.961        0.961        0.961        0.961        0.981        0.981        0.981        0.931        0.931        0.931
18        0.921        0.921        0.921        0.921        0.921        0.921        0.961        0.961        0.961        0.981        0.981        0.981        0.961        0.961        0.961        0.961        0.961        0.961        0.981        0.981        0.981        0.931        0.931        0.931
19        0.921        0.921        0.921        0.921        0.921        0.921        0.961        0.961        0.961        0.981        0.981        0.981        0.961        0.961        0.961        0.961        0.961        0.961        0.981        0.981        0.981        0.931        0.931        0.931
20        0.921        0.921        0.921        0.921        0.921        0.921        0.961        0.961        0.961        0.981        0.981        0.981        0.961        0.961        0.961        0.961        0.961        0.961        0.981        0.981        0.981        0.931        0.931        0.931
10        0.926        0.926        0.926        0.926        0.926        0.926        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
49        0.926        0.926        0.926        0.926        0.926        0.926        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
50        0.926        0.926        0.926        0.926        0.926        0.926        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
51        0.926        0.926        0.926        0.926        0.926        0.926        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
12        0.955        0.955        0.955        0.955        0.955        0.955        0.995        0.995        0.995        1.015        1.015        1.015        0.995        0.995        0.995        0.995        0.995        0.995        1.015        1.015        1.015        0.965        0.965        0.965
16        0.955        0.955        0.955        0.955        0.955        0.955        0.995        0.995        0.995        1.015        1.015        1.015        0.995        0.995        0.995        0.995        0.995        0.995        1.015        1.015        1.015        0.965        0.965        0.965
17        0.955        0.955        0.955        0.955        0.955        0.955        0.995        0.995        0.995        1.015        1.015        1.015        0.995        0.995        0.995        0.995        0.995        0.995        1.015        1.015        1.015        0.965        0.965        0.965
11        0.919        0.919        0.919        0.919        0.919        0.919        0.959        0.959        0.959        0.979        0.979        0.979        0.959        0.959        0.959        0.959        0.959        0.959        0.979        0.979        0.979        0.929        0.929        0.929
13        0.919        0.919        0.919        0.919        0.919        0.919        0.959        0.959        0.959        0.979        0.979        0.979        0.959        0.959        0.959        0.959        0.959        0.959        0.979        0.979        0.979        0.929        0.929        0.929
14        0.919        0.919        0.919        0.919        0.919        0.919        0.959        0.959        0.959        0.979        0.979        0.979        0.959        0.959        0.959        0.959        0.959        0.959        0.979        0.979        0.979        0.929        0.929        0.929
21        0.950        0.950        0.950        0.950        0.950        0.950        0.990        0.990        0.990        1.010        1.010        1.010        0.990        0.990        0.990        0.990        0.990        0.990        1.010        1.010        1.010        0.960        0.960        0.960
22        0.950        0.950        0.950        0.950        0.950        0.950        0.990        0.990        0.990        1.010        1.010        1.010        0.990        0.990        0.990        0.990        0.990        0.990        1.010        1.010        1.010        0.960        0.960        0.960
23        0.950        0.950        0.950        0.950        0.950        0.950        0.990        0.990        0.990        1.010        1.010        1.010        0.990        0.990        0.990        0.990        0.990        0.990        1.010        1.010        1.010        0.960        0.960        0.960
24        0.950        0.950        0.950        0.950        0.950        0.950        0.990        0.990        0.990        1.010        1.010        1.010        0.990        0.990        0.990        0.990        0.990        0.990        1.010        1.010        1.010        0.960        0.960        0.960
38        0.950        0.950        0.950        0.950        0.950        0.950        0.990        0.990        0.990        1.010        1.010        1.010        0.990        0.990        0.990        0.990        0.990        0.990        1.010        1.010        1.010        0.960        0.960        0.960
44        0.950        0.950        0.950        0.950        0.950        0.950        0.990        0.990        0.990        1.010        1.010        1.010        0.990        0.990        0.990        0.990        0.990        0.990        1.010        1.010        1.010        0.960        0.960        0.960
45        0.950        0.950        0.950        0.950        0.950        0.950        0.990        0.990        0.990        1.010        1.010        1.010        0.990        0.990        0.990        0.990        0.990        0.990        1.010        1.010        1.010        0.960        0.960        0.960
7         0.930        0.930        0.930        0.930        0.930        0.930        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
8         0.930        0.930        0.930        0.930        0.930        0.930        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
9         0.930        0.930        0.930        0.930        0.930        0.930        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
29        0.930        0.930        0.930        0.930        0.930        0.930        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
52        0.930        0.930        0.930        0.930        0.930        0.930        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
53        0.930        0.930        0.930        0.930        0.930        0.930        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
54        0.930        0.930        0.930        0.930        0.930        0.930        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
55        0.930        0.930        0.930        0.930        0.930        0.930        0.966        0.966        0.966        0.986        0.986        0.986        0.966        0.966        0.966        0.966        0.966        0.966        0.986        0.986        0.986        0.936        0.936        0.936
25        0.876        0.876        0.876        0.876        0.876        0.876        0.916        0.916        0.916        0.936        0.936        0.936        0.916        0.916        0.916        0.916        0.916        0.916        0.936        0.936        0.936        0.886        0.886        0.886
26        0.876        0.876        0.876        0.876        0.876        0.876        0.916        0.916        0.916        0.936        0.936        0.936        0.916        0.916        0.916        0.916        0.916        0.916        0.936        0.936        0.936        0.886        0.886        0.886
27        0.876        0.876        0.876        0.876        0.876        0.876        0.916        0.916        0.916        0.936        0.936        0.936        0.916        0.916        0.916        0.916        0.916        0.916        0.936        0.936        0.936        0.886        0.886        0.886
28        0.876        0.876        0.876        0.876        0.876        0.876        0.916        0.916        0.916        0.936        0.936        0.936        0.916        0.916        0.916        0.916        0.916        0.916        0.936        0.936        0.936        0.886        0.886        0.886
30        0.876        0.876        0.876        0.876        0.876        0.876        0.916        0.916        0.916        0.936        0.936        0.936        0.916        0.916        0.916        0.916        0.916        0.916        0.936        0.936        0.936        0.886        0.886        0.886
31        0.876        0.876        0.876        0.876        0.876        0.876        0.916        0.916        0.916        0.936        0.936        0.936        0.916        0.916        0.916        0.916        0.916        0.916        0.936        0.936        0.936        0.886        0.886        0.886
32        0.876        0.876        0.876        0.876        0.876        0.876        0.916        0.916        0.916        0.936        0.936        0.936        0.916        0.916        0.916        0.916        0.916        0.916        0.936        0.936        0.936        0.886        0.886        0.886
33        0.876        0.876        0.876        0.876        0.876        0.876        0.916        0.916        0.916        0.936        0.936        0.936        0.916        0.916        0.916        0.916        0.916        0.916        0.936        0.936        0.936        0.886        0.886        0.886
34        0.876        0.876        0.876        0.876        0.876        0.876        0.916        0.916        0.916        0.936        0.936        0.936        0.916        0.916        0.916        0.916        0.916        0.916        0.936        0.936        0.936        0.886        0.886        0.886
35        0.876        0.876        0.876        0.876        0.876        0.876        0.916        0.916        0.916        0.936        0.936        0.936        0.916        0.916        0.916        0.916        0.916        0.916        0.936        0.936        0.936        0.886        0.886        0.886
36        0.916        0.916        0.916        0.916        0.916        0.916        0.956        0.956        0.956        0.976        0.976        0.976        0.956        0.956        0.956        0.956        0.956        0.956        0.976        0.976        0.976        0.926        0.926        0.926
37        0.916        0.916        0.916        0.916        0.916        0.916        0.956        0.956        0.956        0.976        0.976        0.976        0.956        0.956        0.956        0.956        0.956        0.956        0.976        0.976        0.976        0.926        0.926        0.926
39        0.916        0.916        0.916        0.916        0.916        0.916        0.956        0.956        0.956        0.976        0.976        0.976        0.956        0.956        0.956        0.956        0.956        0.956        0.976        0.976        0.976        0.926        0.926        0.926
40        0.916        0.916        0.916        0.916        0.916        0.916        0.956        0.956        0.956        0.976        0.976        0.976        0.956        0.956        0.956        0.956        0.956        0.956        0.976        0.976        0.976        0.926        0.926        0.926
56        0.916        0.916        0.916        0.916        0.916        0.916        0.956        0.956        0.956        0.976        0.976        0.976        0.956        0.956        0.956        0.956        0.956        0.956        0.976        0.976        0.976        0.926        0.926        0.926
57        0.916        0.916        0.916        0.916        0.916        0.916        0.956        0.956        0.956        0.976        0.976        0.976        0.956        0.956        0.956        0.956        0.956        0.956        0.976        0.976        0.976        0.926        0.926        0.926
41        0.936        0.936        0.936        0.936        0.936        0.936        0.976        0.976        0.976        0.996        0.996        0.996        0.976        0.976        0.976        0.976        0.976        0.976        0.996        0.996        0.996        0.946        0.946        0.946
42        0.936        0.936        0.936        0.936        0.936        0.936        0.976        0.976        0.976        0.996        0.996        0.996        0.976        0.976        0.976        0.976        0.976        0.976        0.996        0.996        0.996        0.946        0.946        0.946
43        0.936        0.936        0.936        0.936        0.936        0.936        0.976        0.976        0.976        0.996        0.996        0.996        0.976        0.976        0.976        0.976        0.976        0.976        0.996        0.996        0.996        0.946        0.946        0.946
46        0.967        0.967        0.967        0.967        0.967        0.967        1.007        1.007        1.007        1.027        1.027        1.027        1.007        1.007        1.007        1.007        1.007        1.007        1.027        1.027        1.027        0.977        0.977        0.977
47        0.967        0.967        0.967        0.967        0.967        0.967        1.007        1.007        1.007        1.027        1.027        1.027        1.007        1.007        1.007        1.007        1.007        1.007        1.027        1.027        1.027        0.977        0.977        0.977
48        0.967        0.967        0.967        0.967        0.967        0.967        1.007        1.007        1.007        1.027        1.027        1.027        1.007        1.007        1.007        1.007        1.007        1.007        1.027        1.027        1.027        0.977        0.977        0.977
;

*regulatory lower limit (voltage)
MaxVm(bus) = 1.1;
MinVm(bus) = 0.85;

*lower limit to avoid voltage collapse
MinVm('1') = 0.9097;
MinVm('4') = 0.9177;
MinVm('10') = 0.9244;
MinVm('12') = 0.9252;
MinVm('13') = 0.9039;
MinVm('22') = 0.8927;
MinVm('29') = 0.9274;
MinVm('31') = 0.8500;
MinVm('36') = 0.864;
MinVm('41') = 0.9119;
MinVm('48') = 0.9038;




*===== SECTION: EQUATION DEFINITION
equations
    c_SLimit(i,j,c,t)     "Apparent power limit on line ijc"
    c_LinePij(i,j,c,t)    "Real power flowing from bus i into bus j along line c"
    c_LinePji(i,j,c,t)    "Real power flowing from bus j into bus i along line c"
    c_LineQij(i,j,c,t)    "Reactive power flowing from bus i into bus j along line c"
    c_LineQji(i,j,c,t)    "Reactive power flowing from bus j into bus i along line c"

    c_BalanceP(bus,t) "Balance of real power for bus at time t"
    c_BalanceQ(bus,t) "Balance of reactive power for bus at time t"

    c_GenStatusMin(gen,t)  "Generator minimum operating capacity"
    c_GenStatusMax(gen,t)  "Generator maximum operating capacity"
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
          - Pd(i,t)
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

* ABS value shunt maneuver
c_ManeuverShuntP(bus,t)$(atBusSwitchedBs(bus) and ord(t) ge 2)..
    V_shunt(bus,t) - V_shunt(bus,t-1) =l= V_Ushunt(bus,t);
c_ManeuverShuntN(bus,t)$(atBusSwitchedBs(bus) and ord(t) ge 2)..
    V_shunt(bus,t-1) - V_shunt(bus,t) =l= V_Ushunt(bus,t)
;

* ABS value Tap ratio transformer maneuver
c_ManeuverTapP(i,j,c,t)$(transformer(i,j,c) and (ord(t) ge 2))..
    V_ratio(i,j,c,t) - V_ratio(i,j,c,t-1) =l= V_Uratio(i,j,c,t);
c_ManeuverTapN(i,j,c,t)$(transformer(i,j,c) and (ord(t) ge 2))..
    V_ratio(i,j,c,t-1) - V_ratio(i,j,c,t) =l= V_Uratio(i,j,c,t)
;

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
*option optca = 0.1;
*option optcr = 0.2;
*option iterLim = 5;

*===== SECTION: VARIABLE BOUNDS
* Generator active power generation limits
V_P.lo(gen,t) = 0;
V_P.up(gen,t) = Pmax(gen);

* Generator reactive power generation limits
V_Q.lo(gen,t) = min(Qmin(gen),0);
V_Q.up(gen,t) = Qmax(gen);

* Bus voltage magnitude limits
V_V.lo(bus,t) = MinVm(bus);
V_V.up(bus,t) = MaxVm(bus);

* Ratio tap transformer limits
V_ratio.lo(i,j,c,t)$(transformer(i,j,c)) = 0.9;
V_ratio.up(i,j,c,t)$(transformer(i,j,c)) = 1.1;

* Fix no swing bus power
V_P.fx(gen,t)$(not atBusSlack(gen)) = Pg(gen,t);

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
V_Uratio.l(i,j,c,t) = 0;
V_Ushunt.l(bus,t) = 0;
* Starting values may be provided in the data file
* Startup and shutdown variables are binary {0,1} via equations
V_genstatus.fx(gen,t) = status(gen,t);
V_genstatus.l(gen,t) = status(gen,t);

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
    + 0



*    + 0.01*sum((i,j,c,t)$(transformer(i,j,c) and (ord(t) ge 2)), sqr(V_ratio.l(i,j,c,t) - V_ratio.l(i,j,c,t-1)))

*    + 100000*sum((bus,t)$(Vref(bus,t)), sqr(V_V.l(bus,t)-Vref(bus,t)))

*    + 100*sum((gen,t), sqr(V_Q.l(gen,t)))

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
    Vg(bus,t)
    Vnp(bus,t)
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

* Generator voltage
    Vg(bus,t)$(businfo(bus,'type','given') ne 1) = Vm(bus,t);

* Voltage nodes pilot
    Vnp(bus,t)$(Vref(bus,t)) = Vm(bus,t);


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
