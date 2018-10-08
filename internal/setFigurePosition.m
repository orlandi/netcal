function pos = setFigurePosition(parent, varargin)
% SETFIGUREPOSITION Sets the default figure position relative to the parent
%
% USAGE:
%   pos = setFigurePosition(parent, varargin)
%
% INPUT arguments:
%   parent - handle to the parent figure (if any)
%
% INPUT optional arguments ('key' followed by its value):
%   width - figure width
%
%   height - figure height
%
% OUTPUT arguments:
%   pos - vector containing [left right width height] in pixels
%
% EXAMPLE:
%   pos = setFigurePosition(parent, 'width', 300, 'height', 200)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

params.width = 500;
params.height = 500;
params.centered = false;
params.useMultipleMonitors = false;
% Parse them
params = parse_pv_pairs(params, varargin);
if(ismac)
  BORDERSIZE = 150;
else
  BORDERSIZE = 50;
end
% Get absolute available area
monPos = get(0,'MonitorPositions');
currentMonitor = 1;
if(params.useMultipleMonitors)
  monMinX = min(monPos(:,1));
  monMaxX = max(monPos(:,1)+monPos(:,3)-1);
  monMinY = min(monPos(:,2));
  monMaxY = max(monPos(:,2)+monPos(:,4)-1);  
else
  if(isempty(parent))
    % If no parent, get current matlab monitor
    desktop = com.mathworks.mde.desk.MLDesktop.getInstance;
    desktopMainFrame = desktop.getMainFrame;
    % That +9 is so weird....
    mainX = desktopMainFrame.getLocation.x+9;
    mainY = desktopMainFrame.getLocation.y+9;
    if(mainX < 1)
      mainX = 1;
    end
    if(mainY < 1)
      mainY = 1;
    end
  else
    % If parent, get parent monitor
    pos = parent.Position;
    mainX = pos(1);
    mainY = pos(2);
  end
  currentMonitor = 1;
  if(size(monPos, 1) > 1)
    % If there's more than one monitor, check in which one we are
    for it = 1:(size(monPos, 1))
      if(mainX >= monPos(it, 1) && mainX < (monPos(it, 1)+monPos(it,3)) && mainY >= monPos(it, 2) && mainY < (monPos(it, 2)+monPos(it,4)))
        currentMonitor = it;
        break;
      end
    end
    monMinX = monPos(currentMonitor,1);
    monMaxX = monPos(currentMonitor,1)+monPos(currentMonitor,3)-1;
    monMinY = monPos(currentMonitor,2);
    monMaxY = monPos(currentMonitor,2)+monPos(currentMonitor,4)-1;
  else
    monMinX = min(monPos(:,1));
    monMaxX = max(monPos(:,1)+monPos(:,3)-1);
    monMinY = min(monPos(:,2));
    monMaxY = max(monPos(:,2)+monPos(:,4)-1);
  end
end

if(~isempty(parent) && ~params.centered)
  % Try to put the new figure to the right of the parent
  pos = [parent.Position(1)+parent.Position(3)+5, parent.Position(2), params.width, params.height];
  % If the figure is out of bounds try to put it on the left of the parent
  if(pos(1)+pos(3) > monMaxX || pos(2)+pos(4) > monMaxY || pos(1) < monMinX || pos(2) < monMinY)
    pos = [parent.Position(1)-params.width-5, parent.Position(2), params.width, params.height];
    % If it is still out of bounds, just put it on top of the parent
    if(pos(1)+pos(3) > monMaxX || pos(2)+pos(4) > monMaxY || pos(1) < monMinX || pos(2) < monMinY)
      pos = [parent.Position(1), parent.Position(2), params.width, params.height];
      % If it still doesn't fit, center it on the first monitor (add BORDERSIZE pixels for possible window borders)
      if(pos(1)+pos(3) + BORDERSIZE > monMaxX || pos(2)+pos(4) + BORDERSIZE > monMaxY || pos(1) < monMinX || pos(2) < monMinY)
        pos = [monPos(1,1)+round((monPos(1,3)-params.width)/2), monPos(1, 2)+round((monPos(1,4)-params.height)/2), params.width, params.height];
        % If it still doesn't fit, change width and height so it fits
        if(pos(1)+pos(3) + BORDERSIZE > monMaxX || pos(2)+pos(4) + BORDERSIZE > monMaxY || pos(1) < monMinX || pos(2) < monMinY)
          if(params.width > monPos(1,3))
            params.width = monPos(1,3)-BORDERSIZE;
          end
          if(params.height > monPos(1,4))
            params.height = monPos(1,4)-BORDERSIZE;
          end
          % If it still doesn't fit, you are pretty much screwed
          pos = [monPos(1,1)+round((monPos(1,3)-params.width)/2), monPos(1, 2)+round((monPos(1,4)-params.height)/2), params.width, params.height];
        end
      end
    end
  end
else
  % Center it on the current monitor
  %pos = [monPos(1,1)+round((monPos(1,3)-params.width)/2), monPos(1, 2)+round((monPos(1,4)-params.height)/2), params.width, params.height];
  pos = [monPos(currentMonitor,1)+round((monPos(currentMonitor,3)-params.width)/2), monPos(currentMonitor, 2)+round((monPos(currentMonitor,4)-params.height)/2), params.width, params.height];
  % If it still doesn't fit, change width and height so it fits
  if(pos(1)+pos(3) + BORDERSIZE > monMaxX || pos(2) + pos(4) + BORDERSIZE > monMaxY || pos(1) < monMinX || pos(2) < monMinY)
    if(params.width > monPos(1,3))
      params.width = monPos(1,3)-BORDERSIZE;
    end
    if(params.height > monPos(1,4))
      params.height = monPos(1,4)-BORDERSIZE;
    end
    % If it still doesn't fit, you are pretty much screwed
    pos = [monPos(1,1)+round((monPos(1,3)-params.width)/2), monPos(1, 2)+round((monPos(1,4)-params.height)/2), params.width, params.height];
  end
end
