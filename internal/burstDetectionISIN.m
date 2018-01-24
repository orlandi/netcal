function experiment = burstDetectionISIN(experiment, varargin)
% BURSTDETECTIONISIN See: https://doi.org/10.3389/fncom.2013.00193
%
% USAGE:
%    experiment = burstDetectionISIN(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: burstDetectionISINoptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = burstDetectionISIN(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: ISI_N burst detection
% parentGroups: spikes: bursts
% optionsClass: burstDetectionISINoptions
% requiredFields: spikes, ROI, folder, name

[params, var] = processFunctionStartup(burstDetectionISINoptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Detecting bursts', true);
%--------------------------------------------------------------------------

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
    ncbar.setBarTitle(sprintf('Detecting bursts from group: %s', groupList{git}));
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
  
  experiment.spikes = cellfun(@(x)x(:)', experiment.spikes, 'UniformOutput', false);
  
  ar=[cellfun(@(x)x, experiment.spikes(members), 'UniformOutput', false)];
  %lr = cellfun(@(x)length(x), ar);
  %SpikeTimes = [ar{:}];
  SpikeTimes = [];
  SpikeIdx = [];
  for it = 1:length(ar)
    SpikeTimes = [SpikeTimes, ar{it}];
    SpikeIdx = [SpikeIdx, ones(size(ar{it}))*it];
  end
  mat = [SpikeTimes', SpikeIdx'];
  ar = sortrows(mat, 1);
  SpikeTimes = ar(:,1)';
  %SpikeTimes = SpikeTimes +(rand(size(SpikeTimes))-0.5)/experiment.fps;
  SpikeIdx = ar(:,2)';


  Spike.T = SpikeTimes;
  Spike.C = SpikeIdx;
  % So first channel is 0
  Spike.C = Spike.C - 1;
  N = params.N;
  ISI_N = params.ISI_N;
  
  % %% Find when the ISI_N burst condition is met
   % Look both directions from each spike
  dT = zeros(N,length(Spike.T))+inf;
  for j = 0:N-1
    dT(j+1,N:length(Spike.T)-(N-1)) = Spike.T( (N:end-(N-1))+j ) - ...
    Spike.T( (1:end-(N-1)*2)+j );
  end
  Criteria = zeros(size(Spike.T)); % Initialize to zero
  Criteria( min(dT)<=ISI_N ) = 1; % Spike passes condition if it is
  % included in a set of N spikes
  % with ISI_N <= threshold.
  % %% Assign burst numbers to each spike
  SpikeBurstNumber = zeros(size(Spike.T)) - 1; % Initialize to '-1'
  INBURST = 0; % In a burst (1) or not (0)
  NUM_ = 0; % Burst Number iterator
  NUMBER = -1; % Burst Number assigned
  BL = 0; % Burst Length
  for i = N:length(Spike.T)
    if INBURST == 0 % Was not in burst.
      if Criteria(i) % Criteria met, now in new burst.
        INBURST = 1; % Update.
        NUM_ = NUM_ + 1;
        NUMBER = NUM_;
        BL = 1;
      else % Still not in burst, continue.
      % continue %
      end
    else % Was in burst.
      if ~ Criteria(i) % Criteria no longer met.
        INBURST = 0; % Update.
        if BL<N % Erase if not big enough.
          SpikeBurstNumber(SpikeBurstNumber==NUMBER) = -1;
          NUM_ = NUM_ - 1;
        end
        NUMBER = -1;
      elseif diff(Spike.T([i-(N-1) i])) > ISI_N && BL >= N
      % This conditional statement is necessary to split apart
      % consecutive bursts that are not interspersed by a tonic spike
      % (i.e. Criteria == 0). Occasionally in this case, the second
      % burst has fewer than 'N' spikes and is therefore deleted in
      % the above conditional statement (i.e. 'if BL<N').
      %
      % Skip this if at the start of a new burst (i.e. 'BL>=N'
      % requirement).
      %
      NUM_ = NUM_ + 1; % New burst, update number.
      NUMBER = NUM_;
      BL = 1; % Reset burst length.
      else % Criteria still met.
        BL = BL + 1; % Update burst length.
      end
    end
    SpikeBurstNumber(i) = NUMBER; % Assign a burst number to
    % each spike.
  end
  % %% Assign Burst information
  MaxBurstNumber = max(SpikeBurstNumber);
  Burst.T_start = zeros(1,MaxBurstNumber); % Burst start time [sec]
  Burst.T_end = zeros(1,MaxBurstNumber); % Burst end time [sec]
  Burst.S = zeros(1,MaxBurstNumber); % Size (total spikes)
  Burst.C = zeros(1,MaxBurstNumber); % Size (total channels)
  for i = 1:MaxBurstNumber
    ID = find( SpikeBurstNumber==i );
    Burst.T_start(i) = Spike.T(ID(1));
    Burst.T_end(i) = Spike.T(ID(end));
    Burst.S(i) = length(ID);
    if isfield( Spike, 'C' )
      Burst.C(i) = length( unique(Spike.C(ID)) );
    end
  end
  % On our format
  burstList = struct;
  burstList.duration = Burst.T_end-Burst.T_start;
  burstList.amplitude = Burst.S;
  burstList.start = Burst.T_start;
  burstList.IBI = diff(Burst.T_start);
  burstList.channels = Burst.C;
  burstList.frames = round(Burst.T_start/experiment.fps):round(Burst.T_end/experiment.fps);
  if(params.plotResults)
    % Plot results
    figure, hold on;

    % Order y-axis channels by firing rates
    tmp = zeros( 1, max(Spike.C)-min(Spike.C) );
    for c = min(Spike.C):max(Spike.C)
      tmp(c-min(Spike.C)+1) = length( find(Spike.C==c) );
    end
    [tmp ID] = sort(tmp);
    if(params.reorderChannels)
      OrderedChannels = zeros( 1, max(Spike.C)-min(Spike.C) );
      for c = min(Spike.C):max(Spike.C)
        OrderedChannels(c-min(Spike.C)+1) = find( ID==c-min(Spike.C)+1 );
      end
      % Raster plot
      plot(Spike.T, OrderedChannels(1+Spike.C), 'k.');
      maxC = max(OrderedChannels)+1;
    else
      % Raster plot
      plot(Spike.T, 1+Spike.C, 'k.');
      maxC = max(Spike.C)+1;
    end
    
    %plot( Spike.T, OrderedChannels(Spike.C), 'k.' )
    % set( gca, 'ytick', (min(Spike.C):max(Spike.C))+1, 'yticklabel', ...
    % ID-min(ID)+min(Spike.C) ) % set yaxis to channel ID

    % Plot times when bursts were detected
    ID = find(Burst.T_end<max(Spike.T));
    Detected = [];
    for i=ID
      Detected = [ Detected Burst.T_start(i) Burst.T_end(i) NaN ];
      valid = find(Spike.T >= Burst.T_start(i) & Spike.T <= Burst.T_end(i));
      if(params.reorderChannels)
        plot(Spike.T(valid), OrderedChannels(1+Spike.C(valid)), 'b.');
      else
        plot(Spike.T(valid), 1+Spike.C(valid), 'b.');
      end
    end
    plot(Detected, maxC*ones(size(Detected)), 'r', 'linewidth', 14 )

    xlabel 'Time [sec]'
    ylabel 'Channel'
    box on;
    title(sprintf('ISI_N burst detection exploration for: %s - %s', groupName, experiment.name));
  end
  
  experiment.spikeBursts.(groupName){groupIdx} = burstList;

  logMsg(sprintf('%d bursts detected on group %s', length(burstList.start), groupList{git}));
  logMsg(sprintf('%.2f s mean duration', mean(burstList.duration)));
  logMsg(sprintf('%.2f mean maximum amplitude', mean(burstList.amplitude)));
  logMsg(sprintf('%.2f s mean IBI', mean(burstList.IBI)));
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end
