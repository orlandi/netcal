function experiment = saveExperiment(experiment, varargin)
% SAVEEXPERIMENT saves the current experiment
%
% USAGE:
%    saveExperiment(experiment)
%
% INPUT arguments:
%
%    experiment - structure obtained from loadExperiment()
%
%    'verbose' - true/false. If true, outputs verbose information
%
% EXAMPLE:
%    saveExperiment(experiment)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>

%--------------------------------------------------------------------------
params.verbose = true;
params.pbar = [];
params = parse_pv_pairs(params, varargin);
params = barStartup(params, 'Saving experiment', true);
%--------------------------------------------------------------------------
if(params.pbar > 0)
  pause(1); % For the bar
end
% Create folders (if they do not exist
if(~exist(experiment.folder, 'dir'))
  mkdir(experiment.folder);
end
dataFolder = [experiment.folder 'data' filesep];
if(~exist(dataFolder, 'dir'))
  mkdir(dataFolder);
end
    
% Save separately huge data variables if they exist
% We only need to save this fields when tey are modified
bigFields = getBigFields();
for i = 1:length(bigFields)
  savedBigFields = false;
  if(isfield(experiment, bigFields{i}) && ~ischar(experiment.(bigFields{i})))
    rawFile = [dataFolder experiment.name '_' bigFields{i} '.dat'];
    % If the file does not exist, create it and save it
    if(~exist(rawFile, 'file'))
      savedBigFields = true;
      if(params.pbar > 0)
        ncbar.setBarTitle(sprintf('Saving experiment %s', bigFields{i}));
      end
      save(rawFile, '-struct', 'experiment', bigFields{i}, '-v7.3');
    end
    if(isfield(experiment, 'saveBigFields') && experiment.saveBigFields)
      savedBigFields = true;
      if(params.pbar > 0)
        ncbar.setBarTitle(sprintf('Saving experiment %s', bigFields{i}));
      end
      save(rawFile, '-struct', 'experiment', bigFields{i}, '-v7.3');
    end
    if(exist(rawFile, 'file') && savedBigFields)
      experiment.(bigFields{i}) = [experiment.name '_' bigFields{i} '.dat'];
    elseif(savedBigFields)
      logMsg(['There was a problem saving ' bigFields{i} '. Aborting...'], 'e');
      return;
    else
      experiment.(bigFields{i}) = [experiment.name '_' bigFields{i} '.dat'];
    end
  end
end
% Disable since they were just saved
if(isfield(experiment, 'saveBigFields') && experiment.saveBigFields)
  experiment.saveBigFields = false;
end

% Remove GUI handles when saving - I don't think this is needed anymore
names = fieldnames(experiment);
for i = 1:numel(names)
  if(ismethod(experiment.(names{i}), 'setGui'))
    experiment.(names{i}) = experiment.(names{i}).setGui([]);
  end
end
if(isfield(experiment, 'data'))
  experiment = rmfield(experiment, 'data');
end
% Save the whole project
fullSaveFile = [experiment.folder experiment.saveFile];

[fpa, fpb, fpc] = fileparts(fullSaveFile);
fpa = GetFullPath(fpa);
if(~exist(fpa, 'dir'))
  mkdir(fpa);
end

if(params.pbar > 0)
  ncbar.setBarTitle('Saving backups');
end
backupFile = [fpa filesep fpb '.bak'];
backupHourlyFile = [fpa filesep fpb '.bkh'];
if(exist(fullSaveFile, 'file') == 2)
  copyfile(fullSaveFile, backupFile, 'f');
  % If the hourly backup file doesn't exist, create it
  if(exist(backupHourlyFile, 'file') ~= 2)
    copyfile(fullSaveFile, backupHourlyFile, 'f');
  else
    fileInfo = dir(backupHourlyFile);
    % If the old bkh file is more than 1h old, update it with the previous
    % backup
    if(etime(datevec(now), datevec(fileInfo.datenum))/3600 > 1)
      copyfile(fullSaveFile, backupHourlyFile, 'f');
    end
  end
end

if(params.pbar > 0)
  ncbar.setBarTitle('Saving experiment');
end
save(fullSaveFile, '-struct', 'experiment', '-mat', '-v7.3');

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
