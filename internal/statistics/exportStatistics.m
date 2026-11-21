classdef exportStatistics < handle
% Main class to export any one-dimensional statistic. Taking into account projects, experiments, labels, groups, etc
%
%   Copyright (C) 2016-2018, Javier G. Orlandi
  
  properties
    figureHandle;
    axisHandle;
    fullStatisticsData;
    fullStatisticsDataFull;
    statisticsName;
    labelList;
    mainGroup;
    mode;
    params; % Set at init
    guiHandle; % Set at init
    groupList;
    maxGroups;
    experimentNames;
    groupLabels;
    fullGroupList;
    exportFolder;
    loadFields;
    fullData;
    fullDataMember;
    fullDataID;
    featureList;
    projexp;
  end
  
  methods
    % Use this function to setup the statistics data
    %----------------------------------------------------------------------
    function success = getData(obj, optionsObject, projexp, featList, varargin)
      success = false;
      obj.featureList = featList;
      
      switch obj.mode
        case 'project'
          [success, data, dataMember, dataID] = getDataProject(obj, optionsObject, projexp, obj.mainGroup, featList, varargin{:});
          obj.fullData = data;
          obj.fullDataMember = dataMember;
          obj.fullDataID = dataID;
        case 'experiment'
          [success, data, dataMember, dataID] = getDataExperiment(obj, optionsObject, projexp, obj.mainGroup, featList, varargin{:});
          obj.fullData = data;
          obj.fullDataMember = dataMember;
          obj.fullDataID = dataID;
          obj.experimentNames = {projexp.name};
      end
    end
    
    %----------------------------------------------------------------------
    function [success, data, dataMember, dataID] = getDataExperiment(obj, optionsObject, experiment, mainGroup, featList, varargin)
      success = false;
      data = {};

      % Get ALL subgroups in case of parents
      if(~iscell(mainGroup) && (strcmpi(mainGroup, 'all') || strcmpi(mainGroup, 'ask')))
        tmpGroupList = getExperimentGroupsNames(experiment);
      elseif(~iscell(mainGroup))
        tmpGroupList = getExperimentGroupsNames(experiment, mainGroup);
      else
        tmpGroupList = mainGroup;
      end
      % If ask, open the popup
      if(~iscell(mainGroup) && strcmpi(mainGroup, 'ask'))
        [selection, ok] = listdlg('PromptString', 'Select groups to use', 'ListString', tmpGroupList, 'SelectionMode', 'multiple');
        if(~ok)
          return;
        end
        tmpGroupList = tmpGroupList(selection);
      end
      if(~iscell(tmpGroupList))
        tmpGroupList = {tmpGroupList};
      end
      
      % data dimensions are {experiment}{group}{feature}[list] / so they are consistent between experiment and project modes
      data{1} = cell(length(tmpGroupList), 1);
      dataMember{1} = cell(length(tmpGroupList), 1);
      dataID{1} = cell(length(tmpGroupList), 1);
      
      for git = 1:length(tmpGroupList)
        % Again, for compatibility reasons
        if(strcmpi(tmpGroupList{git}, 'none'))
          tmpGroupList{git} = 'everything';
        end
        % Here is where we obtain the data
        %tmpData = feval(funcHandle, experiment, tmpGroupList{git}, featList, varargin{:});
        tmpData = optionsObject.getData(experiment, tmpGroupList{git}, featList, varargin{:});
        % Turn into a unit cell in case featList is of size 1
        if(~iscell(tmpData))
          data{1}{git}{1} = tmpData;
        else
          data{1}{git} = tmpData;
        end
        dataMember{1}{git} = cell(length(data{1}{git}), 1);
        dataID{1}{git} = cell(length(data{1}{git}), 1);
        for it3 = 1:length(data{1}{git})
          dataMember{1}{git}{it3} = getExperimentGroupMembers(experiment, tmpGroupList{git});
          dataID{1}{git}{it3} = getROIid(experiment.ROI(dataMember{1}{git}{it3}));
        end
        % Turn zeros to nans
        if(obj.params.zeroToNan)
          for it1 = 1:length(data{1}{git})
            data{1}{git}{it1}(data{1}{git}{it1} == 0) = NaN;
          end
        end
        if(isempty(data{1}))
          logMsg(sprintf('Found no data for group %s on experiment %s', tmpGroupList{git}, experiment.name), obj.gui, 'w');
          continue;
        end
      end
      if(isempty(obj.groupList))
        obj.groupList = tmpGroupList;
      end
      success = true;
    end
    
    %----------------------------------------------------------------------
    function [success, data, dataMember, dataID] = getDataProject(obj, optionsObject, project, mainGroup, featList, varargin)
      success = false;

      checkedExperiments = find(project.checkedExperiments);
      
      if(obj.params.pbar > 0)
        ncbar.setCurrentBarName(sprintf('Gathering data (%d/%d)', 0, length(checkedExperiments))');
        ncbar.update(0);
      end
      
      %%% First pass to gather all groups names
      obj.experimentNames = cell(length(checkedExperiments));
      for it1 = 1:length(checkedExperiments)
        experimentName = project.experiments{checkedExperiments(it1)};
        obj.experimentNames{it1} = experimentName;
        experimentFile = [project.folderFiles experimentName '.exp'];
        experiment = load(experimentFile, '-mat', 'traceGroups', 'traceGroupsNames');
        % Get ALL subgroups in case of parents
        if(strcmpi(mainGroup, 'all') || strcmpi(mainGroup, 'ask'))
          obj.groupList = getExperimentGroupsNames(experiment);
        else
          obj.groupList = getExperimentGroupsNames(experiment, obj.mainGroup);
        end
        obj.fullGroupList = unique([obj.fullGroupList(:); obj.groupList(:)]);
      end
      % If ask, open the popup to select some groups
      if(strcmpi(obj.mainGroup, 'ask'))
        [selection, ok] = listdlg('PromptString', 'Select groups to use', 'ListString', obj.fullGroupList, 'SelectionMode', 'multiple');
        if(~ok)
          success = false;
          return;
        end
        obj.fullGroupList = obj.fullGroupList(selection);
      end
      obj.groupList = obj.fullGroupList;
      if(~iscell(obj.groupList))
        obj.groupList = {obj.groupList};
      end
      obj.maxGroups = length(obj.groupList);
      
      % Data structure
      % data dimensions are {experiment}{group}{feature}[list] / so they are consistent between experiment and project modes
      data = cell(length(checkedExperiments), 1);
      dataMember = cell(length(checkedExperiments), 1);
      dataID = cell(length(checkedExperiments), 1);
      %%% Gather the data
      for it1 = 1:length(checkedExperiments)
        experimentName = project.experiments{checkedExperiments(it1)};
        % Load the experiment
        experimentFile = [project.folderFiles experimentName '.exp'];
        if(~isempty(obj.params.loadFields))
          warning('off', 'MATLAB:load:variableNotFound');
          exp = load(experimentFile, '-mat', 'traceGroups', 'traceGroupsNames', 'name', 'folder', 'ROI', obj.params.loadFields{:});
          warning('on', 'MATLAB:load:variableNotFound');
        else
          exp = loadExperiment(experimentFile, 'verbose', false, 'project', project);
        end
        % Get data from the experiment;
        try
          [success, expData, expDataMember, expDataID] = getDataExperiment(obj, optionsObject, exp, obj.groupList, featList, varargin{:});
          if(success)
            data{it1} = expData{1};
            dataMember{it1} = expDataMember{1};
            dataID{it1} = expDataID{1};
          else
            data{it1} = cell(obj.groupList, 1);
            dataMember{it1} = cell(obj.groupList, 1);
            dataID{it1} = cell(obj.groupList, 1);
            for it2 = 1:length(data{it1})
              data{it1}{it2} = cell(length(featList));
              dataMember{it1}{it2} = cell(length(featList));
              dataID{it1}{it2} = cell(length(featList));
              for it3 = 1:length(data{it1}{it2})
                data{it1}{it2}{it3} = NaN;
                dataMember{it1}{it2}{it3} = NaN;
                dataID{it1}{it2}{it3} = NaN;
              end
            end
          end
        catch ME
          logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'w'); %#ok<SPRINTFN>
          logMsg(sprintf('Error getting data from experiment %s. Setting it to NaN', experimentName), 'w');
          data{it1} = cell(obj.groupList, 1);
          dataMember{it1} = cell(obj.groupList, 1);
          dataID{it1} = cell(obj.groupList, 1);
          for it2 = 1:length(data{it1})
            data{it1}{it2} = cell(length(featList));
            dataMember{it1}{it2} = cell(length(featList));
            dataID{it1}{it2} = cell(length(featList));
            for it3 = 1:length(data{it1}{it2})
              data{it1}{it2}{it3} = NaN;
              dataMember{it1}{it2}{it3} = NaN;
              dataID{it1}{it2}{it3} = NaN;
            end
          end
        end
        if(obj.params.pbar > 0)
          ncbar.setCurrentBarName(sprintf('Gathering data (%d/%d)', it1, length(checkedExperiments))');
          ncbar.update(it1/length(checkedExperiments));
        end
      end
    end
    
    %----------------------------------------------------------------------
    function init(obj, projexp, optionsClass, msg, varargin)
      %--------------------------------------------------------------------
      [obj.params, var, newClass] = processFunctionStartup(optionsClass, varargin{:});
      % Define additional optional argument pairs
      obj.params.pbar = [];
      obj.params.gui = [];
      obj.params.loadFields = {};
      obj.params.plotDataFull = [];
      % Parse them
      obj.params = parse_pv_pairs(obj.params, var);
      obj.params = barStartup(obj.params, msg);
      %obj.params = obj.params;
      obj.guiHandle = obj.params.gui;
      obj.groupList = [];
      obj.projexp = projexp;
      %--------------------------------------------------------------------
      
      % Fix in case for some reason the group is a cell
      if(iscell(obj.params.group))
        obj.mainGroup = obj.params.group{1};
      else
        obj.mainGroup = obj.params.group;
      end

      % Check if its a project or an experiment
      if(isfield(projexp, 'saveFile'))
        [~, ~, fpc] = fileparts(projexp.saveFile);
        if(strcmpi(fpc, '.exp'))
          obj.mode = 'experiment';
          experiment = projexp;
          baseFolder = experiment.folder;
        else
          obj.mode = 'project';
          project = projexp;
          baseFolder = project.folder;
        end
      else
        obj.mode = 'project';
        project = projexp;
        baseFolder = project.folder;
      end
      
      % Create necessary folders
      if(strcmpi(obj.mode, 'experiment'))
        switch obj.params.exportOptions.baseFolder
          case 'experiment'
            baseFolder = experiment.folder;
          case 'project'
            baseFolder = [experiment.folder '..' filesep];
        end
      else
        baseFolder = project.folder;
      end
      if(~exist(baseFolder, 'dir'))
        mkdir(baseFolder);
      end
      obj.exportFolder = [baseFolder 'exports' filesep];
      if(~exist(obj.exportFolder, 'dir'))
        mkdir(obj.exportFolder);
      end
      
      tmpStat = obj.params.statistic;
      % Process statistic list
      if(strcmpi(tmpStat, 'ask') || strcmpi(tmpStat, 'all'))
        switch obj.mode
          case 'project'
            exp = [project.folderFiles project.experiments{find(project.checkedExperiments, 1, 'first')} '.exp'];
            tmpClass = optionsClass.setExperimentDefaults(exp);
          case 'experiment'
            tmpClass = optionsClass.setExperimentDefaults(experiment);
        end
        %tmpClass = defClass.setExperimentDefaults([]);
        statList = tmpClass.statistic(1:end-2); % Removing last one since it's going to be empty and 'all'
        if(strcmpi(tmpStat, 'ask'))
          [selection, ok] = listdlg('PromptString', 'Select statistics to export', 'ListString', statList, 'SelectionMode', 'multiple');
          if(~ok)
            return;
          end
        elseif(strcmpi(tmpStat, 'all'))
          selection = 1:length(statList);
        end
        statList = statList(selection);
      else
        statList = {tmpStat};
      end
      obj.params.statistic = statList;
      if(obj.getData(newClass, projexp, obj.params.statistic))
        obj.exportData();
      end
      obj.cleanup();
    end

    
    %----------------------------------------------------------------------
    function cleanup(obj)
      
      %--------------------------------------------------------------------
      barCleanup(obj.params);
      %--------------------------------------------------------------------
    end

    function exportData(obj)
      switch obj.params.exportMode
        case 'summary'
          obj.exportDataAggregates();
        case 'full'
          obj.exportDataFull();
      end
    end
    %--------------------------------------------------------------------
    function exportDataAggregates(obj)
      switch obj.mode
        case 'experiment'
          if(length(obj.featureList) == 1)
            fileName = [obj.exportFolder obj.experimentNames{1} '_' obj.featureList{1} '_' obj.params.exportOptions.fileTag '_aggregates.csv'];
          else
            fileName = [obj.exportFolder obj.experimentNames{1} '_multiStatistics_' obj.params.exportOptions.fileTag '_aggregates.csv'];
          end
        case 'project'
          if(length(obj.featureList) == 1)
            fileName = [obj.exportFolder 'project_' obj.featureList{1} '_' obj.params.exportOptions.fileTag '_aggregates.csv'];
          else
            fileName = [obj.exportFolder 'project_multiStatistics_' obj.params.exportOptions.fileTag '_aggregates.csv'];
          end
      end

      fID = fopen(fileName, 'w');

      % List of additional columns
      additionalColumns = 0;
      

      % Let's start with the headers
      %First the experiment Names
      lineStr = 'experiment';
      for it1 = 1:length(obj.experimentNames)
        curColumns = (length(obj.groupList)+additionalColumns)*length(obj.featureList);
        for it2 = 1:curColumns
          lineStr = sprintf('%s,"%s"', lineStr, obj.experimentNames{it1});
        end
      end
      lineStr = sprintf('%s\n', lineStr);
      fprintf(fID, lineStr);
      
      % Now the groups
      lineStr = 'group';
      for it1 = 1:length(obj.experimentNames)
        for it2 = 1:length(obj.groupList)
          for it3 = 1:(length(obj.featureList)+additionalColumns)
            lineStr = sprintf('%s,"%s"', lineStr, obj.groupList{it2});
          end
        end
      end
      lineStr = sprintf('%s\n', lineStr);
      fprintf(fID, lineStr);
      
      % Now the features
      obj.featureList
      lineStr = 'statistic';
      for it1 = 1:length(obj.experimentNames)
        for it2 = 1:length(obj.groupList)
          for it3 = 1:length(obj.featureList)
            lineStr = sprintf('%s,"%s"', lineStr, obj.featureList{it3});
          end
        end
      end
      lineStr = sprintf('%s\n', lineStr);
      fprintf(fID, lineStr);
      
      % Now we can plot the actual data
      measureNames = {'mean', 'median', 'std', 'ske', 'N (with nans)', 'N (without NaNs)', 'Q1', 'Q3', 'IQR', 'min', 'max', 'nans', 'zeros', 'non-zeros'};
      for it0 = 1:length(measureNames)
        lineStr = measureNames{it0};
        for it1 = 1:length(obj.experimentNames)
          for it2 = 1:length(obj.groupList)
            for it3 = 1:(length(obj.featureList))
              curData = obj.fullData{it1}{it2}{it3};
              invalid = find(isnan(curData));
              valid = find(~isnan(curData));
              curData = curData(valid);
              curFormat = obj.params.exportOptions.dataFormat;
              switch measureNames{it0}
                case 'mean'
                  val = mean(curData);
                case 'median'
                  val = median(curData);
                case 'std'
                  val = std(curData);
                case 'ske'
                  val = skewness(curData);
                case 'N (with nans)'
                  val = length(valid)+length(invalid);
                  curFormat = '%d';
                case 'N (without NaNs)'
                  val = length(valid);
                  curFormat = '%d';
                case 'Q1'
                  val = prctile(curData, 25);
                case 'Q3'
                  val = prctile(curData, 75);
                case 'IQR'
                  val = prctile(curData, 75) - prctile(curData, 25);
                case 'min'
                  val = min(curData);
                case 'max'
                  val = max(curData);
                case 'nans'
                  val = length(invalid);
                  curFormat = '%d';
                case 'zeros'
                  val = sum(curData == 0);
                  curFormat = '%d';
                case 'non-zeros'
                  val = sum(curData ~= 0);
                  curFormat = '%d';
              end
              if(obj.params.exportOptions.NaNtoBlank && isnan(val))
                  lineStr = sprintf('%s,""', lineStr);
              else
                lineStr = sprintf(['%s,"' curFormat ' "'], lineStr, val);
              end
            end
          end
        end
        lineStr = sprintf('%s\n', lineStr);
        fprintf(fID, lineStr);
      end
      fclose(fID);
    end

    %--------------------------------------------------------------------
    function exportDataFull(obj)
      switch obj.mode
        case 'experiment'
          if(length(obj.featureList) == 1)
            fileName = [obj.exportFolder obj.experimentNames{1} '_' obj.featureList{1} '_' obj.params.exportOptions.fileTag '_full.csv'];
          else
            fileName = [obj.exportFolder obj.experimentNames{1} '_multiStatistics_' obj.params.exportOptions.fileTag '_full.csv'];
          end
        case 'project'
          if(length(obj.featureList) == 1)
            fileName = [obj.exportFolder 'project_' obj.featureList{1} '_' obj.params.exportOptions.fileTag '_full.csv'];
          else
            fileName = [obj.exportFolder 'project_multiStatistics_' obj.params.exportOptions.fileTag '_full.csv'];
          end
      end
      
      fID = fopen(fileName, 'w');

      % List of additional columns
      additionalColumns = 0;
      switch obj.params.exportOptions.includeROI
        case {'yes', 'index'}
          additionalColumns = 1;
      end

      % Let's start with the headers
      %First the experiment Names
      lineStr = 'experiment';
      for it1 = 1:length(obj.experimentNames)
        curColumns = length(obj.groupList)*length(obj.featureList)*(1+additionalColumns);
        for it2 = 1:curColumns
          lineStr = sprintf('%s,"%s"', lineStr, obj.experimentNames{it1});
        end
      end
      lineStr = sprintf('%s\n', lineStr);
      fprintf(fID, lineStr);
      
      % Now the groups
      lineStr = 'group';
      for it1 = 1:length(obj.experimentNames)
        for it2 = 1:length(obj.groupList)
          for it3 = 1:(length(obj.featureList)*(1+additionalColumns))
            lineStr = sprintf('%s,"%s"', lineStr, obj.groupList{it2});
          end
        end
      end
      lineStr = sprintf('%s\n', lineStr);
      fprintf(fID, lineStr);
      
      % Now the features
      lineStr = 'statistic';
      for it1 = 1:length(obj.experimentNames)
        for it2 = 1:length(obj.groupList)
          switch obj.params.exportOptions.includeROI
            case 'yes'
              lineStr = sprintf('%s,"%s"', lineStr, 'ROI ID');
            case 'index'
              lineStr = sprintf('%s,"%s"', lineStr, 'ROI index');
          end
          for it3 = 1:(length(obj.featureList))
            lineStr = sprintf('%s,"%s"', lineStr, obj.featureList{it3});
          end
        end
      end
      lineStr = sprintf('%s\n', lineStr);
      fprintf(fID, lineStr);
      
      % Now we can plot the actual data - THIS IS A MESS - might need to change if the datasets become too big
      remainingGroups = length(obj.experimentNames)*length(obj.groupList)*length(obj.featureList);
      curMember = 0;
      curFormat = obj.params.exportOptions.dataFormat;
      while(remainingGroups > 0)
        lineStr = '';
        remainingGroups = length(obj.experimentNames)*length(obj.groupList)*length(obj.featureList);
        curMember = curMember + 1;
        for it1 = 1:length(obj.experimentNames)
          for it2 = 1:length(obj.groupList)
            for it3 = 1:(length(obj.featureList))
              if(length(obj.fullData{it1}{it2}{it3}) < curMember)
                remainingGroups = remainingGroups - 1;
                switch obj.params.exportOptions.includeROI
                  case {'yes', 'index'}
                    lineStr = sprintf('%s,""', lineStr);
                end
                lineStr = sprintf('%s,""', lineStr);
              else
                curData = obj.fullData{it1}{it2}{it3}(curMember);
                switch obj.params.exportOptions.includeROI
                  case 'yes'
                    if(iscell(obj.fullDataID{it1}{it2}{it3}))
                      lineStr = sprintf('%s,"%s"', lineStr, obj.fullDataID{it1}{it2}{it3}{curMember});
                    else
                      lineStr = sprintf('%s,"%d"', lineStr, obj.fullDataID{it1}{it2}{it3}(curMember));
                    end
                  case 'index'
                    lineStr = sprintf('%s,"%d"', lineStr, obj.fullDataMember{it1}{it2}{it3}(curMember));
                end
                if(obj.params.exportOptions.NaNtoBlank && isnan(curData))
                  lineStr = sprintf('%s,""', lineStr);
                else
                  lineStr = sprintf(['%s,"' curFormat ' "'], lineStr, curData);
                end
              end
            end
          end
        end
        lineStr = sprintf('%s\n', lineStr);
        fprintf(fID, lineStr);
      end
    fclose(fID);
    end
  end
end