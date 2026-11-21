
% List files in brick folder
fn_cd brick
mfiles = fn_ls('*.m');
mfiles = setdiff(mfiles, ...
    {'Contents.m' 'fn_dodebug.m' 'interface_template.m'});

% go!
fn_progress('file',length(mfiles))
for i=1:length(mfiles)
    fn_progress(i)
    txt = fn_readtext(mfiles{i});
    mod = false;
    % get the indent of the help
    indent = fn_regexptokens(txt{2},'^( *)%');
    if iscell(indent), indent = fn_regexptokens(txt{1},'^( *)%'); end % look for indent on the first line, in case the file is a script rather than a function
    if iscell(indent)
        warning('file ''%s'' has no help!',mfiles{i})
        edit(mfiles{i})
        continue
    end
    % go to first non-comment line
    for j=2:length(txt)
        str = txt{j};
        if isempty(regexp(str,'^ *%', 'once')), break, end
    end
    % are we now on an empty line?
    if ~all(txt{j}==' ')
        txt = [txt(1:j-1); {''}; txt(j:end)];
    end
    % is there already a copyright information?
    j = j+1; jcopyright = j; % mark the line where copyright info should be written
    for j=j:length(txt), if regexp(txt{j},'^ *% Thomas Deneux *$'), break, end, end
    if j==length(txt)
        % no Copyright info was found, add it
        j = jcopyright;
        txt = [txt(1:j-1); [indent '% Thomas Deneux']; [indent '% Copyright 2015-2017']; {''}; txt(j:end)];
        mod = true;
    else
        if j>jcopyright
            warning('Copyright info appears low in file ''%s''',mfiles{i})
        end
        % check the second date
        j = j+1; str = txt{j};
        date2 = fn_regexptokens(str,'^ *% Copyright \d{4}(-\d{4}){0,1} *$');
        if iscell(date2) && isempty(date2)
            warning('could not read Copyright in file ''%s''',mfiles{i})
            continue
        elseif isempty(date2)
            % a single date!
            txt{j} = regexprep(str,'^( *% Copyright \d{4}) *$','$1-2017');
            mod = true;
        elseif ~strcmp(date2,'-2017')
            % 
            txt{j} = regexprep(str,'^( *% Copyright \d{4})(-\d{4}) *$','$1-2017');
            mod = true;
        else
            % everything seems correct, but check that there are no other Copyright info
            for j=j+1:length(txt)
                if strfind(txt{j},'Copyright')
                    warning('More than one Copyright info in file ''%s''',mfiles{i})
                    edit(mfiles{i})
                    break
                end
            end
        end
    end
    % need to save?
    if mod
        fn_savetext(txt,mfiles{i})
    end
end
