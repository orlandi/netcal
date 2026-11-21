function experiment = burstDetectionXplot(experiment, varargin)
% BURSTDETECTIONXPLOT Based on X
%
% USAGE:
%    experiment = burstDetectionXplot(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: burstDetectionXplotOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = burstDetectionXplot(experiment)
%
% Copyright (C) 2016-2019, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: burst detection X plot
% parentGroups: spikes: bursts
% optionsClass: burstDetectionXplotOptions
% requiredFields: spikes, ROI, folder, name

[params, var] = processFunctionStartup(burstDetectionXplotOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Detecting bursts', true);
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

% Some definitions
%urstSeparation = params.minBurstSeparation;
%minParticipators = params.minParticipators;

% Empty check
if(isempty(groupList))
  logMsg(sprintf('Group %s not found on experiment %s', mainGroup, experiment.name), 'w');
  return;
end

% Time to iterate through all the groups
for git = 1:length(groupList)
  if(params.pbar > 0)
    ncbar.setBarTitle(sprintf('Plotting bursts from group: %s', groupList{git}));
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
  
  experiment.spikes = cellfun(@(x)x(:)', experiment.spikes, 'UniformOutput', false);
  spkList = cellfun(@(x)x, experiment.spikes(members), 'UniformOutput', false);
  spkListIdx = cellfun(@(x,y)ones(size(x))*y, spkList, num2cell(1:length(spkList))', 'UniformOutput', false);
  firings.T = [spkList{:}];
  firings.N = [spkListIdx{:}];
  % Sort by time
  [firings.T, idx] = sort(firings.T);
  firings.N  = firings.N(idx);
  %
  [a, b] = hist(firings.N, 1:max(firings.N));
  [~, sortedChannels] = sort(a, 'ascend');
  sortedChannels = arrayfun(@(x)find(x==sortedChannels), 1:max(firings.N));
  if(params.reorderChannels)
    minC = min(sortedChannels(firings.N));
  else
    minC = 0;
  end
  
  %%% The X model
  burstStructure = experiment.spikeBursts.(groupName){groupIdx};
  
  firingRateAvgChannels = zeros(size(experiment.t));
  %%% Needs optimization
  for it = 1:length(experiment.t)
    valid = firings.T <= experiment.t(it) & firings.T > experiment.t(it)-experiment.burstDetectionXoptionsCurrent.windowSize;
    firingRateAvgChannels(it) = length(unique(firings.N(valid)));
  end
  
  
    if(~params.reorderChannels)
      sortedChannels = 1:max(firings.N);
    end

    figName = sprintf('X bursts %s', experiment.name);
    figVisible = 'on';
    
    figureHandle = figure('Name', figName, 'NumberTitle', 'off', 'Visible', figVisible, 'Tag', 'netcalPlot');
    figureHandle.Position = setFigurePosition(gcf, 'width', params.styleOptions.figureSize(1), 'height', params.styleOptions.figureSize(2), 'centered', true);
      
    a2 = subplot(3, 1, 2);
    hold on;
    plot(firings.T, sortedChannels(firings.N)-minC, 'k.');
    detected = [];
    for i=1:length(burstStructure.start)
      %Detected = [ Detected Burst.T_start(i) Burst.T_end(i) NaN ];
      valid = find(firings.T >= burstStructure.start(i) & firings.T <= (burstStructure.start(i)+burstStructure.duration(i)));

      plot(firings.T(valid), sortedChannels(firings.N(valid))-minC, '.');
      detected = [detected burstStructure.start(i) burstStructure.start(i)+burstStructure.duration(i) NaN];
    end
    % Now plot the surprises
    %for it = 1:length(surprise.T)
    %plot(surprise.T, sortedChannels(surprise.N)-minC, 'or', 'MarkerSize', 8);
    %a1.ColorOrderIndex = 1;
%     if(strcmpi(params.surpriseMode, 'single'))
%       plot(surprise.T, sortedChannels(surprise.N)-minC, 'b.');
%     else
%       plot(surprise.T, surprise.N*(max(sortedChannels)-minC+2), 'b.');
%     end
    %end
    linesMap = lines(2);
    %plot(detectedFullSchmitt, ones(size(detectedFullSchmitt))*max(sortedChannels(firings.N))-minC+5, 'v-', 'Color', linesMap(2,:), 'MarkerFaceColor', linesMap(2,:))
    plot(detected, ones(size(detected))*max(sortedChannels(firings.N))-minC+5, 'v-', 'Color', linesMap(1,:), 'MarkerFaceColor', linesMap(1,:))

    xlabel('time (s)')
    ylabel('sorted ROI');

    box on;
    title(sprintf('Raster plot - N: %d', length(burstStructure.amplitude)));
    xl = xlim;

    a3 = subplot(3, 1, 3);
    hold on;
    try
      experiment = loadTraces(experiment, 'smoothed');
      avgF = mean(experiment.traces(:, members), 2);
      plot(experiment.t, avgF,'Color',[1 1 1]*0.75);
      ax = gca;
      ax.ColorOrderIndex = 1;
      for i=1:length(burstStructure.start)
        valid = find(experiment.t >= burstStructure.start(i) & experiment.t <= (burstStructure.start(i)+burstStructure.duration(i)));
        plot(experiment.t(valid), avgF(valid));
      end
      xlim([min(experiment.t) max(experiment.t)]);
      ylim([min(avgF) max(avgF)*1.1]);
    catch
    end
    title('Average trace');
    xlabel('time (s)');
    ylabel('DF/F');
    box on;

    a1 = subplot(3, 1, 1);
    plot(experiment.t, firingRateAvgChannels);
    hold on;
    xlim([min(experiment.t) max(experiment.t)]);
    xl = xlim;
    %plot(xl, [1,1]*schmittLow);
    %plot(xl, [1,1]*schmittHigh);
    %legend('ISI_N','low','high');
    title(['X burst detection: ' experiment.name]);
    xlabel('time (s)');
    ylabel('Simultaneous X bursts');
    box on;
    linkaxes([a1 a2 a3], 'x');
    xlim([min(experiment.t) max(experiment.t)]);
    
    ui = uimenu(figureHandle, 'Label', 'Export');
    uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, strrep([figFolder, figName], ' - ', '_'), params.saveOptions.saveFigureResolution});
      
    if(params.saveOptions.saveFigure)
      if(~isempty(params.saveOptions.saveFigureTag))
        figName = [figName params.saveOptions.saveFigureTag];
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


  logMsg(sprintf('%d bursts found on group %s in %s', length(burstStructure.start), groupList{git}, experiment.name));
  logMsg(sprintf('%.2f s mean duration', mean(burstStructure.duration)));
  logMsg(sprintf('%.2f mean maximum amplitude', mean(burstStructure.amplitude)));
  logMsg(sprintf('%.2f s mean IBI', mean(burstStructure.IBI)));
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end