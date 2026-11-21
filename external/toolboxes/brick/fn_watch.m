function c = fn_watch(hf,varargin)
% function c = fn_watch([hf])

% Thomas Deneux
% Copyright 2012-2017

if nargin==0, hf = gcf; end

if nargout==0
    % Old syntax, does not use an onClean object and requires manual
    % stopping
    if fn_dodebug, warning 'syntax for fn_watch function has changed!', end
    if nargin<2 || ismember(varargin{1},{'start' 'startnow'})
        startfcn(hf)
    elseif strcmp(varargin{1},'stop')
        stopfcn(hf,[],'arrow')
    else
        error 'argument'
    end
    return
end

curpointer = get(hf,'Pointer');
if eval('true')
    t = maketimer(hf);
    if ~strcmp(get(t,'Running'),'on'), start(t), end
else
    startfcn(hf)
    t = [];
end
c = onCleanup(@()stopfcn(hf,t,curpointer));

function t = maketimer(hf)

% timer is stored in figure to avoid loosing time creating it multiple
% times
t = getappdata(hf,'fn_watch_timer');
if isempty(t)
    t = timer('StartDelay',.3,'TimerFcn',@(u,e)startfcn(hf));
    setappdata(hf,'fn_watch_timer',t)
    if fn_matlabversion('newgraphics')
        % will not work with Matlab version previous to R2014b and timer will not be deleted
        addlistener(hf,'ObjectBeingDestroyed',@(u,e)delete(t));
    end 
end

function startfcn(hf)

set(hf,'Pointer','watch')
drawnow

function stopfcn(hf,t,curpointer)

if ~isempty(t), stop(t), end
set(hf,'Pointer',curpointer)


