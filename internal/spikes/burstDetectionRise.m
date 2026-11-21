function experiment = burstDetectionRise(experiment, varargin)
% BURSTDETECTIONRISE Based on the Rise
%
% USAGE:
%    experiment = burstDetectionRise(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: burstDetectionRiseOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = burstDetectionX(experiment)
%
% Copyright (C) 2020, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: burst detection Rise
% parentGroups: spikes: bursts
% optionsClass: burstDetectionRiseOptions
% requiredFields: spikes, ROI, folder, name

[params, var] = processFunctionStartup(burstDetectionRiseOptions, varargin{:});
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
minBurstSeparation = params.minBurstSeparation;
minBurstDuration = params.minBurstDuration;

% Empty check
if(isempty(groupList))
  logMsg(sprintf('Group %s not found on experiment %s', mainGroup, experiment.name), 'w');
  return;
end

% Time to iterate through all the groups
for git = 1:length(groupList)
  if(params.pbar > 0)
    ncbar.setBarTitle(sprintf('Detecting bursts from group: %s', groupList{git}));
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
  
  binSize=1/experiment.fps;
  fullSpikes = experiment.spikes;
  if(~isempty(params.timeRange) && length(params.timeRange) == 2)
    for it1 = 1:length(members)
        fullSpikes{members(it1)} = fullSpikes{members(it1)}(fullSpikes{members(it1)} >= params.timeRange(1) & fullSpikes{members(it1)} <= params.timeRange(2));
    end
  end
  if(~isempty(params.minSpikes))
      validMembers = cellfun(@(x)length(x) >= params.minSpikes,fullSpikes(members));
      logMsg(sprintf('After minSpikes correction, going from %d members to %d', length(members), sum(validMembers)));
      members = members(validMembers);
  end

  %spikesSubset = cellfun(@(x)floor(x/binSize), experiment.spikes(members),'UniformOutput', false);
  spikesSubset = cellfun(@(x)floor(x/binSize), fullSpikes(members),'UniformOutput', false);
  spk = zeros(length(spikesSubset), length(experiment.rawT));
  for it = 1:length(spikesSubset)
    spk(it, spikesSubset{it}) = 1;
  end
  spkNull = zeros(size(spk));
  for it = 1:size(spk, 1)
    nSpikes = sum(spk(it, :));
    if(nSpikes > 0)
      spkNull(it, randi(size(spk, 2), sum(spk(it, :)), 1)) = 1;
    end
  end
  activityThreshold = mean(mean(spkNull))+params.activityThreshold*std(mean(spkNull));
  % Threshold on increase
  expt = diff(mean(spkNull));
  riseThreshold = mean(expt)+params.riseThreshold*std(expt);
  
  rise = diff(mean(spk));
  avgS = mean(spk);
  inBurst = false;
  burstStart = [];
  burstEnd = [];
  for it = 1:(length(avgS)-1)
    if(~inBurst & rise(it) > riseThreshold)
      burstStart = [burstStart; it];
  %     if(inBurst)
  %       burstEnd = [burstEnd; it-1];
  %     end
      inBurst = true;
    elseif(inBurst & avgS(it) < activityThreshold & rise(it) < riseThreshold)
  %     burstEnd = [burstEnd; it-1];
      burstEnd = [burstEnd; it];
      inBurst = false;
    end
  end
  if(length(burstStart) > length(burstEnd))
    burstStart(end) = [];
  end

  burstStructure = struct;
  burstStructure.duration = experiment.rawT(burstEnd)-experiment.rawT(burstStart);
  burstStructure.start = burstStart;
  burstStructure.amplitude = zeros(size(burstStructure.start));
  burstStructure.frames = cell(size(burstStructure.start));
  burstStructure.participators = cell(size(burstStructure.start));
  for it = 1:length(burstStructure.start)
    burstStructure.frames{it} = burstStart(it):burstEnd(it);
    if(burstStart(it) > 1)
      burstStructure.amplitude(it) = max(avgS(burstStructure.frames{it}))-avgS(burstStart(it)-1);
    else
      burstStructure.amplitude(it) = max(avgS(burstStructure.frames{it}))-avgS(burstStart(it));
    end
    spkSubset = find(sum(spk(:, burstStructure.frames{it}), 2));
    %burstStructure.participators{it} = intersect(spkSubset, members);
    burstStructure.participators{it} = members(spkSubset); % Nov 2026 fix
  end
  burstStructure.thresholds = [riseThreshold, activityThreshold];
  burstStructure.N = [];

  %
  if(length(burstStructure.start) > 1)
    burstStructure.IBI = burstStructure.start(2:end) - (burstStructure.start(1:end-1) + burstStructure.duration(1:end-1));
  else
    burstStructure.IBI = [];
  end

  % Remove short bursts
  invalidBursts = find(burstStructure.duration < minBurstDuration);
  burstStructure.duration(invalidBursts) = [];
  burstStructure.amplitude(invalidBursts) = [];
  burstStructure.start(invalidBursts) = [];
  burstStructure.frames(invalidBursts) = [];
  burstStructure.participators(invalidBursts) = [];
  burstStructure.invalidBursts = length(invalidBursts);
  if(length(burstStructure.start) > 1)
    burstStructure.IBI = burstStructure.start(2:end)- (burstStructure.start(1:end-1) + burstStructure.duration(1:end-1));
  else
    burstStructure.IBI = [];
  end

  % Merge bursts between too short IBIs
  done = false;
  while(~done)
    done = true;
    for it = 1:length(burstStructure.IBI)
      % Remove burst it+1 and add it to burst it
      if(burstStructure.IBI(it) <= minBurstSeparation)
        done = false;
        burstStructure.duration(it) = burstStructure.start(it+1)+burstStructure.duration(it+1)-burstStructure.start(it);
        burstStructure.amplitude(it) = burstStructure.amplitude(it) + burstStructure.amplitude(it+1);
        burstStructure.frames{it} = burstStructure.frames{it}(1):burstStructure.frames{it+1}(end);
        spkSubset = find(sum(spk(:, burstStructure.frames{it}), 2));
        burstStructure.participators{it} = members(spkSubset);
       %burstStructure.participators{it} = intersect(spkSubset, members); %Fix nov 2026
        % Now remove the next one
        burstStructure.duration(it+1) = [];
        burstStructure.amplitude(it+1) = [];
        burstStructure.start(it+1) = [];
        burstStructure.frames(it+1) = [];
        burstStructure.participators(it+1) = [];
        % Recompute IBIs
        if(length(burstStructure.start) > 1)
          burstStructure.IBI = burstStructure.start(2:end)- (burstStructure.start(1:end-1) + burstStructure.duration(1:end-1));
        else
          burstStructure.IBI = [];
        end
        break;
      end
    end
  end
  %figure;imagesc(1-spk, 'YData', [1 size(spk, 1)], 'XData', experiment.rawT([1 end]));colormap(gray);
  if(params.plotResults)
    figName = sprintf('rise bursts %s - %s', experiment.name, strrep(groupList{git},':','_'));
    if(params.saveOptions.onlySaveFigure)
      figVisible = 'off';
    else
      figVisible = 'on';
    end
    figureHandle = figure('Name', figName, 'NumberTitle', 'off', 'Visible', figVisible, 'Tag', 'netcalPlot');
    figureHandle.Position = setFigurePosition(gcf, 'width', params.styleOptions.figureSize(1), 'height', params.styleOptions.figureSize(2), 'centered', true);
    
    
    a2 = subplot(3, 1, 2);
    plot(experiment.t(1:end-1), rise);
    hold on;
    xlim([experiment.t(1) experiment.t(end)]);
    xl = xlim;
    plot(xl, [1,1]*riseThreshold,'--');
    xlabel('time (s)');
    ylabel('Rise (a.u.)');
    box on;
    

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
    xlabel('time (s)');
    ylabel('DF/F');
    box on;

    a1 = subplot(3, 1, 1);
    plot(experiment.t, avgS*experiment.fps);
    hold on;
    xlim([min(experiment.t) max(experiment.t)]);
    xl = xlim;
    plot(xl, [1,1]*activityThreshold*experiment.fps,'--');
    title(['Rise burst detection: ' experiment.name ' ' strrep(groupList{git},':','_')], 'interpreter', 'none');
    xlabel('time (s)');
    ylabel('Avg Firing Rate (Hz)');
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
  end
  % Store results
  
  burstList = burstStructure;
  
  experiment.spikeBursts.(groupName){groupIdx} = burstList;

  logMsg(sprintf('%d bursts detected on group %s in %s', length(burstList.start), groupList{git}, experiment.name));
  logMsg(sprintf('%.2f s mean duration', mean(burstList.duration)));
  logMsg(sprintf('%.2f mean maximum amplitude', mean(burstList.amplitude)));
  logMsg(sprintf('%.2f s mean IBI', mean(burstList.IBI)));
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end