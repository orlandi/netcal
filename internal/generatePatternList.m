function [patterns, basePatternList] = generatePatternList(experiment, varargin)
  if(nargin < 2)
    mode = 'traces';
  else
    mode = varargin{1};
  end
  if(isempty(mode))
    mode = 'traces';
  end
  patterns = {};
  basePatternList = {};
  switch mode
    case 'traces'
      if(isfield(experiment, 'patternFeatures'))
        patternList = experiment.patternFeatures;
        for it1 = 1:length(patternList)
          patterns{end+1} = struct;
          patterns{end}.name = patternList{it1}.name;
          patterns{end}.fullName = sprintf('%s (%s)', patternList{it1}.name, patternList{it1}.basePattern);
          patterns{end}.basePattern = patternList{it1}.basePattern;
          patterns{end}.type = 'auto';
          patterns{end}.idx = it1;
          patterns{end}.t = ((1:length(patternList{it1}.signal))-1)/experiment.fps;
          patterns{end}.F = patternList{it1}.signal;
          patterns{end}.threshold = patternList{it1}.threshold;
          patterns{end}.plotHandle = [];
          basePatternList{end+1} = patterns{end}.basePattern;
        end
      end
      % Same as above
      if(isfield(experiment, 'importedPatternFeatures'))
        patternList = experiment.importedPatternFeatures;
        for it1 = 1:length(patternList)
          patterns{end+1} = struct;
          patterns{end}.name = patternList{it1}.name;
          patterns{end}.fullName = sprintf('%s (%s)', patternList{it1}.name, patternList{it1}.basePattern);
          patterns{end}.basePattern = patternList{it1}.basePattern;
          patterns{end}.type = 'imported';
          patterns{end}.idx = it1;
          patterns{end}.t = ((1:length(patternList{it1}.signal))-1)/experiment.fps;
          patterns{end}.F = patternList{it1}.signal;
          patterns{end}.threshold = patternList{it1}.threshold;
          patterns{end}.plotHandle = [];
          basePatternList{end+1} = patterns{end}.basePattern;
        end
      end
      if(isfield(experiment, 'learningEventListPerTrace'))
        for it1 = 1:length(experiment.learningEventListPerTrace)
          for it2 = 1:length(experiment.learningEventListPerTrace{it1})
            patterns{end+1} = struct;
            patterns{end}.name = sprintf('%d', experiment.learningEventListPerTrace{it1}{it2}.id);
            patterns{end}.fullName = sprintf('%d (%s)', experiment.learningEventListPerTrace{it1}{it2}.id, experiment.learningEventListPerTrace{it1}{it2}.basePattern);
            patterns{end}.basePattern = experiment.learningEventListPerTrace{it1}{it2}.basePattern;
            patterns{end}.type = 'user';
            patterns{end}.idx = [it1 it2];
            patterns{end}.t = (experiment.learningEventListPerTrace{it1}{it2}.x-experiment.learningEventListPerTrace{it1}{it2}.x(1))/experiment.fps;
            patterns{end}.F = experiment.learningEventListPerTrace{it1}{it2}.y;
            if(~isfield(experiment.learningEventListPerTrace{it1}{it2}, 'threshold'))
              patterns{end}.threshold = 0.9;
            else
              patterns{end}.threshold = experiment.learningEventListPerTrace{it1}{it2}.threshold;
            end
            patterns{end}.plotHandle = [];
            basePatternList{end+1} = patterns{end}.basePattern;
          end
        end
      end
      basePatternList = unique(basePatternList);
    case 'bursts'
      if(isfield(experiment, 'burstPatterns'))
        groupNames = getExperimentGroupsNames(experiment);
        %experiment.traceBursts.(groupType){groupIdx} = burstStructure;
        %[field, idx] = getExperimentGroupCoordinates(experiment, name)
        for it1 = 1:length(groupNames)
          [field, idx] = getExperimentGroupCoordinates(experiment, groupNames{it1});
          if(~isfield(experiment.burstPatterns, field) || length(experiment.burstPatterns.(field)) < idx)
            continue;
          end
          % Process
          currPatterns = experiment.burstPatterns.(field){idx};
          
          for it2 = 1:length(currPatterns)
            patterns{end+1} = struct;
            patterns{end}.name = sprintf('%d', currPatterns{it2}.id);
            patterns{end}.fullName = sprintf('%d (%s)', currPatterns{it2}.id, currPatterns{it2}.basePattern);
            patterns{end}.basePattern = currPatterns{it2}.basePattern;
            patterns{end}.type = 'bursts';
            %patterns{end}.idx = [it1 it2];
            patterns{end}.idx = {field, idx, it2};
            patterns{end}.t = (currPatterns{it2}.x-currPatterns{it2}.x(1))/experiment.fps;
            patterns{end}.F = currPatterns{it2}.y;
            if(~isfield(currPatterns{it2}, 'threshold'))
              patterns{end}.threshold = 0.9;
            else
              patterns{end}.threshold = currPatterns{it2}.threshold;
            end
            patterns{end}.plotHandle = [];
            basePatternList{end+1} = patterns{end}.basePattern;
          end
        end
      end
      % Same as above
      if(isfield(experiment, 'importedBurstPatternFeatures'))
        patternList = experiment.importedBurstPatternFeatures;
        for it1 = 1:length(patternList)
          patterns{end+1} = struct;
          patterns{end}.name = patternList{it1}.name;
          patterns{end}.fullName = sprintf('%s (%s)', patternList{it1}.name, patternList{it1}.basePattern);
          patterns{end}.basePattern = patternList{it1}.basePattern;
          patterns{end}.type = 'importedBursts';
          patterns{end}.idx = it1;
          patterns{end}.t = ((1:length(patternList{it1}.signal))-1)/experiment.fps;
          patterns{end}.F = patternList{it1}.signal;
          patterns{end}.threshold = patternList{it1}.threshold;
          patterns{end}.plotHandle = [];
          basePatternList{end+1} = patterns{end}.basePattern;
        end
      end
      basePatternList = unique(basePatternList);
  end
end
