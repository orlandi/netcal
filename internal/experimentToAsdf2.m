function asdf2 = experimentToAsdf2(experiment, varargin)
% EXPERIMENTTOASDF2 converts an experiment to an ASDF2 structure (for use
% in the NCC tooblox)
%
% USAGE:
%    asdf2 = experimentToAsdf2(experiment)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% INPUT optional arguments
%
%    binSize - bin size (in seconds)
%
% OUTPUT arguments:
%    asdf2 - asdf2 structure
%
% EXAMPLE:
%    asdf2 = experimentToAsdf2(experiment)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also loadExperiment

% Define additional optional argument pairs
params.binsize = [];
params.pbar = [];
params.subset = [];
% Parse them
params = parse_pv_pairs(params, varargin);

asdf2 = struct;
if(~isempty(params.binsize))
% Pass to ms first
  asdf2.binsize = params.binsize*1e3;
  asdf2.nbins = round(experiment.numFrames/experiment.fps/params.binsize);
else
  asdf2.binsize = 1/experiment.fps*1e3;
  %	double	Number of time bins in the recording
  asdf2.nbins = round(experiment.numFrames);
end

%	double	Number of recorded channels (e.g., electrodes or neurons)
if(~isempty(params.subset))
  asdf2.nchannels = length(params.subset);
else
  asdf2.nchannels = length(experiment.ROI);
end
%	string	Type of experimental system
asdf2.expsys = 'calcium';
%	string	Data type (e.g., ?spikes? or ?LFP?)
asdf2.datatype = 'infered spikes';
%	string	Experiment specific identifier
asdf2.dataID = experiment.name;
% 	cell array	Spike or event times for each channel as a double vector
if(~isempty(params.subset))
  asdf2.raster = experiment.spikes(params.subset);
else
  asdf2.raster = experiment.spikes;
end
% Convert spikes to the nearest bin
for i = 1:length(asdf2.raster)
    spikeTimes = asdf2.raster{i}*1e3;
    spikeBins = floor(spikeTimes/asdf2.binsize);
    spikeBins(spikeBins == 0) = [];
    asdf2.raster{i} = spikeBins(:)';
end