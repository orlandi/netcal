function experiment = identifyHCG(experiment, varargin)
% IDENTIFYHCG finds the highly correlated groups HCG
%
% USAGE:
%    experiment = identifyHCG(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: identifyHCGoptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = identifyHCG(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also extractTraces

% EXPERIMENT PIPELINE
% name: identify HCG
% parentGroups: fluorescence: group classification
% optionsClass: identifyHCGoptions
% requiredFields: traces

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(identifyHCGoptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Identifying Highly Correlated Groups');
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

members = getAllMembers(experiment, mainGroup);

switch params.tracesType
  case 'smoothed'
    experiment = loadTraces(experiment, 'normal');
    traces = experiment.traces;
  case 'raw'
    experiment = loadTraces(experiment, 'raw');
    traces = experiment.rawTraces;
  case 'denoised'
    experiment = loadTraces(experiment, 'rawTracesDenoised');
    traces = experiment.rawTracesDenoised;
end

currentOrder = members;

correlationDistance = params.correlationLevel;

% Find optimal
if(params.automaticCorrelationLevel)
  if(params.pbar > 0)
    ncbar.setAutomaticBar(params.pbar, 'Looking for optimal correlation level');
  end
  logMsg('Looking for optimal correlation level');
  
  correlationDistanceList = linspace(0+1e-6, 1-1e-6, 100);

  subTraces = traces(:, currentOrder)';
  distmat = pdist(subTraces, 'correlation');
  Z = linkage(distmat);
  clusterElements = zeros(size(correlationDistanceList));
  maxClusterElements = zeros(size(correlationDistanceList));

  for it = 1:length(correlationDistanceList)
      cDist = correlationDistanceList(it);
      cl = cluster(Z, 'criterion', 'distance', 'cutoff', 1-cDist);
      [a,~] = hist(cl, 1:max(cl));
      [y, idx] = sort(a, 'descend');
      validClusters = find(y > 1);
      numClusters = length(validClusters);
      clusterElements(it) = 0;
      for i = 1:numClusters
          clusterMembers = currentOrder(cl == idx(validClusters(i)));
          if(i == 1)
              maxClusterElements(it) = length(clusterMembers);
          end
          clusterElements(it) = clusterElements(it) + length(clusterMembers);
      end
  end
  [~, optimal] = max(clusterElements-maxClusterElements);
  logMsg(sprintf('Optimal correlation level found: %.2f', correlationDistanceList(optimal)));
  
  if(params.plotAutomaticCorrelationLevel)
    h = figure;
    plot(correlationDistanceList, clusterElements/length(currentOrder),'o-');
    hold on;
    plot(correlationDistanceList, maxClusterElements/length(currentOrder),'o-');
    yl = ylim;
    plot(correlationDistanceList(optimal)*[1 1], yl, 'k--');
    legend('traces in clusters', 'traces in the biggest cluster', sprintf('optimal: %.2f', correlationDistanceList(optimal)));
    xlabel('Correlation');
    ylabel('traces (fraction)');
    ui = uimenu(h, 'Label', 'Export');
    uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_HCG_exploration']});
  end
  correlationDistance = correlationDistanceList(optimal);
  ncbar.setBarName('Identifying Highly Correlated Groups');
end

subTraces = traces(:, currentOrder)';
distmat = pdist(subTraces, 'correlation');

Z = linkage(distmat);
cl = cluster(Z, 'criterion', 'distance', 'cutoff', 1-correlationDistance);
[a,~] = hist(cl, 1:max(cl));
[y, idx] = sort(a, 'descend');
validClusters = find(y > 1);

if(~isfield(experiment, 'traceGroups'))
  experiment.traceGroups = struct;
end
if(isempty(validClusters))
  logMsg(sprintf('Found no groups'));
end
% + 2 because we are adding two at the end
experiment.traceGroups.HCG = cell(length(validClusters)+2, 1);
experiment.traceGroupsNames.HCG = cell(length(validClusters)+2, 1);
experiment.traceGroupsOrder.ROI.HCG = cell(length(validClusters)+2, 1);
experiment.traceGroupsOrder.similarity.HCG = cell(length(validClusters)+2, 1);
usedMembers = [];
for i = 1:length(validClusters)
  clusterMembers = currentOrder(cl == idx(validClusters(i)));
  usedMembers = [usedMembers; clusterMembers(:)];
  experiment.traceGroups.HCG{i} = clusterMembers;
  experiment.traceGroupsNames.HCG{i} = num2str(i);
  experiment.traceGroupsOrder.ROI.HCG{i} = sort(clusterMembers);
  % Now do the similarities
  if(length(experiment.traceGroupsOrder.ROI.HCG{i}) > 2)
    [~, order, ~] = identifySimilaritiesInTraces(experiment, experiment.traces(:, clusterMembers), 'saveSimilarityMatrix', false, 'showSimilarityMatrix', false, 'verbose', false, 'pbar', params.pbar);
  else
    order = 1:length(clusterMembers);
  end
  experiment.traceGroupsOrder.similarity.HCG{i} = clusterMembers(order);
end
% Now the last two
% First, all but the first HCG
clusterMembers = setdiff(currentOrder, currentOrder(cl == idx(validClusters(1))));
experiment.traceGroups.HCG{end-1} = clusterMembers;
experiment.traceGroupsNames.HCG{end-1} = 'not on largest HCG';
experiment.traceGroupsOrder.ROI.HCG{end-1} = sort(clusterMembers);
% Now do the similarities
if(length(experiment.traceGroupsOrder.ROI.HCG{end-1}) > 2)
  [~, order, ~] = identifySimilaritiesInTraces(experiment, experiment.traces(:, clusterMembers), 'saveSimilarityMatrix', false, 'showSimilarityMatrix', false, 'verbose', false, 'pbar', params.pbar);
else
  order = 1:length(clusterMembers);
end
experiment.traceGroupsOrder.similarity.HCG{end-1} = clusterMembers(order);
% Now, whatever is not on a HCG
clusterMembers = setdiff(currentOrder, usedMembers);
experiment.traceGroups.HCG{end} = clusterMembers;
experiment.traceGroupsNames.HCG{end} = 'not on any HCG';
experiment.traceGroupsOrder.ROI.HCG{end} = sort(clusterMembers);
% Now do the similarities
if(length(experiment.traceGroupsOrder.ROI.HCG{end}) > 2)
  [~, order, ~] = identifySimilaritiesInTraces(experiment, experiment.traces(:, clusterMembers), 'saveSimilarityMatrix', false, 'showSimilarityMatrix', false, 'verbose', false, 'pbar', params.pbar);
else
  order = 1:length(clusterMembers);
end
experiment.traceGroupsOrder.similarity.HCG{end} = clusterMembers(order);

experiment.HCGcorrelationDistance = correlationDistance;

logMsg(sprintf('Found %d groups', length(experiment.traceGroups.HCG)), 'w');

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
