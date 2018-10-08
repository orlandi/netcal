function [spkTout,output] = PeelingOptimizeSpikeTimes(dff,spkTin,lowerT,upperT,...
    rate,tauOn,A1,tau1,optimMethod,maxIter,doPlot)
% optimization of spike times found by Peeling algorithm
% minimize the sum of the residual squared
% while several optimization algorithms are implemented (see below), we have only used pattern
% search. Other algorithms are only provided for convenience and are not tested sufficiently.
%
% Henry Luetcke (hluetck@gmail.com)
% Brain Research Institut
% University of Zurich
% Switzerland

t = (1:numel(dff))./rate;

modelTransient = modelCalciumTransient(t,t(1),tauOn,A1,tau1);
modelTransient = modelTransient';

spkTout = spkTin;

spkVector = zeros(1,numel(t));
for i = 1:numel(spkTin)
    [~,idx] = min(abs(spkTin(i)-t));
    spkVector(idx) = spkVector(idx)+1;
end
model = conv(spkVector,modelTransient);
model = model(1:length(t));

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
opt_args.rate = rate;
opt_args.tauOn = tauOn;
opt_args.A1 = A1;
opt_args.tau1 = tau1;
optimClock = tic;

switch lower(optimMethod)
    case 'simulated annealing'
        options = saoptimset;
    case 'pattern search'
        options = psoptimset;
    case 'genetic'
        options = gaoptimset;
    case 'none'
        options = psoptimset;
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
% options.TimeLimit = 10; % in s / default is Inf

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
  case 'none'
        fval = inf;
end

if fval < resInit
    spkTout = x;
elseif(~strcmpi(optimMethod, 'none'))
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
rate = opt_args.rate;
tauOn = opt_args.tauOn;
A1 = opt_args.A1;
tau1 = opt_args.tau1;
t = (1:numel(dff))./rate;
modelTransient = spkTimes2Calcium(0,tauOn,A1,tau1,0,0,rate,max(t));
spkVector = zeros(1,numel(t));
for i = 1:numel(spkTin)
    [~,idx] = min(abs(spkTin(i)-t));
    spkVector(idx) = spkVector(idx)+1;
end
model = conv(spkVector,modelTransient);
model = model(1:length(t));
residual = dff-model;
residual = sum(residual.^2);








