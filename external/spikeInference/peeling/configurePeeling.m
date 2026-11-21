function [ca_p, peel_p, exp_p] = configurePeeling(experiment, traces, varargin)
% CONFIGUREPEELING
%
% USAGE:
%    ROI = configurePeeling(experiment, traces, varargin)
%
% INPUT arguments:
% TODO
%
% INPUT optional arguments ('key' followed by its value):
%    'verbose' - true/false. If true, outputs verbose information. Default:
%    true
%
% EXAMPLE:
%    ROI = refineROI(stillImage, ROI, varargin)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
params.amp1 = [];
params.amp2 = [];
params.tau1 = [];
params.tau2 = [];
params.standardNoise = [];
params.schmittThresholds = [2.4, -1.2];
params.optimizationMethod = 'none';
params.calciumMode = 'linDFF';
params.additionalPlots = false;
params.gamma = 400;
params.dffmax = 93;
params.verbose = true;
params = parse_pv_pairs(params, varargin);

if(params.verbose)
    fprintf('\n----------------------------------\n');
    MSG = 'Configuring Peeling algorihtm';
    fprintf([datestr(now, 'HH:MM:SS'), ' ', MSG '\n']);
end

[ca_p, peel_p, exp_p, ~] = Peeling(zeros(1, 100), experiment.fps);

if(~isempty(params.amp1))
    ca_p.amp1 = params.amp1;
end
if(~isempty(params.amp2))
    ca_p.amp2 = params.amp2;
end
if(~isempty(params.tau1))
    ca_p.tau1 = params.tau1;
end
if(~isempty(params.tau2))
    ca_p.tau2 = params.tau2;
end
if(~isempty(params.calciumMode))
    ca_p.ca_genmode = params.calciumMode;
    peel_p.spk_recmode = params.calciumMode;
end
if(~isempty(params.optimizationMethod))
  peel_p.optimizationMethod = params.optimizationMethod;
end
if(~isempty(params.standardNoise))
    peel_p.sdnoise = params.standardNoise;
else
    peel_p.sdnoise = mean(std(traces))*0.75;
end

ca_p.ca_gamma = params.gamma;
exp_p.dffmax = params.dffmax;

peel_p.doPlot = params.additionalPlots;
peel_p.smtthigh = params.schmittThresholds(1)*peel_p.sdnoise;
peel_p.smttlow = params.schmittThresholds(2)*peel_p.sdnoise;

exp_p.numpnts = size(traces,1);

if(params.verbose)
    MSG = 'Done!';
    fprintf([datestr(now, 'HH:MM:SS'), ' ', MSG '\n']);
    fprintf('----------------------------------\n');
end

