classdef networkInferenceBase < handle
  % Base class to perform any network inference measure
  %
  %   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
  %
  %   See also networkInferenceOptions

  properties
    mainGroup;
    mode;
    params; % Set at init
    groupList;
    plotHandles;
    maxGroups;
    guiHandle;
    surrogates;
    globalConditioning;
    inferenceName;
  end
  
  methods
    % Use this function to do the actual inference
    %----------------------------------------------------------------------
    function [success, inferenceData, inferenceDataSurrogates, members] = infer(obj, inferFunc, normFunc, experiment, varargin)
      obj.surrogates = obj.params.surrogates;
      obj.globalConditioning = obj.params.globalConditioning;
      
      % Get ALL subgroups in case of parents
      if(strcmpi(obj.mainGroup, 'all') || strcmpi(obj.mainGroup, 'ask'))
        obj.groupList = getExperimentGroupsNames(experiment);
      else
        obj.groupList = getExperimentGroupsNames(experiment, obj.mainGroup);
      end
      % If ask, open the popup
      if(strcmpi(obj.mainGroup, 'ask'))
        [selection, ok] = listdlg('PromptString', 'Select groups to use', 'ListString', obj.groupList, 'SelectionMode', 'multiple');
        if(~ok)
          success = false;
          return;
        end
        obj.groupList = obj.groupList(selection);
      end
      
      % Will infer between members of all the groups
      members = [];
      for git = 1:length(obj.groupList)
        % Again, for compatibility reasons
        if(strcmpi(obj.groupList{git}, 'none'))
          obj.groupList{git} = 'everything';
        end
        members = [members, getExperimentGroupMembers(experiment, obj.groupList{git})];
      end
      members = unique(members);
      
      inferenceData = zeros(length(members), length(members));
      if(obj.surrogates.enable)
        Nsurrogates = obj.surrogates.amount;
        inferenceDataSurrogates = zeros(length(members), length(members), Nsurrogates);
      else
        Nsurrogates = 0;
        inferenceDataSurrogates = zeros(length(members), length(members));
      end
      % Create the asdf2 structure
      asdf2 = experimentToAsdf2(experiment);
      % Let's turn all rasters into a 2D array for slicing
      raster = zeros(asdf2.nbins, length(members));
      for i = 1:length(members)
        raster(asdf2.raster{members(i)}, i) = 1;
      end
      % Normalize data
      raster = feval(normFunc, raster, varargin{:});
      if(obj.params.pbar > 0)
        ncbar.setBarName(sprintf('Performing %s based inference', obj.inferenceName));
      end
      
      % The actual comparison - we will iterate thorugh all pairs in both directions. Might be overkill for symmetric measures, but since we are not sure how it will behave with the surrogates, better be safe than sorry
      % We will check for I->J interactions. Using the surrogates on I
      curIteration = 0;
      totalIterations = length(members)*(length(members)-1)*(Nsurrogates+1);
      for i = 1:length(members)
        if(sum(raster(:, i)) == 0)
          curIteration = curIteration + (length(members)-1)*(Nsurrogates+1);
          if(obj.params.pbar > 0)
            ncbar.update(curIteration/totalIterations);
          end
          continue;
        end
        Iorig = raster(:, i);
        if(~obj.surrogates.useAllAtOnce)
          for s = 0:Nsurrogates
            % s=0 is the original, not surrogate
            if(s == 0)
              I = Iorig;
            else
              % Generate the surrogate - still use the spike list
              I = obj.generateSurrogate(Iorig, asdf2.raster{members(i)}, obj.surrogates.type, obj.surrogates.jitterAmount);
              I = feval(normFunc, I, varargin{:});
            end
            inferenceDataCol = zeros(1, length(members));
            for j = 1:length(members)
              if(i == j)
                continue;
              end
              J = raster(:, j);
              % If there are no spikes, skip
              if(sum(J) == 0)
%                 curIteration = curIteration + 1;
%                 if(obj.params.pbar > 0)
%                   ncbar.update(curIteration/totalIterations);
%                 end
                continue;
              end
              
              % The actual computation
              inferenceDataCol(j) = feval(inferFunc, I, J, varargin{:});
            end
            curIteration = curIteration + length(members) - 1;
            if(s == 0)
              inferenceData(i, :) = inferenceDataCol;
            else
              inferenceDataSurrogates(i, :, s) = inferenceDataCol;
            end
            if(obj.params.pbar > 0)
              ncbar.update(curIteration/totalIterations);
            end
          end
        else
          fullSurrogates = zeros(length(Iorig), Nsurrogates+1);
          fullSurrogates(:, 1) = Iorig;
          % Generate all surrogates
          for s = 1:Nsurrogates
            fullSurrogates(:, s+1) = obj.generateSurrogate(Iorig, asdf2.raster{members(i)}, obj.surrogates.type, obj.surrogates.jitterAmount);
          end
          % Normalize them
          fullSurrogates = feval(normFunc, fullSurrogates, varargin{:});
          % Use them
         for j = 1:length(members)
            if(i == j)
              continue;
            end
            J = raster(:, j);
            if(sum(J) == 0)
              continue;
            end
            
            % The actual computation
            inferenceDataFullSurrogates = feval(inferFunc, fullSurrogates, J, varargin{:});
            inferenceData(i, j) = inferenceDataFullSurrogates(1);
            if(Nsurrogates > 0)
              inferenceDataSurrogates(i, j, :) = inferenceDataFullSurrogates(2:end);
            end
            curIteration = curIteration + 1 + Nsurrogates;
            if(obj.params.pbar > 0)
              ncbar.update(curIteration/totalIterations);
            end
          end
        end
      end
      success = true;
    end
    
    % The actual function to generate surrogates from a single spike train
    %----------------------------------------------------------------------
    function surrogateData = generateSurrogate(obj, data, spikes, type, jitterAmount)
      switch type
        case 'ISIconserved'
          ISI = diff(spikes);
          if(isempty(ISI) || all(isnan(ISI)))
            surrogateData = data;
            return;
          end
          done = false;
          curSpike = 0;
          surrogateData = zeros(size(data));
          while(~done)
            curSpike = curSpike + ISI(randperm(length(ISI), 1));
            if(curSpike  > 0 && curSpike < length(surrogateData))
              surrogateData(curSpike) = 1;
            else
              done = true;
            end
          end
        case 'poisson'
          surrogateData = data;
        case 'spikeCountConserved'
          surrogateData = data;
        case 'jitter'
          surrogateData = data;
      end
    end
      
    %----------------------------------------------------------------------
    function init(obj, optionsClass, msg, varargin)
      %--------------------------------------------------------------------
      [obj.params, var] = processFunctionStartup(optionsClass, varargin{:});
      % Define additional optional argument pairs
      obj.params.pbar = [];
      obj.params.gui = [];
      % Parse them
      obj.params = parse_pv_pairs(obj.params, var);
      obj.params = barStartup(obj.params, msg);
      obj.params = obj.params;
      obj.guiHandle = obj.params.gui;
      %--------------------------------------------------------------------

      % Fix in case for some reason the group is a cell
      if(iscell(obj.params.group))
        obj.mainGroup = obj.params.group{1};
      else
        obj.mainGroup = obj.params.group;
      end
      obj.inferenceName = msg;
    end
    
    %----------------------------------------------------------------------
    function cleanup(obj)
      barCleanup(obj.params);
    end
    
  end
end