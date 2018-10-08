function [t,X] = CalciumDecay(p_gamma,p_carest,p_cacurrent,p_kappas,p_kd,p_conc,tspan)
% Uses ODE45 to solve Single-compartment model differential equation 
% 
% Fritjof Helmchen (helmchen@hifo.uzh.ch)
% Brain Research Institute,University of Zurich, Switzerland
% created: 7.10.2013, last update: 25.10.2013 fh

options=odeset('RelTol',1e-6);                          % set an error
Xo = p_cacurrent;                                       % initial conditions
mypar = [p_gamma,p_carest,p_kappas,p_kd,p_conc];        % parameters
[t,X] = ode45(@Relax2CaRest,tspan,Xo,options, mypar);   % call the solver, tspan should contain time vector with more than two elements

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [dx_dt]= Relax2CaRest(t,x,pp)
% differential equation describing the decay of calcium conc level to resting level in the presence
% of indicator dye with variable buffering capacity.
% paramters pp: 1 - gamma, 2 - ca_rest, 3 - kappaS, 4 - kd, 5 - indicator total concentration (all conc in nM) 
dx_dt =  -pp(1)* (x - pp(2))/(1 + pp(3) + pp(4)*pp(5)/(x + pp(4))^2); 
return
end

end