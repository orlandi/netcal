function [ca_p, peel_p, exp_p] = configurePeeling(experiment, traces, varargin)
% CONFIGUREPEELING
%
% USAGE:
%    ROI = refineROI(stillImage, ROI, varargin)
%
% INPUT arguments:
%    stillImage - image to use in the ROI refinement
%
%    ROI - ROI list
%
% INPUT optional arguments ('key' followed by its value):
%    'verbose' - true/false. If true, outputs verbose information. Default:
%    true
%
% EXAMPLE:
%    ROI = refineROI(stillImage, ROI, varargin)
%
% Copyright (C) 2015, Javier G. Orlandi <javierorlandi@javierorlandi.com>
params.amp1 = [];
params.amp2 = [];
params.tau1 = [];
params.tau2 = [];
params.sdnoise = [];
params.smtthigh = 2.4;
params.smttlow = -1.2;
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

if(~isempty(params.sdnoise))
    peel_p.sdnoise = params.sdnoise;
else
    peel_p.sdnoise = mean(std(traces))*0.75;
end

peel_p.smtthigh = params.smtthigh*peel_p.sdnoise;
peel_p.smttlow = params.smttlow*peel_p.sdnoise;

exp_p.numpnts = size(traces,1);

if(params.verbose)
    MSG = 'Done!';
    fprintf([datestr(now, 'HH:MM:SS'), ' ', MSG '\n']);
    fprintf('----------------------------------\n');
end

