function createhelpfiles(target)
% function createhelpfiles('all|funcbycat|allfunc|allmanual'|mfile)

% which files to create
if nargin==0, target = 'all'; end
dofuncbycat = fn_ismemberstr(target,{'all' 'funcbycat'});
domanual = strcmp(target,'allmanual');

% memorize current working directory
swd = pwd;

% Create autohelp folder if needed
fn_mkdir(fn_cd('brick','helpsource','autohelp'))

% All Functions by Category
if dofuncbycat, createhelp('funcbycat'), end

% m-files
switch target
    case {'all' 'allfunc'}
        %         mfiles = fn_ls(fn_cd('brick','*.m'));
        % functions described in Contents.m
        fcontent = fullfile(fn_cd('brick','Contents.m'));
        txt = fn_readtext(fcontent);
        contentfun = regexp(txt,'(?<=%   [^-]*)\w*(?=.*-)','match');
        contentfun = [contentfun{:}];
        mfiles = strcat(contentfun,'.m');
    case {'funcbycat' 'allmanual'}
        mfiles = {};
    otherwise
        mfiles = {[target '.m']};
end
for i=1:length(mfiles), createhelp(mfiles{i}), end

% Manual m-files
if domanual
    fn_cd('brick','helpsource','manualhelp')
    mfiles = fn_ls('help_*.m');
    for i=1:length(mfiles), createhelp(mfiles{i}), end
end

% restore working directory
cd(swd)

%---
function createhelp(target)

if strcmp(target,'funcbycat')
    ismanual = false;
    out = createhelp_funcbycat;
    targetm = 'helpfuncbycat.m';
elseif strfind(target,'help_')
    % manual help, publish only
    ismanual = true;
    disp(target)
    targetm = target;
else
    ismanual = false;
    out = createhelp_mfile(target);
    if isempty(out), return, end
    targetm = ['help_' target];
end
if ismanual
    fn_cd('brick','helpsource','manualhelp')
else
    fn_cd('brick','helpsource','autohelp')
    fn_savetext(out,targetm)
end
publishopt = struct('outputDir',fn_cd('brick','html'));
publish(targetm,publishopt);

%---
function out = createhelp_funcbycat

disp 'funcbycat'

% read Contents.m file
content = fn_readtext(fn_cd('brick','Contents.m'));

% first lines
out = { ...
    '%% Functions by Categories' ...
    ['% Brick Toolbox, ' content{2}(3:end)] ...
    '' ...
    };

% read
[insection insubsection] = deal(false);
for k=4:length(content)
    line = content{k};

    % opening a section
    if ~insection
        % finished?
        if k==length(content), break, end
        head = fn_regexptokens(line,'% (.*)');
        if ismember(head,{'RECOMMENDED' 'HIGHLIGHTS'}), break, end
        % open a new section (header + new table)
        out = [ out  ...
            ['%% ' head] ...
            '% <html>' ...
            ];
        insection = true;
        continue
    end
    
    % closing a subsection
    closesection = all(line(2:end)==' ');
    subhead = fn_regexptokens(line,'% - (.*)');
    if insubsection && (~isempty(subhead) || closesection)
        out = [out ...
            '% </table>' ...
            ];
    end
    
    % closing a section
    if closesection
        out = [ out ...
            '% </html>' ...
            {''} ...
            ];
        [insection insubsection] = deal(false);
        continue
    end
    
    % opening a subsection
    if ~isempty(subhead)
        out = [out ...
            ['% <b>' subhead '</b>'] ...
            '% <table cellspacing="0" width="100%" border="0" cellpadding="2" style="margin-top:5px;margin-bottom:30px;">' ...
            ];
        insubsection = true;
        continue
    end
    
    % items
    funs = regexp(line,'(?<=%   [^-]*)\w*(?=.*-)','match');
    for i=1:length(funs)
        funs{i} = ['<a href="help_' funs{i} '.html">' funs{i} '</a>'];
    end
    desc = fn_regexptokens(line,'- (.*)');
    out{end+1} = [ ...
        '% <tr valign="top">' ...
        '<td width="150">' fn_strcat(funs,', ') '</td>' ...
        '<td>' desc '</td>' ...
        '</tr>' ...
        ];
    
end

%---
function out = createhelp_mfile(mfile)

% file names
if strcmp(mfile,'Contents.m'), out = []; return, end
disp(mfile)

% read file
content = fn_readtext(mfile);

% get desc and copyright blocks
khelpend = 0;
syntax = {};
desc = {};
copyright = {};
for k=2:length(content)
    line = content{k};
    istart = find(line~=' ',1,'first');
    if isempty(istart) || line(istart)~='%'
        if k==2
            % try the first line (script?)
            line = content{1};
            if ~isempty(line) && line(1)=='%'
                desc = {line};
                khelpend = 1;
            else
                error('no help found for file ''%s''',mfile)
            end
        elseif ~khelpend
            khelpend = k;
        elseif k==khelpend+1
            error 'no copyright found'
        else
            break
        end
        continue
    else
        line = line(istart:end);
    end
    if ~khelpend && isempty(desc) && ~isempty(regexp(line,'^ *% *function', 'once'))
        syntax{end+1} = strrep(line,'function','');
    elseif ~khelpend
        if length(line)<2 || line(2)~='-' % avoid the '%---' line
            desc{end+1} = line;
        end
    else
        copyright{end+1} = line;
    end
end

% formatting syntax - no need for more formatting

% formatting description
for k=1:length(desc)
    line = desc{k};
    desc{k} = ['% ' line(2:end)]; % syntax for formatted block
end

% whole formatted help
out = {['%% ' fn_fileparts(mfile,'base')]};
if ~isempty(syntax)
    out = [out ...
        {''} ...
        '%% Syntax' ...
        syntax]; %#ok<*AGROW>
end
if ~isempty(desc)
    for k=1:length(syntax)
        line = syntax{k};
        istart = 1+find(line(2:end)~=' ',1,'first');
        syntax{k} = ['%  ' line(istart:end)]; %#ok<*SAGROW> % syntax for formatted block
    end
    out = [out ...
        {''} ...
        '%% Description' ...
        desc];
end
if ~isempty(copyright)
    [copyright{2,:}] = deal('%');
    out = [out ...
        {''} ...
        '%% Source' ...
        copyright(:)'];
end

