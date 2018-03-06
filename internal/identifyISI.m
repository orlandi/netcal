function experiment = identifyISI(experiment, varargin)
% IDENTIFYISI finds groups of spiking cells with similar ISI distributions
%
% USAGE:
%    experiment = identifyISI(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: identifyISIoptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = identifyISI(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also extractTraces

% EXPERIMENT PIPELINE
% name: identify ISI groups
% parentGroups: spikes: group classification
% optionsClass: identifyISIoptions
% requiredFields: traces

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(identifyISIoptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Identifying ISI groups');
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

members = getAllMembers(experiment, mainGroup);

experiment.spikes = cellfun(@(x)x(:)', experiment.spikes, 'UniformOutput', false);
spkList = cellfun(@(x)x, experiment.spikes(members), 'UniformOutput', false);
ISIlist = cellfun(@(x)diff(x), spkList, 'UniformOutput', false);


if(params.pbar > 0)
  ncbar.setBarTitle('Computing KS distances');
end
% Pairwise distances, returned as a numeric row vector of length m(m–1)/2, corresponding to pairs of observations, where m is the number of observations in X.
% The distances are arranged in the order (2,1), (3,1), ..., (m,1), (3,2), 
%..., (m,2), ..., (m,m–1), i.e., the lower-left triangle of the full m-by-m distance matrix in column order. The pairwise distance between observations i and j is in D((i-1)*(m-i/2)+j-i) for i≤j.
D = ones(1, length(members)*(length(members)-1)/2);
itt = 0;
for i = 1:length(members)
  for j = (i+1):length(members)
    itt = itt + 1;
    if(~isempty(ISIlist{i}) && ~isempty(ISIlist{j}))
      [~, p] = kstest2(ISIlist{i}(:), ISIlist{j}(:));
      D(itt) = p;
    end
    if(params.pbar > 0)
      ncbar.update(itt/length(D));
    end
  end
end
%nD = -log(D);
nD = D;
newmat = squareform(nD);
%Z = linkage(nD);

if(isempty(params.significanceLevel) || params.significanceLevel == 0)
  automatic = true;
else
  automatic = false;
end

minGroupSize = params.minimumGroupSize;
if(isempty(minGroupSize) || minGroupSize < 1)
  minGroupSize = 1;
end

if(automatic)
  if(params.pbar > 0)
    ncbar.setBarTitle('Looking for optimal significance level');
  end
  %pValueList = linspace(0+eps, 0.1, 50);
  pValueList = eval(params.automaticSignificanceRange);
  nClusters = zeros(size(pValueList));
  nBiggestGroup = zeros(size(pValueList));
  nInGroups = zeros(size(pValueList));
  stdDist = zeros(size(pValueList));
  skeDist = zeros(size(pValueList));

  for it = 1:length(pValueList)
    switch params.significanceMeasure
      case 'average'
        T = clusterdata(newmat, 'cutoff', length(newmat)*pValueList(it), 'criterion', 'distance', 'distance', 'cityblock');
      case 'max'
        T = clusterdata(newmat, 'cutoff', length(newmat)*pValueList(it), 'criterion', 'distance', 'distance', 'chebychev');
    end
    [a, b] = hist(T, 1:max(T));
    nClusters(it) = sum(a >= minGroupSize);
    nBiggestGroup(it) = max(a);
    nInGroups(it) = sum(a(a >= minGroupSize));
    stdDist(it) = std(a(a >= minGroupSize));
    skeDist(it) = skewness(a(a >= minGroupSize));
    if(params.pbar > 0)
      ncbar.update(it/length(pValueList));
    end
  end
  switch params.automaticSignificanceMeasure
    case 'largestGroup'
      [~, optimalIdx] = max(nInGroups-nBiggestGroup);
    case 'numGroups'
      [~, optimalIdx] = max(nInGroups);
    case 'skewness'
      [~, optimalIdx] = max(skeDist);
  end
  
  if(params.plotAutomaticSignificanceLevel)
    figure;
    subplot(2, 2, 1);
    plot(pValueList, nClusters,'o');
    box on;
    xlabel('avg p Value');
    ylabel('N clusters');
    subplot(2, 2, 2);
    plot(pValueList, nBiggestGroup/length(experiment.ROI),'o');
    hold on;
    plot(pValueList, nInGroups/length(experiment.ROI),'o');
    plot(pValueList(optimalIdx)*[1 1], [nBiggestGroup(optimalIdx) nInGroups(optimalIdx)]/length(experiment.ROI), '-k');
    legend('Biggest Group', 'In groups', sprintf('Optimal: %.3f', pValueList(optimalIdx)));
    xlabel('avg p Value');
    ylabel('Fraction');

    subplot(2, 2, 3);
    plot(pValueList, stdDist, 'o');
    hold on;
    box on;
    plot(pValueList(optimalIdx)*[1 1], [0 stdDist(optimalIdx)], '-k');
    xlabel('avg p Value');
    ylabel('std deviation');

    subplot(2, 2, 4);
    plot(pValueList, skeDist, 'o');
    hold on;
    box on;
    plot(pValueList(optimalIdx)*[1 1], [0 skeDist(optimalIdx)], '-k');
    xlabel('avg p Value');
    ylabel('skewness');
    mtit(sprintf('Optimal significance level for: %s', experiment.name));
  end
  targetPvalue = pValueList(optimalIdx);
else
  targetPvalue = params.significanceLevel;
end

switch params.significanceMeasure
  case 'average'
    T = clusterdata(newmat, 'cutoff', length(newmat)*targetPvalue, 'criterion', 'distance', 'distance', 'cityblock');
  case 'max'
    T = clusterdata(newmat, 'cutoff', length(newmat)*targetPvalue, 'criterion', 'distance', 'distance', 'chebychev');
end

[a, ~] = hist(T, 1:max(T));
[~, idx] = sort(a(T), 'descend');
[~, newidx] = sort(a, 'descend');

%experiment.traceGroupsOrder.ISI.everything{1} = members(idx);
experiment.traceGroups.ISI = cell(sum(a >= minGroupSize), 1);
experiment.traceGroupsNames.ISI = cell(sum(a >= minGroupSize), 1);
for it = 1:max(T)
  % Stop at the minimum group size
  if(sum(T == newidx(it)) < minGroupSize)
    break;
  end
  experiment.traceGroups.ISI{it} = members(find(T == newidx(it)));
  experiment.traceGroupsNames.ISI{it} = sprintf('%d', it);
end
if(it ~= max(T))
  experiment.traceGroupsNames.ISI{end+1} = 'without group';
  fullList = cellfun(@(x)x(:)',experiment.traceGroups.ISI, 'UniformOutput', false);
  fullList = [fullList{:}];
  fullList = fullList(:);
  % The members that we not on the previou groups
  experiment.traceGroups.ISI{end+1} = setdiff(members, fullList);
  %experiment.traceGroups.ISI{end+1} = members(sort(arrayfun(@(x)find(x==T), newidx(it:end))));
end
switch params.groupOrder
  case 'size'
    % Do nothing
  case 'firing rate'
    frList = zeros(length(experiment.traceGroups.ISI)-1, 1);
    for it = 1:(length(experiment.traceGroups.ISI)-1)
      frList(it) = length([experiment.spikes{experiment.traceGroups.ISI{it}}])/length(experiment.traceGroups.ISI{it});
    end
    [a, b] = sort(frList, 'descend');
    experiment.traceGroups.ISI(1:end-1) = experiment.traceGroups.ISI(b);
end

% Create a joint list with all group members
fullList = cellfun(@(x)x(:)',experiment.traceGroups.ISI, 'UniformOutput', false);
fullList = [fullList{:}];
fullList = fullList(:);
experiment.traceGroupsNames.ISI{end+1} = 'all members';
experiment.traceGroups.ISI{end+1} = sort(fullList);
experiment.traceGroupsOrder.ISI.ISI = cell(size(experiment.traceGroups.ISI));
experiment.traceGroupsOrder.ISI.ISI{end} = fullList;
notMembers = setdiff(1:length(experiment.ROI), fullList);
experiment.traceGroupsOrder.ISI.everything{1} = [fullList; notMembers(:)];
if(isfield(experiment.traceGroupsOrder, 'similarity') && isfield(experiment.traceGroupsOrder.similarity, 'ISI'))
  experiment.traceGroupsOrder.similarity = rmfield(experiment.traceGroupsOrder.similarity, 'ISI');
end

experiment.ISIsignificanceLevel = targetPvalue;

logMsg(sprintf('Found %d groups', length(experiment.traceGroups.ISI)), 'w');

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
