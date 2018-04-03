classdef ncbar < handle
% NCBAR class for the sequential progressbar
%
% You initialize it passing as many arguments as bars, each argument the
% bar title.
% Then you update it with update(barIdx, fraction), barIdx from 1 to N, and
% ratio from 0 to 1.
% You close the bar with close() - it will report the elapsed time
% If you close the bar without calling close() it will throw an exception
% This bar is intended for sequential usage (althout it will also work with
% iterative loops)
%
% Modification of the progressbar by Steve Hoelzer
% https://www.mathworks.com/matlabcentral/fileexchange/6922-progressbar
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%

  % List of variles
  %----------------------------------------------------------------------
  properties (Access = private)
    numBars;
    barName;
    figHandle;
    lastUpdate;
    progData;
    startTime;
    barStartTime;
    initialFraction;
    currentBar;
    timerObj;
    automaticBar;
    timerIterator;
    ETA;
    height = 35;
    fullWidth = 800;
    fullHeight = 35;
    hpad = 10;
    vpad = 10;
    baseCmap;
    imgPath;
    title = 'Progress';
    defaultTitleStr = '%s (%s elapsed)'
  end
  
  methods (Static)
    % Make th aclass a singleton - so we can pass it around
    %----------------------------------------------------------------------
    function singleObj = getInstance
         persistent localObj
         if(isempty(localObj) || ~isvalid(localObj))
            localObj = ncbar;
         end
         singleObj = localObj;
      end

    % Constructor
    %----------------------------------------------------------------------
    function obj = ncbar(varargin)
      if(nargin > 0)
        obj = obj.initialize(varargin{:});
      end
    end
    
    % Initialize
    %----------------------------------------------------------------------
    function obj = initialize(varargin)
      obj = ncbar.getInstance();
      runningTimers = timerfind('TimerFcn', @TimerCircularScroll);
      if(~isempty(runningTimers))
        try
          stop(runningTimers);
          delete(runningTimers);
        catch
        end
      end
      obj.close();
      obj = ncbar.getInstance();
      obj.imgPath = fileparts(mfilename( 'fullpath' ));
      obj.imgPath = fullfile(obj.imgPath, 'images');
      imSize = zeros(33, 800-22, 3);
      skipRatio = 40/256;
      L = size(imSize, 2)/(1-skipRatio);
      cmap = parula(round(L));
      cmap = cmap((end-size(imSize, 2)+1):end, :);
      obj.baseCmap = cmap;
      obj.numBars = length(varargin);
      obj.automaticBar = false(obj.numBars, 1);
      obj.barName = varargin;
      obj.ETA = cell(obj.numBars, 1);
      obj.initializeFigure();
      obj.timerObj = timer('TimerFcn', @TimerCircularScroll, ...
                       'BusyMode', 'drop', 'ExecutionMode','FixedRate',...
                       'Period', 1);
      start(obj.timerObj);% Start timer.
    end
    
    % Initialize automatic
    %----------------------------------------------------------------------
    function obj = automatic(varargin)
      obj = ncbar.getInstance();
      runningTimers = timerfind('TimerFcn', @TimerCircularScroll);
      if(~isempty(runningTimers))
        try
          stop(runningTimers);
          delete(runningTimers);
        catch
        end
      end
      obj.close();
      obj = ncbar.getInstance();
      
      obj.imgPath = fileparts(mfilename( 'fullpath' ));
      obj.imgPath = fullfile(obj.imgPath, 'images');
      imSize = zeros(33, 800-22, 3);
      skipRatio = 40/256;
      L = size(imSize, 2)/(1-skipRatio);
      cmap = parula(round(L));
      cmap = cmap((end-size(imSize, 2)+1):end, :);
      obj.baseCmap = cmap;
      obj.numBars = length(varargin);
      obj.automaticBar = false(obj.numBars, 1);
      obj.barName = varargin;
      obj.ETA = cell(obj.numBars, 1);
      for i = 1:obj.numBars
        %obj.setAutomaticBar(i);
        obj.automaticBar(i) = true;
      end
      obj.initializeFigure();
      obj.timerObj = timer('TimerFcn', @TimerCircularScroll, ...
                       'BusyMode', 'drop', 'ExecutionMode','FixedRate',...
                       'Period', 1);
      start(obj.timerObj);% Start timer.
      %obj.defaultTitleStr = '%s';
      obj.defaultTitleStr = '%s (%s elapsed)';
      obj.automaticBar = true(obj.numBars, 1);
      
    end
    % Initialize figure
    %----------------------------------------------------------------------
    function obj = initializeFigure()
      obj = ncbar.getInstance();
      
      % Adjust figure size and axes padding for number of bars
      obj.fullHeight = (obj.height + obj.vpad) * obj.numBars + obj.vpad;
    
      pos = setFigurePosition([], 'width', obj.fullWidth, 'height', obj.fullHeight, 'centered', true);
      left = pos(1);
      bottom = pos(2);
      fullWidth = pos(3);
      fullHeight = pos(4);
      obj.figHandle = figure(...
        'Units', 'pixels',...
        'Position', [left bottom fullWidth fullHeight],...
        'NumberTitle', 'off',...
        'Resize', 'off',...
        'Name', obj.title, ...
        'MenuBar', 'none');
      figure(obj.figHandle);
      WinOnTop(obj.figHandle);
      % Initialize axes, patch, and text for each bar
      left = obj.hpad;

      for ndx = 1:obj.numBars
        % Create axes, patch, and text
        bottom = obj.vpad + (obj.vpad + obj.height) * (obj.numBars - ndx);

        if(obj.automaticBar(ndx))
          fileName = 'loopFile.gif';
        else
          fileName = 'loopFileEmpty.gif';
        end
        
        textMsgHtml = '<table border=0 cellspacing=3 cellpadding=0 width="100%%"><tr><td><font size="5" style="font-family:Times New Roman, Georgia, Serif">%s</font></td><td align="right"><font size="5" style="font-family:Times New Roman, Georgia, Serif">%s&nbsp;</font></td></tr>';
        
        textMsg = sprintf(textMsgHtml, obj.barName{ndx}, '');
        if(ismac || isunix)
          fileSrc = 'file://';
        else
          fileSrc = 'file:/';
        end
          gif = ['<html><table border=0 cellspacing=0 cellpadding=0><tr><td></td>'...
                '<td rowspan=2>'...
                '<img src="' fileSrc obj.imgPath, filesep, fileName '"/></td></tr>'...
                '<tr><td colspan=2>' textMsg '</td></tr></table></body></html>'];
              

        gifSize  = [778, 33];
        borderSize = 0;
        backColor = [1 1 1];
        cd = ones(gifSize(2),gifSize(1),3);

        for i = 1:3
          if(obj.automaticBar(ndx))
            cd(:, :, i) = backColor(i);
          else
            cd(:, :, :) = 1;
          end
        end
        % Make corners black
        cd(1, 1:end, :) = 0;
        cd(end, 1:end, :) = 0;
        cd(1:end, 1, :) = 0;
        cd(1:end, end, :) = 0;
        
        obj.progData(ndx).control = uicontrol(obj.figHandle, 'style','push', 'pos',[left+1 bottom+1 gifSize(1)+borderSize gifSize(2)+borderSize], 'String' ,gif, 'enable', 'inactive', 'CData', cd);
        obj.progData(ndx).currentFraction = 0;
        % Set starting time reference
        obj.barStartTime{ndx} = clock;
      end
      obj.startTime = clock;
      obj.figHandle.ResizeFcn = @resizeBar;
      obj.currentBar = 1;
    end
  
    % Consistency check so the bar exists and has been initialized
    %----------------------------------------------------------------------
    function handleCheck()
      obj = ncbar.getInstance();
      % Check that the handle exists
      if(~ishandle(obj.figHandle))
        ME = MException('NCBAR:closed', ...
                        'Aborted. Progress bar manually closed');
        throwAsCaller(ME);
      end
    end
    
    % Set automatic bar
    %----------------------------------------------------------------------
    function obj = setAutomaticBar(varargin)
      obj = ncbar.getInstance();
      if(length(varargin) >= 2)
        idx = varargin{1};
        obj.barName{idx} = varargin{2};
      elseif(length(varargin) == 1)
        idx = varargin{1};
      elseif(isempty(varargin))
        idx = obj.currentBar;
      end
      if(isempty(idx))
        idx = 1;
      end
      %obj.defaultTitleStr = '%s';
      obj.defaultTitleStr = '%s (%s elapsed)';
      obj.automaticBar(idx) = true;
      obj.update(0, idx);
    end
    
    % Change current bar name
    %----------------------------------------------------------------------
    function obj = setCurrentBarName(msg)
      obj = ncbar.getInstance();
      obj.defaultTitleStr = '%s (%s elapsed)';
      if(isempty(obj.currentBar))
        obj.currentBar = 1;
      end
      obj.barName{obj.currentBar} = msg;
      obj.update('force');
    end
    
    % Compatibility reasons
    %----------------------------------------------------------------------
    function obj = setBarName(msg)
      obj = ncbar.getInstance();
      obj.setCurrentBarName(msg);
    end
    
    % Unset automatic bar
    %----------------------------------------------------------------------
    function obj = unsetAutomaticBar(varargin)
      obj = ncbar.getInstance();
      if(nargin == 0)
        idx = obj.currentBar;
      else
        idx = varargin{1};
      end
      obj.automaticBar(idx) = false;
      obj.defaultTitleStr = '%s (%s elapsed)';
      obj.update(0, idx);
    end
    
    % Compatibility dummy functions
    %----------------------------------------------------------------------
    function setSequentialBar(varargin)

    end
    
    function  unsetSequentialBar(varargin)

    end
    
    % Increase bar index
    %----------------------------------------------------------------------
    function increaseCurrentBar()
      obj = ncbar.getInstance();
      if(obj.currentBar < length(obj.barName))
        obj.currentBar = obj.currentBar + 1;
      end
    end
    
    % Decrease bar index
    %----------------------------------------------------------------------
    function decreaseCurrentBar()
      obj = ncbar.getInstance();
      if(obj.currentBar > 1)
        obj.currentBar = obj.currentBar - 1;
      end
    end
    
    % Number of bars
    %----------------------------------------------------------------------
    function ret = getNumberBars()
      obj = ncbar.getInstance();
      ret = length(obj.barName);
    end
    
    % Check it its automatic
    %----------------------------------------------------------------------
    function ret = isAutomaticBar()
      obj = ncbar.getInstance();
      if(obj.automaticBar(obj.currentBar))
        ret = true;
      else
        ret = false;
      end
    end
    
    % Update bar
    %----------------------------------------------------------------------
    function obj = update(varargin)
      obj = ncbar.getInstance();
      obj.handleCheck();
      
      % update(x) - update current bar to x fraction
      % update(x, id) - update bar id to x fraction
      % update(x, 'force') - force update current bar to x fraction
      % update(x, id, 'force') - update bar id to x fraction
      % Check for force option
      if(strcmp(varargin{end}, 'force'))
        force = true;
        varargin(end) = [];
      else
        force = false;
      end
      if(isempty(obj.currentBar))
        obj.currentBar = 1;
      end
      
      if(isempty(varargin))
        try
          if(length(obj.progData) >= obj.currentBar)
            fraction = obj.progData(obj.currentBar).currentFraction;
          else
            fraction = 0;
          end
        catch
          fraction = 0;
        end
      else
        fraction = varargin{1};
      end
      % Check the bar that needs updating
      if(length(varargin) < 2)
        curBar = obj.currentBar;
      else
        curBar = varargin{2};
      end
      
      % Sanity checks
      if(fraction < 0)
        fraction = 0;
      elseif(fraction > 1)
        fraction = 1;
      end
      % If the fraction is either 0 and 1, force update
      if(~isempty(fraction) && (fraction == 0 || fraction == 1))
        force = true;
      end

      % Now we can update the current bar
      ndx = curBar;
      % Check if we need updating - at least 1% change
      %if(~force && abs(fraction-obj.progData(ndx).currentFraction) < 0.005)
      if(~force && abs(fraction-obj.progData(ndx).currentFraction) < 0.0005)
        return;
      end
      if(fraction == 0)
        obj.barStartTime{ndx} = clock;
      end
      if(~iscell(obj.barStartTime))
        if(isempty(ndx))
          ndx = 1;
        end
        obj.barStartTime = cell(ndx, 1);
        obj.barStartTime{ndx} = 0;
      end
      if(obj.barStartTime{ndx} == 0)
        obj.barStartTime{ndx} = clock;
      end
      %elapsedTime = obj.sec2timestr(etime(clock, obj.barStartTime{ndx}));
      elapsedTime = etime(clock, obj.barStartTime{ndx});
      timeLeft = elapsedTime / (fraction) - elapsedTime;
      obj.ETA{ndx} = datetime(clock) + seconds(timeLeft);
      
      if(obj.automaticBar(ndx))
        fileName = 'loopFile.gif';
      else
        fileName = 'loopFileEmpty.gif';
      end
      textMsgHtml = '<table border=0 cellspacing=3 cellpadding=0 width="100%%"><tr><td><font size="5" style="font-family:Times New Roman, Georgia, Serif">%s %s</font></td><td align="right"><font size="5" style="font-family:Times New Roman, Georgia, Serif">%s&nbsp;</font></td></tr>';
      if(obj.automaticBar(ndx) || fraction == 0)
        textMsg = sprintf(textMsgHtml, obj.barName{ndx}, '','');
      else
        textMsg = sprintf(textMsgHtml, obj.barName{ndx}, sprintf('(%s left)', obj.sec2timestr(timeLeft)), sprintf('%d%%', round(fraction*100)));
      end
      if(ismac || isunix)
        fileSrc = 'file://';
      else
        fileSrc = 'file:/';
      end
       gif = ['<html><table border=0 cellspacing=0 cellpadding=0><tr><td></td>'...
              '<td rowspan=2>'...
              '<img src="' fileSrc obj.imgPath, filesep, fileName '"/></td></tr>'...
              '<tr><td colspan=2>' textMsg '</td></tr></table></body></html>'];

      gifSize  = [778, 33];
      backColor = [1 1 1];
      cd = ones(gifSize(2),gifSize(1),3);
      cdmap = obj.baseCmap;
      for i = 1:3
        if(obj.automaticBar(ndx))
          cd(:, :, i) = backColor(i);
        else
          cd(:, :, i) = repmat(cdmap(:,i), [1 size(cd,1)])';

          if(round(fraction*gifSize(1)) > 0 && round(fraction*gifSize(1)) < gifSize(1))
            cd(:, round(fraction*gifSize(1)):end,:) = 1;
            cd(:, round(fraction*gifSize(1)),:) = 0;
          elseif(round(fraction*gifSize(1)) == 0)
            cd(:, :, :) = 1;
          end
        end
      end
      % Make corners black
      cd(1, 1:end, :) = 0;
      cd(end, 1:end, :) = 0;
      cd(1:end, 1, :) = 0;
      cd(1:end, end, :) = 0;
        
      obj.progData(ndx).control.String = gif;
      obj.progData(ndx).control.CData = cd;
      obj.progData(ndx).currentFraction = fraction;
            
      totalTime = obj.sec2timestr(etime(clock, obj.startTime));
      if(length(strfind(obj.defaultTitleStr,'%s')) == 2)
        titleStr = sprintf(obj.defaultTitleStr, obj.title, totalTime);
      else
        titleStr = sprintf(obj.defaultTitleStr, obj.title);
      end
      obj.figHandle.Name = titleStr;
      drawnow;
    end
    
    % For compatibility reasons
    %----------------------------------------------------------------------
    function obj = setCurrentBar(idx)
      obj = ncbar.getInstance();
      obj.setActiveBar(idx);
    end
    
    % Set active bar (active = current)
    %----------------------------------------------------------------------
    function obj = setActiveBar(idx)
      obj = ncbar.getInstance();
      obj.currentBar = idx;
    end
    
    % Set clean active bar (active = current, will reset timers and counters and stop any automatic)
    %----------------------------------------------------------------------
    function obj = setCleanActiveBar(varargin)
      obj = ncbar.getInstance();
      if(nargin == 0)
        idx = obj.currentBar;
      else
        idx = varargin{1};
      end
      obj.currentBar = idx;
      obj.progData(idx).currentFraction = 0;
      obj.unsetAutomaticBar(idx);
      obj.barStartTime{idx} = clock;
    end
    
    % Change bar title
    %----------------------------------------------------------------------
    function obj = setBarTitle(varargin)
      obj = ncbar.getInstance();
      if(length(varargin) == 1)
        idx = obj.currentBar;
      else
        idx = varargin{2};
      end
      
      obj.barName{idx} = varargin{1};
      obj.update('force');
    end
    
    % Close
    %----------------------------------------------------------------------
    function totalTime = close()
      obj = ncbar.getInstance();
      if(~isempty(obj.figHandle) && isvalid(obj.figHandle))
        close(obj.figHandle);
        totalTime = obj.sec2timestr(etime(clock, obj.startTime));
      else
        totalTime = NaN;
      end
      delete(obj);
    end
    
    %----------------------------------------------------------------------
    function timestr = sec2timestr(sec)
      % Convert a time measurement from seconds into a human readable string.
      % Convert seconds to other units
      w = floor(sec/604800); % Weeks
      sec = sec - w*604800;
      d = floor(sec/86400); % Days
      sec = sec - d*86400;
      h = floor(sec/3600); % Hours
      sec = sec - h*3600;
      m = floor(sec/60); % Minutes
      sec = sec - m*60;
      s = floor(sec); % Seconds

      % Create time string
      if w > 0
        if w > 9
          timestr = sprintf('%d week', w);
        else
          timestr = sprintf('%d week, %d day', w, d);
        end
      elseif d > 0
        if d > 9
          timestr = sprintf('%d day', d);
        else
          timestr = sprintf('%d day, %d hr', d, h);
        end
      elseif h > 0
        if h > 9
          timestr = sprintf('%d hr', h);
        else
          timestr = sprintf('%d hr, %d min', h, m);
        end
      elseif m > 0
        if m > 9
          timestr = sprintf('%d min', m);
        else
          timestr = sprintf('%d min, %d sec', m, s);
        end
      else
        timestr = sprintf('%d sec', s);
      end
    end
  end
