function experiment = importFilePatterns(experiment, varargin)
% IMPORTFILEPATTERNS function to load patterns from external file
%
% USAGE:
%    experiment = importFilePatterns(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: importPatternsOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = importFilePatterns(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: import patterns
% parentGroups: fluorescence: bursts, fluorescence: group classification: pattern-based
% optionsClass: importPatternsOptions
% requiredFields: folder, name
% producedFields: validPatterns

[params, var] = processFunctionStartup(importPatternsOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Importing patterns', true);
%--------------------------------------------------------------------------

fileName = params.fileName;
if(~exist(fileName, 'file'))
  logMsg(sprintf('%s file not found', fileName), 'e');
  barCleanup(params);
  return;
end
try
  newPatterns = loadjson(fileName, 'SimplifyCell', 0);
catch ME
  if(strcmpi(ME.identifier, 'MATLAB:UndefinedFunction'))
    errMsg = {'jsonlab toolbox missing. Please install it from the installDependencies folder'};
    uiwait(msgbox(errMsg,'Error','warn'));
  else
    logMsg('Something went wrong with json. Is jsonlab toolbox installed?', 'e');
  end
  barCleanup(params);
  return;
end
mode = params.mode;

if(params.removeAllPreviousPatterns)
  switch mode
    case 'traces'
      if(isfield(experiment, 'patternFeatures'))
        experiment = rmfield(experiment, 'patternFeatures');
      end
      if(isfield(experiment, 'importedPatternFeatures'))
        experiment = rmfield(experiment, 'importedPatternFeatures');
      end     
      if(isfield(experiment, 'learningEventListPerTrace'))
        experiment = rmfield(experiment, 'learningEventListPerTrace');
      end
    case 'bursts'
      if(isfield(experiment, 'burstPatterns'))
        experiment = rmfield(experiment, 'burstPatterns');
      end
      if(isfield(experiment, 'importedBurstPatternFeatures'))
        experiment = rmfield(experiment, 'importedBurstPatternFeatures');
      end
  end
end

[patterns, ~] = generatePatternList(experiment, mode);
% Append or add to the import list
if(~isfield(experiment, 'importedPatternFeatures'))
  experiment.importedPatternFeatures = {};
end
if(~isfield(experiment, 'importedBurstPatternFeatures'))
  experiment.importedBurstPatternFeatures = {};
end
importedPatterns = 0;
for it = 1:length(newPatterns)
  switch newPatterns{it}.type
    case {'auto', 'user', 'imported'}
      % Only import trace-type events if in the traces mode
      if(~strcmpi(mode, 'traces'))
        continue;
      end
      patternField = 'importedPatternFeatures';
      patternType = 'imported';
    case {'bursts', 'importedBursts'}'
      % Only import burst-type events if in the bursts mode
      if(~strcmpi(mode, 'bursts'))
        continue;
      end
      patternField = 'importedBurstPatternFeatures';
      patternType = 'importedBursts';
  end
  % Check for repeated names against the old set
  newName = newPatterns{it}.name;
  addPattern = true;
  % Couldn't care less about repeated names
  for it2 = 1:length(patterns)
    if(strcmpi(patterns{it2}.name, newName))
      if(params.removeIdenticalPatterns)
        px = patterns{it2};
        py = newPatterns{it};
        L = min(length(px.F), length(py.F));
        x = px.F(1:L);
        y = py.F(1:L);
        % For now, corrcoef, should use normalized xcorr instead
        R = corrcoef(x, y);
        if(R(1,2) >= 0.999)
          logMsg(sprintf('Found repeated pattern %s. Skipping', newPatterns{it}.name), 'w');
          addPattern = false;
          break;
        end
      end
    end
  end
  if(addPattern)
    experiment.(patternField){end+1} = struct;
    experiment.(patternField){end}.name = newName;
    experiment.(patternField){end}.basePattern = newPatterns{it}.basePattern;
    experiment.(patternField){end}.type = patternType;
    experiment.(patternField){end}.signal = newPatterns{it}.F;
    experiment.(patternField){end}.threshold = newPatterns{it}.threshold;
    importedPatterns = importedPatterns + 1;
  end
end

logMsg(sprintf('%d Patterns successfully imported', importedPatterns));

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end
