function experiment = measureTracesQCEC(experiment, varargin)
% MEASURETRACESQCEC measures the q-complexity-entropy curves for fluorescence traces
%
% USAGE:
%    experiment = measureTracesQCEC(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: measureTracesQCECoptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = measureTracesQCEC(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also extractTraces

% EXPERIMENT PIPELINE
% name: measure q-complexity-entropy curves
% parentGroups: fluorescence: basic, spikes
% optionsClass: measureTracesQCECoptions
% requiredFields: traces
% producedFields: qEntropy, qComplexity, qList

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(measureTracesQCECoptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Measuring q-complexity-entropy curves');
%--------------------------------------------------------------------------

switch params.tracesType
  case 'smoothed'
    experiment = loadTraces(experiment, 'normal');
    traces = experiment.traces;
  case 'raw'
    experiment = loadTraces(experiment, 'raw');
    traces = experiment.rawTraces;
  case 'spikes'
    dt = 1/experiment.fps;
    t = experiment.t(1):dt:experiment.t(end);
    traces = zeros(length(t), length(experiment.ROI));
    
    % Assuming that you cannot have more than one spike on the same frame
    for i = 1:length(experiment.spikes)
      [~, validFrames] = arrayfun(@(x,y)min(abs(x - t)), experiment.spikes{i});
      traces(validFrames, i) = traces(validFrames, i) + 1;
    end
    % Only on the average trace if spikes
    traces = sum(traces, 2);
end

d = params.embeddingDimension;
facd = factorial(d);
qList = logspace(params.qList(1), params.qList(2), params.qList(3));
nTraces = size(traces, 2);
qCEC.C = zeros(nTraces, length(qList));
qCEC.H = zeros(nTraces, length(qList));
qCEC.minH = zeros(nTraces, 1);
qCEC.maxC = zeros(nTraces, 1);
qCEC.perimeter = zeros(nTraces, 1);
qCEC.qList = qList;
  
[~, q1] = min(abs(qList-1));

for idx = 1:nTraces
  selTrace = traces(:, idx);
  %selTrace = smooth(experiment.traces(:, idx), 30);
  %selTrace = selTrace(1:100:end);
  
  permList = zeros(length(selTrace)-d+1, 1);

  for it = d:length(selTrace)
    permList(it-d+1) = permutationIndex(selTrace((it-d+1):it));
  end
  [P, ~] = hist(permList, 1:facd);
  P = P/(length(selTrace)-d+1);

  [HqList, CqList] = measureQcomplexityEntropyCurve(P, d, qList);
  
  qCEC.C(idx, :) = CqList;
  qCEC.H(idx, :) = HqList;
  qCEC.minH(idx) = min(HqList);
  qCEC.maxC(idx) = max(CqList);
  qCEC.perimeter(idx) = sum(sqrt(sum(diff([CqList'; HqList']).^2,2)));
  if(params.pbar > 0)
    ncbar.update(idx/nTraces);
  end
end

if(params.plotQCEC)
  hFig = figure;
  hold on;
  for it = 1:nTraces
    h = plot3(qCEC.H(it, :), qCEC.C(it, :), qCEC.qList, '-');  
    plot3(qCEC.H(it, q1), qCEC.C(it, q1), it, 'o', 'Color', h.Color);
  end
  plot3(mean(qCEC.H,1), mean(qCEC.C,1), qCEC.qList, '-', 'Color', 'k', 'LineWidth', 2);
  xlabel('q-Entropy Hq');
  ylabel('q-Complexity Cq');
  zlabel('q');
  view([0 90]);
  title('q-entropy-complexity curve');
  box on;
  ui = uimenu(hFig, 'Label', 'Export');
  uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_qCEC']});
end

% Now sort by entropy - minimum first
[~, newIdx]= sort(qCEC.minH);
experiment.traceGroupsOrder.entropy.everything{1} = newIdx;

% Highest complexity first
[~, newIdx]= sort(qCEC.maxC, 'descend');
experiment.traceGroupsOrder.complexity.everything{1} = newIdx;

% Highest perimeter first
[~, newIdx]= sort(qCEC.perimeter, 'descend');
experiment.traceGroupsOrder.qCEC.everything{1} = newIdx;

% Save whatever
experiment.qCEC = qCEC;


%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
