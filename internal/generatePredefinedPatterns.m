function experiment = generatePredefinedPatterns(experiment, varargin)
% GENERATEPREDEFINEDPATTERNS generates predefined patterns for event-based
% trace classsification
%
% USAGE:
%    experiment = generatePredefinedPatterns(experiment)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% INPUT optional arguments ('key' followed by its value):
%
%    See predefinedPatternsOptions
%
% EXAMPLE:
%    experiment = generatePredefinedPatterns(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: generate predefined patterns
% parentGroups: fluorescence: group classification: pattern-based
% optionsClass: predefinedPatternsOptions
% requiredFields: fps
% producedFields: patternFeatures

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(predefinedPatternsOptions, varargin{:});
params.pbar = [];
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Generating pattern-based trace features');
%--------------------------------------------------------------------------

dt = 1/experiment.fps;
patternFeatures = {};

if(params.exponentialPattern)
  currFeatureName = 'exponential';
  tauList = linspace(params.exponentialTauList(1), params.exponentialTauList(2), params.exponentialTauList(3));
  for it1 = 1:length(tauList)
    tau = tauList(it1);
    patternFeatures{end+1} = struct;
    patternFeatures{end}.name = sprintf('%s - tau: %.2g',currFeatureName, tau);
    maxT = ceil(tau*params.exponentialCutoff/dt);
    %patternSignal = exp(-(0:maxT)*dt/tau);
    patternSignal = exppdf((0:maxT)*dt, tau);
    patternFeatures{end}.signal = patternSignal;
    patternFeatures{end}.threshold = params.exponentialCorrelationThreshold;
    patternFeatures{end}.basePattern = currFeatureName;
  end
end

if(params.gaussianPattern)
  currFeatureName = 'gaussian';
  sigmaList = linspace(params.gaussianSigmaList(1), params.gaussianSigmaList(2), params.gaussianSigmaList(3));
  for it1 = 1:length(sigmaList)
    sigma = sigmaList(it1);
    patternFeatures{end+1} = struct;
    patternFeatures{end}.name = sprintf('%s - sigma: %.2g',currFeatureName, sigma);
    maxT = ceil(2*sigma*params.gaussianCutoff/dt);
    patternSignal = normpdf((0:maxT)*dt, maxT*dt/2, sigma);
    patternFeatures{end}.signal = patternSignal;
    patternFeatures{end}.threshold = params.gaussianCorrelationThreshold;
    patternFeatures{end}.basePattern = currFeatureName;
  end
end

if(params.lognormalPattern)
  currFeatureName = 'lognormal';
  sigmaList = linspace(params.lognormalSigmaList(1), params.lognormalSigmaList(2), params.lognormalSigmaList(3));
  modeList = linspace(params.lognormalModeList(1), params.lognormalModeList(2), params.lognormalModeList(3));
  for it1 = 1:length(sigmaList)
    for it2 = 1:length(modeList)
      sigma = sigmaList(it1);
      mode = modeList(it2);
      mu = log(mode)+sigma^2;
      %T = params.lognormalCutoff*lognpdf(mode, mu, sigma);
      T = 1-params.lognormalCutoff;
      
      patternFeatures{end+1} = struct;
      patternFeatures{end}.name = sprintf('%s - sigma: %.2g - mode: %.2g',currFeatureName, sigma, mode);
      maxT = ceil(min(100/dt, exp(sqrt(2)*sigma*erfinv(2*T-1)+mu)/dt)); % Hard maximum at 100 seconds
      patternSignal = lognpdf((0:maxT)*dt, mu, sigma);
      patternFeatures{end}.signal = patternSignal;
      patternFeatures{end}.threshold = params.lognormalCorrelationThreshold;
      patternFeatures{end}.basePattern = currFeatureName;
    end
  end
end

experiment.patternFeatures = patternFeatures;

if(params.showPatterns)
  % Plot the patterns
  nPatterns = length(patternFeatures);
  rc = ceil(sqrt(nPatterns));
  figure;
  for it = 1:nPatterns
    subplot(rc, rc, it);
    plot((1:length(experiment.patternFeatures{it}.signal))/experiment.fps, experiment.patternFeatures{it}.signal)
    %set(gca,'XTick',[]);
    set(gca,'YTick',[]);
    ylim([0 max(experiment.patternFeatures{it}.signal)*1.01]);
    xlim([1 length(experiment.patternFeatures{it}.signal)]/experiment.fps);
    title(patternFeatures{it}.basePattern);
  end
  barCleanup(params);
  return;
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
