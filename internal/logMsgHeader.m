function msg = logMsgHeader(msg, condition, varargin)
% LOGMSGHEADER Writes header (or footer) in the logMsg window
%
% USAGE:
%    logMsgHeader(msg, condition, gui)
%
% INPUT arguments:
%    msg - The actual message
%
%    condition - 'start'/'finish' Type of block
%
% EXAMPLE:
%    logMsgHeader('This is a message', 'start', gcf)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also logMsg
if(nargin < 3)
  gui = gcbf;
else
  gui = varargin{1};
end

switch condition
  case {'start', 'header'}
    logMsg('', gui);
    logMsg('----------------------------------', gui);
    logMsg([datestr(now, 'HH:MM:SS'), ' ', msg], gui, 't');
  case {'finish', 'footer'}
    logMsg([datestr(now, 'HH:MM:SS'), ' ', msg], gui, 't');
    logMsg('----------------------------------', gui);
end