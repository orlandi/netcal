function experiment = importCascadePredictions(experiment, varargin)
% IMPORTCASCADEPREDICTIONS exports spike data
%
% USAGE:
%    experiment = exportBurstStatistics(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: baseOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = importCascadePredictions(experiment)
%
% Copyright (C) 2016-2016, Javier G. Orlandi <javier.orlandi@ucalgary.ca>

% EXPERIMENT PIPELINE
% name: import cascade predictions
% parentGroups: spikes
% optionsClass: baseOptions
% requiredFields: spikes, ROI, folder, name

[params, var] = processFunctionStartup(baseOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Importing cascade predictions', true);
%--------------------------------------------------------------------------

% Check if its a project or an experiment%
% %spikeProbability spike_prob'
dataFolder = [experiment.folder 'data' filesep];
cascadeFile = [dataFolder experiment.name '_cascade.mat'];
if(~exist(cascadeFile))
  logMsg(sprintf('Cascade datafile: %s not found', cascadeFile), 'e');
  barCleanup(params);
  return;
end
data = load(cascadeFile);

experiment.spikeProbability = data.spike_prob';
experiment.cascadeModel = data.model;
for it = 1:length(experiment.ROI)
  validSpikes = find(data.spike_times(:,1)+1 == it); % 0 idx in python
  if(~isempty(validSpikes))
    experiment.spikes{it} = experiment.t(data.spike_times(validSpikes,2)+1); % Again +1 due to 0 idx
  else
    experiment.spikes{it} = [];
  end
end
experiment.saveBigFields = true;

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end