end

function resizeBar(hObject, ~)
  obj = ncbar.getInstance();
  obj.handleCheck();
  % Adjust figure size and axes padding for number of bars
  pos = hObject.Position;
  obj.fullWidth = pos(3);
  obj.fullHeight = pos(4);
  %nheight = max(min([obj.height, (obj.fullHeight-obj.vpad*(obj.numBars+1))/obj.numBars]),15);
  nheight = max((obj.fullHeight-obj.vpad*(obj.numBars+1))/obj.numBars,15);
  
  % Initialize axes, patch, and text for each bar
  left = obj.hpad;
  width = obj.fullWidth - 2*obj.hpad;

  for ndx = 1:obj.numBars
  end
end

% Timer to update every second
%----------------------------------------------------------------------
function TimerCircularScroll(hObject, ~)
  obj = ncbar.getInstance();
  obj.handleCheck();
  try
    totalTime = obj.sec2timestr(etime(clock, obj.startTime));
    if(length(strfind(obj.defaultTitleStr,'%s')) == 2)
      titleStr = sprintf(obj.defaultTitleStr, obj.title, totalTime);
    else
      titleStr = sprintf(obj.defaultTitleStr, obj.title);
    end
    obj.figHandle.Name = titleStr;
    drawnow;
  catch
    stop(hObject);
    delete(hObject);
    %wait(1);
    %delete(timerfind('TimerFcn', @TimerCircularScroll));
    %wait(1);
  end
end