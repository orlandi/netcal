function [spkTout,output] = PeelingOptimizeSpikeTimesSaturation(dff,spkTin,lowerT,upperT,...
    ca_amp,ca_gamma,ca_onsettau,ca_rest, ca_kappas, kd, conc, dffmax, frameRate, dur, optimMethod,maxIter,doPlot)
% optimization of spike times found by Peeling algorithm
% minimize the sum of the residual squared
% while several optimization algorithms are implemented (see below), we have only used pattern
% search. Other algorithms are only provided for convenience and are not tested sufficiently.
%
% Henry Luetcke (hluetck@gmail.com)
% Brain Research Institut
% University of Zurich
% Switzerland

spkTout = spkTin;
t = (1:numel(dff))./frameRate;

ca = spkTimes2FreeCalcium(spkTin,ca_amp,ca_gamma,ca_onsettau,ca_rest, ca_kappas,...
                                    kd, conc,frameRate,dur);
modeltmp = Calcium2Fluor(ca,ca_rest,kd,dffmax);
model = modeltmp(1:length(dff));

if doPlot
    figure('Name','Before Optimization')
    plot(t,dff,'k'), hold on, plot(t,model,'r'), plot(t,dff-model,'b')
    legend('DFF','Model','Residual')
end

residual = dff - model;
resInit = sum(residual.^2);

% start optimization
x0 = spkTin;
lbound = spkTin - lowerT;
lbound(lbound<0) = 0;
ubound = spkTin + upperT;
ubound(ubound>max(t)) = max(t);

lbound = zeros(size(spkTin));
ubound = repmat(max(t),size(spkTin));

opt_args.dff = dff;
opt_args.ca_rest = ca_rest;
opt_args.ca_amp = ca_amp;
opt_args.ca_gamma = ca_gamma;
opt_args.ca_onsettau = ca_onsettau;
opt_args.ca_kappas = ca_kappas;
opt_args.kd = kd;
opt_args.conc = conc;
opt_args.dffmax = dffmax;
opt_args.frameRate = frameRate;
opt_args.dur = dur;

optimClock = tic;

switch lower(optimMethod)
    case 'simulated annealing'
        options = saoptimset;
    case 'pattern search'
        options = psoptimset;
    case 'genetic'
        options = gaoptimset;
    otherwise
        error('Optimization method %s not supported.',optimMethod)
end

% options for optimization algorithms
% not all options are used for all algorithms
options.Display = 'off';
options.MaxIter = maxIter;
options.MaxIter = Inf;
options.UseParallel = 'always';
options.ObjectiveLimit = 0;
options.TimeLimit = 10; % in s / default is Inf

% experimental
options.MeshAccelerator = 'on'; % off by default
options.TolFun = 1e-9; % default is 1e-6
options.TolMesh = 1e-9; % default is 1e-6
options.TolX = 1e-9; % default is 1e-6
% options.MaxFunEvals = numel(spkTin)*100; % default is 2000*numberOfVariables
% options.MaxFunEvals = 20000;

options.Display = 'none';
% options.Display = 'final';

% options.PlotFcns = {@psplotbestf @psplotbestx};
% options.OutputFcns = @psoutputfcn_peel;

switch lower(optimMethod)
    case 'simulated annealing'
        [x, fval , exitFlag, output] = simulannealbnd(...
            @(x) objectiveFunc(x,opt_args),x0,lbound,ubound,options);
    case 'pattern search'
        [x, fval , exitFlag, output] = patternsearch(...
            @(x) objectiveFunc(x,opt_args),x0,[],[],[],[],lbound,...
            ubound,[],options);
    case 'genetic'
        [x, fval , exitFlag, output] = ga(...
            @(x) objectiveFunc(x,opt_args),numel(x0),[],[],[],[],lbound,...
            ubound,[],options);
end

if fval < resInit
    spkTout = x;
else
    disp('Optimization did not improve residual. Keeping input spike times.')
end

if doPlot
    fprintf('Optimization time (%s): %1.2f s\n',optimMethod,toc(optimClock))
    fprintf('Final squared residual: %1.2f (Change: %1.2f)\n',fval,resInit-fval);
    spkVector = zeros(1,numel(t));
    for i = 1:numel(spkTout)
        [~,idx] = min(abs(spkTout(i)-t));
        spkVector(idx) = spkVector(idx)+1;
    end
    model = conv(spkVector,modelTransient);
    model = model(1:length(t));
    figure('Name','After Optimization')
    plot(t,dff,'k'), hold on, plot(t,model,'r'), plot(t,dff-model,'b')
    legend('DFF','Model','Residual')
end


function residual = objectiveFunc(spkTin,opt_args)

dff = opt_args.dff;
ca_rest = opt_args.ca_rest;
ca_amp = opt_args.ca_amp;
ca_gamma = opt_args.ca_gamma;
ca_onsettau = opt_args.ca_onsettau;
ca_kappas = opt_args.ca_kappas;
kd = opt_args.kd;
conc = opt_args.conc;
dffmax = opt_args.dffmax;
frameRate = opt_args.frameRate;
dur = opt_args.dur;

ca = spkTimes2FreeCalcium(sort(spkTin),ca_amp,ca_gamma,ca_onsettau,ca_rest, ca_kappas,...
                                    kd, conc,frameRate,dur);
modeltmp = Calcium2Fluor(ca,ca_rest,kd,dffmax);
model = modeltmp(1:length(dff));

residual = dff-model;
residual = sum(residual.^2);








