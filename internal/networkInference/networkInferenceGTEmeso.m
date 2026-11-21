function experiment = networkInferenceGTEmeso(experiment, varargin)
% NETWORKINFERENCEGTEMESO Network inference using Generalized Transfer
% Entropy for mesoscale data
%
% USAGE:
%   experiment = networkInferenceGTEmeso(experiment, options)
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
% Copyright (C) 2016-2026, Javier G. Orlandi <javier.orlandi@ucalgary.ca>
%
% See also peelingOptions

% EXPERIMENT PIPELINE
% name: GTE meso
% parentGroups: network: inference
% optionsClass: networkInferenceGTEfastOptions
% requiredFields: traces, t, fps, ROI
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
  [groupList, experiment] = getExperimentGroupsNames(experiment);
else
  [groupList, experiment] = getExperimentGroupsNames(experiment, mainGroup);
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

  experiment = loadTraces(experiment, 'smoothed');

  maxI = length(members);
  D = experiment.traces;
  zscThreshold = 1;
  for it1 = 1:maxI
    D(:, it1) = zscore(experiment.traces(:,it1)) > zscThreshold;
  end
  % Now binarize D - no need anymore
  %D(D > 1) = 1;
  % Now calculate G and use 1 as threshold
  G = mean(D, 2);
  if(params.applyConditioning)
    Gthreshold = params.conditioningThreshold;
    if(isempty(Gthreshold) || Gthreshold == 0)
      Gthreshold = median(G)+2*std(G);
      logMsg(sprintf('Performing automatic threshold detection: %.2f', Gthreshold),'w');
    end
  else
    Gthreshold = inf;
  end
  
  if(params.plotGlobalFluorescence)
    figure;
    hist(G, 100);
    hold on;
    yl = ylim;
    h2 = plot([1,1]*Gthreshold(end), yl, 'k--');
    legend(h2, 'Conditioning threshold');
    xlabel('Global signal G');
    ylabel('PDF(G)');
    try
      fpa = [experiment.folder filesep 'figures'];
      if(~exist(fpa, 'dir'))
          mkdir(fpa);
      end
      outputfilename = [experiment.folder filesep 'figures' filesep experiment.name '_GTEmeso_inferenceThreshold.png'];
      export_fig(gcf, outputfilename, '-nocrop', '-r150');
    end
    tmpG = G;
    overT = find(tmpG > Gthreshold(end));
    tmpG(tmpG > Gthreshold(end)) = 0;
    tmpG(~~tmpG) = 1;

    figure;
    plot(1:length(tmpG),G,'-');
    hold on;
    plot(overT,G(overT),'rx');
    title(sprintf('Fraction of frames removed: %.2f', 1-sum(G)/length(G)));
    try
      fpa = [experiment.folder filesep 'figures'];
      if(~exist(fpa, 'dir'))
          mkdir(fpa);
      end
      outputfilename = [experiment.folder filesep 'figures' filesep experiment.name '_GTEmeso_inferenceConditioning.png'];
      export_fig(gcf, outputfilename, '-nocrop', '-r150');
    end

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
  switch params.conditioningSignal
    case 'avg activity'
      % The actual inference
      G(G <= Gthreshold) = 0;
      G(G > Gthreshold) = 1;
    case 'movement'
      G = experiment.movementBinned(:);
      if(length(G) < totalFrames)
        logMsg(sprintf('Mismatch between number of movement and spiking datapoints (%d) vs (%d). Using only movement selection', length(G), totalFrames),'w');
        D = D(experiment.movementFrames, :);
      elseif(length(G) > totalFrames)
        logMsg('Too many movement frames to continue.', 'e');
        barCleanup(params);
        return;
      end
  end
  % Weird
  G = G + 1;
  D = D + 1; % So the values are also 1,2

  [GTE, surrogatesGTE, biasGTE, ~] = calculateGTEultra(D, G, 'IFT', params.instantFeedbackTerm, 'verbose', false, 'MarkovOrder', params.markovOrder, 'returnFull', true, ...
                                                    'surrogateType', params.surrogateType, 'debug', false, 'computeBias', params.computeBias, 'pbar', params.pbar, 'numBiasShuffles', params.numBiasShuffles, 'maxJitter', params.maxJitter, 'numSurrogates', params.numSurrogates);
  % The part below overrides the 2nd (high) conditioning value. So keep
  % that in mind!
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
  experiment.GTEsurrogates.(groupName){groupIdx} = surrogatesGTE;
  experiment.GTEbias.(groupName){groupIdx} = biasGTE;
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end