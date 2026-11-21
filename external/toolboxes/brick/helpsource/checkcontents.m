
% Brick folder
brickfolder = fileparts(which('fn_add'));

% Functions in the brick folder
brickfun = fn_ls(fullfile(brickfolder,'*.m'));
brickfun = strrep(brickfun,'.m','');
hidefun = fn_strcut([ ...
    ... % Contents.m
    'Contents ' ...
    ... % Parent or low-level classes (cannot be put in 'private')
    'fn_uicontrol pixelposwatcher windowcallbackmanager memorypoolitem ' ...
    ... % Low-level and too specific
    'fn_review_showres interface_template ' ...
    'fn_autofigname fn_listedit ' ...
    'fn_meshclosestpoint fn_meshinv fn_meshnormals ' ...
    'fn_dodebug fn_figselection fn_chardisplay ' ...
    'fn_matlabversion fn_userconfig ' ...
    'graph fn_nextbutton ' ...
    ... % Should not be used any more
    'enableListener fn_deletefcn ' ...
    ... % Too 'private'
    'ff ' ...
    ... % Not clear yet whether these functions are too specific, or at least name should be changed
    'fn_isuniform memorypool fn_parametersets fn_readtextdata fn_singular fn_ticks fn_histocol ' ...
    ]);
removedfun = setdiff(hidefun,brickfun);
if ~isempty(removedfun)
    disp(['REMOVED FUNCTIONS (NO NEED TO HIDE): ' fn_strcat(removedfun,', ')])
end
brickfun = setdiff(brickfun,hidefun);

% Functions described in Contents.m
fcontent = fullfile(brickfolder,'Contents.m');
txt = fn_readtext(fcontent);
contentfun = regexp(txt,'(?<=%   [^-]*)\w*(?=.*-)','match');
contentfun = [contentfun{:}];

% Diff
removedfun = setdiff(contentfun,brickfun);
if ~isempty(removedfun)
    disp(['REMOVED FUNCTIONS: ' fn_strcat(removedfun,', ')])
end
nocontentfun = setdiff(brickfun,contentfun);
if ~isempty(nocontentfun)
    disp(['MISSING SUMMARY FOR: ' fn_strcat(nocontentfun,', ')])
end