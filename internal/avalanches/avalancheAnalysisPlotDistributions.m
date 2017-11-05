function experiment = avalancheAnalysisPlotDistributions(experiment, varargin)
% AVALANCHEANALYSISPLOTDISTRIBUTIONS computes the different avalanche distributions (sizes, durations and shapes)
%
% USAGE:
%    experiment = avalancheAnalysisPlotDistributions(experiment)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% INPUT optional arguments ('key' followed by its value):
%
%    see: avalancheOptions
%
% OUTPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% EXAMPLE:
%    experiment = avalancheAnalysisPlotDistributions(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: avalanche distributions plots
% parentGroups: avalanches: plots
% optionsClass: avalanchePlotsOptions
% requiredFields: avalanches

% Pass class options
optionsClass = avalanchePlotsOptions;
params = optionsClass().get;
if(length(varargin) >= 1 && isa(varargin{1}, class(optionsClass)))
  optionsClass = varargin{1};
  params = varargin{1}.get;
  if(length(varargin) > 1)
    varargin = varargin(2:end);
  else
    varargin = [];
  end
end
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, varargin);

infoMsg = 'Plotting avalanche sizes';
if(params.verbose && isempty(params.pbar))
  logMsgHeader(infoMsg, 'start');
  params.pbar = 1;
end

switch params.plotType
  case 'single'
  case 'together'
    hFigW = figure;
    hFigW.Position = setFigurePosition([], 'width', hFigW.Position(4)*3, 'height', hFigW.Position(4));
    title(sprintf('Avalanche statistics for %s', experiment.name));
end
%------------------------------------------------------------------------
% Size distribution
switch params.plotType
  case 'single'
    hFigW = figure;
  case 'together'
    subplot(1, 3, 1);
end

switch params.distributionPlotType
  case 'pdf'
    [hits, ~, histCenters] = integerLogBinning(experiment.avalanches.size(:), 'bins', params.plotBins);
    plot(histCenters, hits, 'Marker', params.plotMarker, 'LineStyle', 'none');
    ylabel('PDF');
  case 'cdf staircase'
    h = cdfplot(experiment.avalanches.size(:));
    ydata = get(h,'YData');
    set(h,'YData',1-ydata);
    ylabel('1-CDF');
    title(gca, '');
    %h.LineStyle = 'none';
    %h.Marker = '.';
  case 'cdf dotted'
    x = sort(experiment.avalanches.size(:));
    y = (1:length(x))/length(x);
    plot(x, 1-y, 'Marker', params.plotMarker, 'LineStyle', 'none');
    ylabel('1-CDF');
end
set(gca,'Xscale', 'log');
set(gca,'Yscale', 'log');
xlabel(sprintf('Avalanche sizes (bin = %d ms)', experiment.asdf2.binsize));

switch params.plotType
  case 'single'
    title(gca, sprintf('Avalanche size distribution for %s', experiment.name));
end

%------------------------------------------------------------------------
% Duration distribution
switch params.plotType
  case 'single'
    hFigW = figure;
  case 'together'
    subplot(1, 3, 2);
end
switch params.distributionPlotType
  case 'pdf'
    [hits, ~, histCenters] = integerLogBinning(experiment.avalanches.duration(:), 'bins', params.plotBins);
    plot(histCenters, hits, 'Marker', params.plotMarker, 'LineStyle', 'none');
    ylabel('PDF');
  case {'cdf staircase'}
    h = cdfplot(experiment.avalanches.duration(:));
    ydata = get(h,'YData');
    set(h,'YData',1-ydata);
    ylabel('1-CDF');
    title(gca, '');
    %h.LineStyle = 'none';
    %h.Marker = '.';
  case 'cdf dotted'
    x = sort(experiment.avalanches.duration(:));
    y = (1:length(x))/length(x);
    plot(x, 1-y, 'Marker', params.plotMarker, 'LineStyle', 'none');
    ylabel('1-CDF');
end
set(gca,'Xscale', 'log');
set(gca,'Yscale', 'log');
xlabel(sprintf('Avalanche durations (bin = %d ms)', experiment.asdf2.binsize));

switch params.plotType
  case 'single'
    title(gca, sprintf('Avalanche duration distribution for %s', experiment.name));
end

%------------------------------------------------------------------------
% Size/duration relation
switch params.plotType
  case 'single'
    hFigW = figure;
  case 'together'
    subplot(1, 3, 3);
end

plot(experiment.avalanches.size(:), experiment.avalanches.duration(:), 'Marker', params.plotMarker, 'LineStyle', 'none');
set(gca,'Xscale', 'log');
set(gca,'Yscale', 'log');
xlabel(sprintf('Avalanche sizes (bin = %d ms)', experiment.asdf2.binsize));
ylabel(sprintf('Avalanche durations (bin = %d ms)', experiment.asdf2.binsize));

switch params.plotType
  case 'single'
    title(gca, sprintf('Avalanche size/duration pairs for %s', experiment.name));
end

switch params.plotType
  case 'together'
    mtit(sprintf('Avalanche distributions for %s', experiment.name), 'yoff', 0.02);
end

if(params.verbose)
  logMsgHeader('Done!', 'finish');
end
