function closeVideoStream(stream)
% CLOSEVIDEOSTREAM closes the video stream
%
% USAGE:
%    closeVideoStream
%
% INPUT arguments:
%    stream - obtained from openVideoStream
%
% EXAMPLE:
%     closeVideoStream(stream)
%
% REFERENCES:
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
% See also: loadExperiment, openVideoStream

if(isempty(stream) || (isnumeric(stream) && stream == 137))
  return;
end

if(isa(stream,'VideoReader'))
  % Actually do nothing
elseif(~isempty(stream))
  for it = 1:length(stream)
    fclose(stream(it));
  end
end