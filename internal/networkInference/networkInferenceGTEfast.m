function experiment = networkInferenceGTEfast(experiment, varargin)
% NETWORKINFERENCEGTEFAST Network inference using Generalized Transfer Entropy
%
% USAGE:
%   experiment = networkInferenceGTEfast(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class networkInferenceGTEfastOptions
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = networkInferenceGTEfast(experiment, networkInferenceGTEfastOptions)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also peelingOptions

% EXPERIMENT PIPELINE
% name: GTE inference
% parentGroups: network: inference
% optionsClass: networkInferenceGTEfastOptions
% requiredFields: spikes, t, fps, ROI
% producedFields: GTE


%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(networkInferenceGTEfastOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Performing GTE inference');
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end
% Check if its a project or an experiment
switch params.saveOptions.saveBaseFolder
  case 'experiment'
    baseFolder = experiment.folder;
  case 'project'
    baseFolder = [experiment.folder '..' filesep];
  otherwise
    baseFolder = experiment.folder;
end

% Consistency checks
if(params.saveOptions.onlySaveFigure)
  params.saveOptions.saveFigure = true;
end
if(params.saveOptions.saveFigure)
  params.plotResults = true;
end
if(ischar(params.styleOptions.figureSize))
  params.styleOptions.figureSize = eval(params.styleOptions.figureSize);
end

% Create necessary folders
if(~exist(baseFolder, 'dir'))
  mkdir(baseFolder);
end
figFolder = [baseFolder 'figures' filesep];
if(~exist(figFolder, 'dir'))
  mkdir(figFolder);
end
exportFolder = [baseFolder 'exports' filesep];
if(~exist(exportFolder, 'dir'))
  mkdir(exportFolder);
end

% Get ALL subgroups in case of parents
if(strcmpi(mainGroup, 'all'))
  groupList = getExperimentGroupsNames(experiment);
else
  groupList = getExperimentGroupsNames(experiment, mainGroup);
end

% Empty check
if(isempty(groupList))
  logMsg(sprintf('Group %s not found on experiment %s', mainGroup, experiment.name), 'w');
  return;
end

% Time to iterate through all the groups
for git = 1:length(groupList)
  if(params.pbar > 0)
    ncbar.setBarTitle(sprintf('Inferring network using GTE from group: %s', groupList{git}));
  end
  if(strcmpi(groupList{git}, 'none'))
    members = 1:length(experiment.ROI);
    groupName = 'everything';
    groupIdx = 1;
  else
    [members, groupName, groupIdx] = getExperimentGroupMembers(experiment, groupList{git});
  end
  
  % Check for empty group
  if(isempty(members) && params.verbose)
    logMsg(sprintf('Found empty group: %s', groupList{git}), 'w');
    continue;
  end
  
  % Prepare the data
  binSize = params.binSize;
  maxT = max(experiment.t);
  totalFrames = ceil(maxT/binSize);

  maxI = length(members);
  D = zeros(totalFrames, maxI);
  for it = 1:maxI
    curIdx = members(it);
    curTimes = ceil(experiment.spikes{curIdx}/binSize)+1;
  %   for it2 = 1:length(curTimes)
  %     D(curTimes(it2), it) = D(curTimes(it2), it) + 1;
  %   end
    % We can do it this way since we are binarizing the activity
    D(curTimes, it) = 1;
  end
  % Now binarize D - no need anymore
  %D(D > 1) = 1;
  % Now calculate G and use 1 as threshold
  G = mean(D, 2);
  if(params.applyConditioning)
    Gthreshold = params.conditioningThreshold;
  else
    Gthreshold = inf;
  end
  if(params.plotGlobalFluorescence)

    origFigName = sprintf('Global Fluorescence %s', experiment.name);
    if(params.saveOptions.onlySaveFigure)
      figVisible = 'off';
    else
      figVisible = 'on';
    end
    figureHandle = figure('Name', origFigName, 'NumberTitle', 'off', 'Visible', figVisible, 'Tag', 'netcalPlot');
    figureHandle.Position = setFigurePosition(gcf, 'width', params.styleOptions.figureSize(1), 'height', params.styleOptions.figureSize(2), 'centered', true);
    
    % The actual plot
    logG = log10(G);
    logG = logG(~isinf(logG));
    minG = floor(min(logG)/0.1)*0.1;
    [a,b] = hist(logG, minG:0.1:0);
    bar(b,a);
    set(gca,'YScale', 'log');
    xlabel('log F');
    ylabel('Count');
    xlim([minG 0]);
    yl = ylim;
    hold on;
    if(params.applyConditioning)
      plot([1, 1]*log10(Gthreshold), yl, 'b--');
    end
    
    box on;
    
    ui = uimenu(figureHandle, 'Label', 'Export');
    uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, strrep([figFolder, origFigName], ' - ', '_'), params.saveOptions.saveFigureResolution});
      
    if(params.saveOptions.saveFigure)
      if(~isempty(params.saveOptions.saveFigureTag))
        figName = [origFigName params.saveOptions.saveFigureTag];
      else
        figName = origFigName;
      end
      export_fig([figFolder, figName, '.', params.saveOptions.saveFigureType], ...
                  sprintf('-r%d', params.saveOptions.saveFigureResolution), ...
                  sprintf('-q%d', params.saveOptions.saveFigureQuality), figureHandle);
    end
    if(params.saveOptions.onlySaveFigure)
     close(figureHandle);
    end
    if(~isempty(params.styleOptions.figureTitle))
      mtit(params.styleOptions.figureTitle);
    end
  end
  
  % The actual inference
  G(G <= Gthreshold) = 0;
  G(G > Gthreshold) = 1;
  % Weird
  G = G + 1;
  D = D + 1; % So the values are also 1,2

  [GTE, ~, ~, ~] = calculateGTEultra(D, G, 'IFT', params.instantFeedbackTerm, 'verbose', false, 'MarkovOrder', params.markovOrder, 'returnFull', true, ...
                                                    'surrogateType', 'none', 'debug', false, 'computeBias', false, 'pbar', params.pbar);
  preMeanGTE = repmat(mean(GTE(:,:,1)), [size(GTE,1) 1]);
  preStdGTE = repmat(std(GTE(:,:,1)), [size(GTE,1) 1]);
  postMeanGTE = repmat(mean(GTE(:,:,1),2), [1, size(GTE,1)]);
  postStdGTE = repmat(std(GTE(:,:,1), [], 2), [1, size(GTE,1)]);
  prePostMeanGTE = 1/2*(preMeanGTE+postMeanGTE);
  prePostStdGTE = 1/2*(preStdGTE+postStdGTE);
  %GTE(:,:,size(GTE,3)+1) = (GTE(:,:,1)-prePostMeanGTE)./prePostStdGTE;
  % Let's override the above values
  switch params.significanceDistribution
    case 'prepost'
      GTE(:,:, 2) = (GTE(:,:,1)-prePostMeanGTE)./prePostStdGTE;
    case 'pre'
      GTE(:,:, 2) = (GTE(:,:,1)-preMeanGTE)./preStdGTE;
    case 'global'
      fullGTE = GTE(:,:, 1);
      fullGTE = fullGTE(:);
      GTE(:,:, 2) = (GTE(:,:,1)-mean(fullGTE))./std(fullGTE);
  end
  
  % Store results
  if(params.applyConditioning)
    experiment.GTE.(groupName){groupIdx} = GTE;
  else
    experiment.GTEunconditioned.(groupName){groupIdx} = GTE;
  end
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end