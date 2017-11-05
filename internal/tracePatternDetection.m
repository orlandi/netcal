function experiment = tracePatternDetection(experiment, varargin)
% TRACEPATTERNSDETECTION detects patterns in traces for a given group
%
% USAGE:
%    experiment = tracePatternDetection(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: tracePatternDetectionOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = tracePatternDetection(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: detect patterns
% parentGroups: fluorescence: group classification: pattern-based
% optionsClass: tracePatternDetectionOptions
% requiredFields: t, traces, ROI, folder, name

[params, var] = processFunctionStartup(tracePatternDetectionOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.parallelMode = false;
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Detecting patterns');
%--------------------------------------------------------------------------

% Parallel is not really working (or worth it) Matlab already parallelizes the detection when possible
if(params.parallelMode)
  ncbar.setBarName('Initializing cluster');
  ncbar.setAutomaticBar();
  cl = parcluster('local');
end

% Load previous patterns NOT HERE
%experiment = loadTraces(experiment, 'validPatterns');

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

% Time to iterate through all the groups
for git = 1:length(groupList)
  if(params.pbar > 0)
    ncbar.setBarTitle(sprintf('Detecting patterns from group: %s', groupList{git}));
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
  
  % We will get the members later
  switch params.tracesType
    case 'smoothed'
      experiment = loadTraces(experiment, 'normal');
      t = experiment.t;
      traces = experiment.traces;
    case 'raw'
      experiment = loadTraces(experiment, 'raw');
      t = experiment.rawT;
      traces = experiment.rawTraces;
    case 'denoised'
      experiment = loadTraces(experiment, 'rawTracesDenoised');
      t = experiment.rawTDenoised;
      traces = experiment.rawTraces;
  end
  [patterns, ~] = generatePatternList(experiment);
  
  validPatterns = detectPatterns(t, traces(:, members), patterns, params.overlappingDiscriminationMethod, params.overlappingDiscriminationType, params.parallelMode);
  if(~isfield(experiment, 'validPatterns'))
    experiment.validPatterns = cell(size(traces, 2), 1);
    experiment.validPatterns(members) = validPatterns;
  else
    try
      experiment.validPatterns(members) = validPatterns;
    catch ME
      experiment.validPatterns = cell(size(traces, 2), 1);
      experiment.validPatterns(members) = validPatterns;
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    end
  end
  %if(params.verbose)
  logMsg(sprintf('Found %d total patterns',  sum(cellfun(@length, validPatterns))));
  patternList = [];
  for it = 1:length(validPatterns)
    patternList = [patternList, cellfun(@(x)x.basePattern, validPatterns{it}, 'UniformOutput', false)];
  end
  uniquePatterns = unique(patternList);
  % I kinda complicated myself here
  hits = cellfun(@sum, cellfun(@(x)strcmp(x, patternList), uniquePatterns, 'UniformOutput', false));
  for it = 1:length(uniquePatterns)
    logMsg(sprintf('Found %d patterns of type %s', hits(it), uniquePatterns{it}));
  end
  %end
%  experiment.traceBursts.(groupName){groupIdx} = burstList;
end

experiment.saveBigFields = true; % So the patterns are saved

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

  %------------------------------------------------------------------------
  function validPatterns = detectPatterns(t, traces, patterns, overlappingDiscriminationMethod, overlappingDiscriminationType, parallel)
    % Time to detect the patterns - for each neuron, a pattern list
    validPatterns = cell(size(traces, 2), 1);

    % New, faster version
    % Precompute for the patterns
    EY = cell(size(patterns));
    EYY = cell(size(patterns));
    b = cell(size(patterns));
    for it1 = 1:length(patterns)
      pattern = patterns{it1}.F(:)';
      EY{it1} = mean(pattern);
      EYY{it1} = mean(pattern.^2);
      b{it1} = ones(size(pattern))'/length(pattern);
    end

    
    nTraces = size(traces, 2);
    numTraces = size(traces, 2);
    if(parallel)
      for it2 = 1:numTraces
        futures(it2) = parfeval(@singleTracePatternDetection, 1, traces(:, it2), t, patterns, b, EY, EYY);
      end
      numCompleted = 0;
      ncbar.unsetAutomaticBar();
      while numCompleted < numTraces
        ncbar.setBarName(sprintf('Running parallel pattern detection (%d/%d)', numCompleted, numTraces));
        ncbar.update(numCompleted/numTraces);
        [completedIdx, validPattern] = fetchNext(futures);
        validPatterns{completedIdx} = validPattern;
        numCompleted = numCompleted + 1;
        ncbar.update(numCompleted/length(checkedExperiments));
      end
      cancel(futures);
      ncbar.close();
    else
      for it2 = 1:numTraces
        validPatterns{it2} = singleTracePatternDetection(traces(:, it2), t, patterns, b, EY, EYY);
        if(params.pbar > 0)
          ncbar.update(it2/nTraces);
        end
      end
    end

    % Now remove overlapping patterns
    switch overlappingDiscriminationMethod
      case 'correlation'
        logMsg('Removing overlapping patterns by correlation');
        if(params.pbar > 0)
          ncbar.setCleanActiveBar();
          ncbar.setBarTitle('Removing overlapping patterns');
        end
        for it1 = 1:length(validPatterns)
          done = false;
          firstPattern = 1;
          while(~done)
            done = true;
            foundPatterns = validPatterns{it1};
            for it2 = firstPattern:length(foundPatterns)
              pattern1 = validPatterns{it1}{it2};
              for it3 = (it2+1):length(foundPatterns)
                pattern2 = validPatterns{it1}{it3};
                switch params.overlappingDiscriminationType
                  case 'independent'
                    valid = true;
                  case 'groupBased'
                    % Only valid if both have the same base pattern
                    valid = strcmpi(pattern1.basePattern, pattern2.basePattern);
                  otherwise
                    valid = true;
                end
                if(valid && any(intersect(pattern1.frames, pattern2.frames)))
                  if(pattern1.coeff > pattern2.coeff)
                    validPatterns{it1}(it3) = [];
                  else
                    validPatterns{it1}(it2) = [];
                  end
                  firstPattern = it2;
                  done = false;
                  break;
                end
              end
              if(~done)
                break;
              end
            end
          end
          if(params.pbar > 0)
            ncbar.update(it1/length(validPatterns));
          end
        end
      case 'length'
        logMsg('Removing overlapping patterns');
        if(params.pbar > 0)
          ncbar.setCleanActiveBar();
          ncbar.setBarTitle('Removing overlapping by length');
        end
        for it1 = 1:length(validPatterns)
          done = false;
          firstPattern = 1;
          while(~done)
            done = true;
            foundPatterns = validPatterns{it1};
            for it2 = firstPattern:length(foundPatterns)
              pattern1 = validPatterns{it1}{it2};
              for it3 = (it2+1):length(foundPatterns)
                pattern2 = validPatterns{it1}{it3};
                switch overlappingDiscriminationType
                  case 'independent'
                    valid = true;
                  case 'groupBased'
                    % Only valid if both have the same base pattern
                    valid = strcmpi(pattern1.basePattern, pattern2.basePattern);
                  otherwise
                    valid = true;
                end
                if(valid && any(intersect(pattern1.frames, pattern2.frames)))
                  if(length(pattern1.frames) > length(pattern2.frames))
                    validPatterns{it1}(it3) = [];
                  else
                    validPatterns{it1}(it2) = [];
                  end
                  firstPattern = it2;
                  done = false;
                  break;
                end
              end
              if(~done)
                break;
              end
            end
          end
          if(params.pbar > 0)
            ncbar.update(it1/length(validPatterns));
          end
        end
      otherwise
    end
  end


  function validPattern = singleTracePatternDetection(signal, t, patterns, b, EY, EYY)
%    parfor(it1 = 1:size(traces, 2), parforArg)
 %     signal = traces(:, it1);
    validPattern = {};
    for it2 = 1:length(patterns)
      threshold = patterns{it2}.threshold;
      pattern = patterns{it2}.F(:)';
      % Since patterns might have different lenght, this has to go here
      % We are doing all
      [cc, ~] = xcorr(signal, pattern);
      EXY = cc(length(t):end)/length(pattern);
      revY = signal(end:-1:1);
      EX = filter(b{it2}, 1, revY);
      EX = EX(end:-1:1);
      EXX = filter(b{it2}, 1, revY.^2);
      EXX = EXX(end:-1:1);
      cc = (EXY-EX.*EY{it2})./(sqrt(EXX-EX.^2)*sqrt(EYY{it2}-EY{it2}.^2));
      done = false;
      %origCC = cc;
      while(~done)
        currT = find(cc > threshold, 1, 'first');
        if(isempty(currT))
          done = true;
          continue;
        end
        lastT = min(length(t), currT+length(pattern)-1);
        validPattern{end+1} = struct;
        validPattern{end}.frames = currT:lastT;
        validPattern{end}.coeff = cc(currT);
        validPattern{end}.pattern = it2;
        validPattern{end}.basePattern = patterns{it2}.basePattern;
        cc(1:lastT) = 0;
      end
    end
  end
end
