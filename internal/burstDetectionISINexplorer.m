function experiment = burstDetectionISINexplorer(experiment, varargin)
% BURSTDETECTIONISINEXPLORER
%
% USAGE:
%    experiment = burstDetectionISINexplorer(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: burstDetectionISINexplorerOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = burstDetectionISINexplorer(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: ISI_N burst detection explorer
% parentGroups: spikes: bursts
% optionsClass: burstDetectionISINexplorerOptions
% requiredFields: spikes, ROI, folder, name

[params, var] = processFunctionStartup(burstDetectionISINexplorerOptions, varargin{:});
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

Steps = eval(params.steps);

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
  
  experiment.spikes = cellfun(@(x)x(:)', experiment.spikes, 'UniformOutput', false);
  
  ar=[cellfun(@(x)x, experiment.spikes(members), 'UniformOutput', false)];
  %lr = cellfun(@(x)length(x), ar);
  %SpikeTimes = [ar{:}];
  SpikeTimes = [];
  SpikeIdx = [];
  for it = 1:length(ar)
    SpikeTimes = [SpikeTimes, ar{it}];
    SpikeIdx = [SpikeIdx, ones(size(ar{it}))*it];
  end
  mat = [SpikeTimes', SpikeIdx'];
  ar = sortrows(mat, 1);
  SpikeTimes = ar(:,1)';
  if(params.jitterSpikes)
    SpikeTimes = SpikeTimes +(rand(size(SpikeTimes))-0.5)/experiment.fps;
  end
  SpikeIdx = ar(:,2)';

  N = eval(params.N);
  figure;
  hold on;
  cmap = parula(length(N));
  cnt = 0;
  hList = [];
  for FRnum = N
    cnt = cnt + 1;
    ISI_N = SpikeTimes( FRnum:end ) - SpikeTimes( 1:end-(FRnum-1) );
    n = histc( ISI_N, Steps);
    %n = smooth( n, 'lowess' );
    valid = find(n > 0);
    newSteps = Steps(valid);
    n = n(valid);
    %plot( newSteps, n/sum(n), '-', 'color', map(cnt,:) )
    nPlot = smooth(n)/sum(n);
    hList = [hList; plot(newSteps, nPlot, '-', 'color', cmap(cnt,:), 'DisplayName', sprintf('N=%d', FRnum))];
    %r = 1-n/sum(n);
    %r(n == 0) = nan;
    %plot( Steps, r, '-o', 'color', map(cnt,:) )
    
    % Peak detection
     [~, locs, ~, p] = findpeaks(log(nPlot));
    if(length(locs) < 2)
      continue;
    end
    [~, pidx] = sort(p, 'descend');
    pksIdx = locs(pidx(1:2));
    plot(newSteps(pksIdx), nPlot(pksIdx)*1.1, 'v','MarkerSize', 8, 'MarkerFaceColor', cmap(cnt, :), 'MarkerEdgeColor', cmap(cnt, :));
    optISINupper = max(newSteps(pksIdx));
    optISINlower = min(newSteps(pksIdx));
    %[optISINupper optISINlower]
    [~, locs, ~, p] = findpeaks(-log(nPlot));
    valid = find(newSteps(locs) > optISINlower & newSteps(locs) < optISINupper);
    locs = locs(valid);
    p = p(valid);
    [~, pidx] = sort(p,'descend');
    pksIdx = locs(pidx(1));
    plot(newSteps(pksIdx), nPlot(pksIdx)*1.1, 'o', 'MarkerSize', 8, 'MarkerFaceColor', cmap(cnt, :), 'MarkerEdgeColor', cmap(cnt, :));
    optISINmiddle = newSteps(pksIdx);
    if(length(pidx) > 1)
      optISINmiddle2 = newSteps(locs(pidx(2)));
      plot(newSteps(locs(pidx(2))), nPlot(locs(pidx(2)))*1.1, 'o', 'MarkerSize', 8, 'MarkerFaceColor', cmap(cnt, :), 'MarkerEdgeColor', cmap(cnt, :));
    else
      optISINmiddle2 = optISINmiddle;
    end
    %optISINupper = mean([optISINupper newSteps(pksIdx)]);
    % Move it a little bit
    logMsg(sprintf('N: %d - maxs: %.2f %.2f - mins: %.2f %.2f', FRnum, optISINupper, optISINlower, optISINmiddle, optISINmiddle2));
    %optISINmiddle[optISINupper optISINlower]);
    
  end
  xlabel 'ISI, T_i - T_{i-(N-1) _{ }} [s]'
  ylabel 'Probability [%]'
  set(gca,'xscale','log')
  set(gca,'yscale','log') 
  title(sprintf('ISI_N burst detection exploration for: %s - %s', groupName, experiment.name));
  box on;
  legend(hList);
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end
