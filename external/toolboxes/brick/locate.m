function locate(f)
% function locate(f)
%---
% Reveal file or folder in Windows Explorer. f can also be the name of a
% Maltlab function on the path.

% Thomas Deneux
% Copyright 2015-2017

if exist(f,'dir')
    % folder
    cmd = ['!explorer "' f '"'];
else
    % file
    if ~exist(f,'file')
        f = which(f);
    end
    cmd = ['!explorer /select,"' f '"'];
end
disp(cmd)
eval(cmd)
