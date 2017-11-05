function msg = logMsg(msg, varargin)
  if(nargin > 1 && ~isempty(varargin{1}) && ishandle(varargin{1}))
    logHandles = getappdata(varargin{1}, 'logHandle');
    for i = 1:length(logHandles)
      logMessage(logHandles(i), msg, varargin{2:end});
    end
  elseif(isempty(gcbf))
    logMessage([], msg, varargin);
  elseif(~isempty(gcf) && ~isempty(getappdata(gcf, 'logHandle')))
    logHandles = getappdata(gcf, 'logHandle');
    for i = 1:length(logHandles)
      logMessage(logHandles(i), msg, varargin);
    end
  else
    logHandles = getappdata(gcbf, 'logHandle');
    for i = 1:length(logHandles)
      logMessage(logHandles(i), msg, varargin);
    end
  end
end