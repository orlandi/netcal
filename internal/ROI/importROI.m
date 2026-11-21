function project = importROI(project, varargin)
% IMPORTROI Imports external ROI list (either from another experiment or
% an external file)
%
% USAGE:
%   project = importROI(project, options)
%
% INPUT arguments:
%   project - structure containing a project
%
% INPUT optional arguments:
%   options - object from class importROIoptions
%
% INPUT optional arguments ('key' followed by its value):
%   gui - handle of the external GUI
%
% OUTPUT arguments:
%   project - structure containing an experiment
%
% EXAMPLE:
%   project = importROI(project, importROIoptions)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also importROIoptions

% PROJECT PIPELINE
% name: import ROI
% parentGroups: ROI: imports
% optionsClass: importROIoptions
% requiredFields: fps, numFrames, width, height
% producedFields: ROI
  
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(importROIoptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Importing ROI');
%--------------------------------------------------------------------------

switch params.origin 
  case 'experiment'
    %params.experiment
    experimentFile = [project.folderFiles params.experiment '.exp'];
    importROIfromRefExperiment(experimentFile);
  case 'external file'
    if(~exist(params.file, 'file')) %#ok<BDSCI,OR2,BDLGI>
        logMsg('Invalid ROI or experiment file', 'e');
        barCleanup(params);
        return;
    end
    [fpa, fpb, fpc] = fileparts(params.file);
    if(strcmpi(fpc, '.exp'))
      experimentFile = params.file;
      importROIfromRefExperiment(experimentFile);
    else
      valid = find(project.checkedExperiments);
      for it0 = 1:length(valid)
        if(params.pbar > 0)
          ncbar.setCurrentBarName(sprintf('Updating ROI on experiment: %s', project.experiments{valid(it0)}));
          ncbar.update(it0/length(valid));
        end
        experimentFile = [project.folderFiles project.experiments{valid(it0)} '.exp'];
        newExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);

        ROI = loadROI(newExperiment, params.file, 'overwriteMode', 'rawNew', 'verbose', false);


        switch params.importType
          case 'overwrite'
            lastID = 0;
            if(params.reassignIDs)
              for it1 = 1:length(ROI)
                ROI{it1}.ID = lastID+it1;
              end
            end
            %ROI = tmpROI;
          case 'append'
            IDlist = getROIid(newExperiment.ROI);
            lastID = max(IDlist);
            if(params.reassignIDs)
              for it1 = 1:length(ROI)
                ROI{it1}.ID = lastID+it1;
              end
            end
            ROI = [newExperiment.ROI; ROI];
        end
        newExperiment.ROI = ROI;

        if(params.verbose || params.pbar > 0)
          logMsg(sprintf('%d  ROI imported to experiment %s',length(newExperiment.ROI), newExperiment.name));
        end
        saveExperiment(newExperiment, 'pbar', 0, 'verbose', false);
      end
    end
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

  function importROIfromRefExperiment(experimentFile)
    refExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
  
    if(~isfield(refExperiment, 'ROI') || isempty(refExperiment.ROI))
      logMsg('No ROI found', 'e');
      barCleanup(params);
      return;
    end
    switch params.group
      case 'none'
        tmpROI = refExperiment.ROI;
      case 'ask'
        groupList = getExperimentGroupsNames(refExperiment);
        [selection, ok] = listdlg('PromptString', 'Select groups to use', 'ListString', groupList, 'SelectionMode', 'single');
        if(~ok)
          logMsg('No group selected. Quitting', 'w');
          return;
        end
        groupList = groupList{selection};
        members = getExperimentGroupMembers(refExperiment, groupList);
        tmpROI = refExperiment.ROI(members);
    end
    ROI = tmpROI;
    logMsg([num2str(length(ROI)) ' ROI imported']);
    valid = find(project.checkedExperiments);
    for it = 1:length(valid)
      if(params.pbar > 0)
        ncbar.setCurrentBarName(sprintf('Updating ROI on experiment: %s', project.experiments{valid(it)}));
        ncbar.update(it/length(valid));
      end
      experimentFile = [project.folderFiles project.experiments{valid(it)} '.exp'];
      newExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      if(refExperiment.width ~= newExperiment.width || refExperiment.height ~= newExperiment.height)
        logMsg(sprintf('Experiments differ in image size (%dx%d vs %dx%d). I will do my best to accomodate', refExperiment.width, refExperiment.height, newExperiment.width, newExperiment.height), 'w');
        tmpROI = ROI;
        fullInvalid = 0;
        invalidROI = [];
        for it2 = 1:length(tmpROI)
          px = tmpROI{it2}.pixels;
          [r, c] = ind2sub(size(refExperiment.avgImg),  px);
          invalid = find(r > newExperiment.height | c > newExperiment.width);
          fullInvalid = fullInvalid + length(invalid);
          if(length(invalid) == length(r))
            invalidROI = [invalidROI; it2];
          else
            if(~isempty(invalid))
              r(invalid) = [];
              c(invalid) = [];
              if(isfield(tmpROI{it2}, 'weights'))
                tmpROI{it2}.weights(invalid) = [];
              end
            end
            newpx = sub2ind(size(newExperiment.avgImg), r, c);
            tmpROI{it2}.pixels = newpx;
            tmpROI{it2}.center = [mean(c), mean(r)];
            tmpROI{it2}.maxDistance = max(sqrt((tmpROI{it2}.center(1)-c).^2+(tmpROI{it2}.center(2)-r).^2));
          end
        end
        tmpROI(invalidROI) = [];
        ROI = tmpROI;
        logMsg(sprintf('Had to remove %d pixels from the ROI list', fullInvalid), 'w');
      else
      %  ROI = ROI;
      end
      
      if(params.verbose || params.pbar > 0)
        logMsg(sprintf('%d new ROI to be assigned to experiment %s',length(ROI), newExperiment.name));
      end
      
      switch params.importType
        case 'overwrite'
          lastID = 0;
          if(params.reassignIDs)
            for it1 = 1:length(ROI)
              ROI{it1}.ID = lastID+it1;
            end
          end
          %ROI = tmpROI;
        case 'append'
          IDlist = getROIid(newExperiment.ROI);
          lastID = max(IDlist);
          if(params.reassignIDs)
            for it1 = 1:length(ROI)
              ROI{it1}.ID = lastID+it1;
            end
          end
          ROI = [newExperiment.ROI; ROI];
      end
      newExperiment.ROI = ROI;
      if(params.verbose || params.pbar > 0)
        logMsg(sprintf('Experiment %s now has %d ROI',newExperiment.name, length(newExperiment.ROI)));
      end
      saveExperiment(newExperiment, 'pbar', 0, 'verbose', false);
    end
  end
end
