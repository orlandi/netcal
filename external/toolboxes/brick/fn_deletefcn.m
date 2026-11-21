function fn_deletefcn(hu,deletefcn)
% function fn_deletefcn(hu,deletefcn)
%---
% Set the 'DeleteFcn' property of a graphic object in such a way that
% several functions can be executed upon its deletion.

% Thomas Deneux
% Copyright 2015-2017

if ishandle(hu)
    
    if isappdata(hu,'fn_deletefcn')
        funset = getappdata(hu,'fn_deletefcn');
    else
        funset = {};
    end
    
    % set the 'DeleteFcn' property to call fn_deletefcn
    fun = get(hu,'deletefcn');
    if ~isa(fun,'function_handle') || ~strcmp(func2str(fun),'@(hu,evnt)deleteexec(hu,evnt)')
        if ~isempty(fun)
            funset = [{fun} funset];
        end
        set(hu,'deletefcn',@(hu,evnt)deleteexec(hu,evnt))
    end
    
    % add the new delete function to the set (on top)
    funset = [{deletefcn} funset];
    setappdata(hu,'fn_deletefcn',funset)

elseif isobject(hu)
    
    addlistener(hu,'ObjectBeingDestroyed',deletefcn);
    
else
    
    error 'hu must be a handle object'
    
end

%---
function deleteexec(hu,evnt)


if isappdata(hu,'fn_deletefcn')
    funset = getappdata(hu,'fn_deletefcn');
else
    funset = {};
end

for i=1:length(funset)
    fn_evalcallback(funset{i},hu,evnt)
end
