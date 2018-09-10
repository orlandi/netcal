% GETCASES        Return all cases handled by a switch structure
%
% When called inside a switch structure, C = GETCASES() will return a
% cellstring C which contains all cases handled by the switch structure.
% This can be useful to construct error messages, for example:
%
%     switch value
%         case 1
%             %...
%
%         case 2
%             %...
%
%         case 3
%             %...
%
%         otherwise
%             C = getCases; % == {'1' '2' '3'}
%             error(['Invalid option: ''%d''. ',...
%                    'Valid options are: ' C{:}], value);
%     end
%
% Normally, the list of all cases handled by the switch needs to be
% maintained in two different places -- at the cases themselves, and in
% the error message. When new cases are added, old ones are removed or
% changed, it is all too easy to forget that the error message(s) need to
% be updated as well. Especially for large switch structures that handle
% many cases and have many actions per case, this often leads to situations
% where the error message(s) list a different set of cases than are
% actually handled.
%
% GETCASES() automates this process by taking away the need to keep two
% separate yet identical lists. It simply traverses the current switch and
% collects all different cases it encounters, collecting all of them in a
% cellstring.
%
% C = GETCASES() will return a cell string C containing all the cases
% handled by the corresponding switch, as they are written in the code.
%
% C = GETCASES('eval') will return a cell string C containing all the
% cases handled by the corresponding switch, as they are seen by the
% switch.
%
% GETCASES('error') will issue a standard error listing all the valid
% cases, as shown in the example above. The cases will be listed as they
% are written in the code.
%
% GETCASES('eval', 'error') or GETCASES('error', 'eval') will do the same,
% except with the interpreted expressions (see 'eval' above). In all of
% these use cases, there is no return argument.
%
% GETCASES() may be called either from an ''otherwise'' block, or from a
% ''case'' field. In both cases, the complete list of cases is returned.
%
% GETCASES() will return an error message when it is called outside a
% switch structure.
%
% GETCASES() interprets M-code. That implies it cannot be used in MATLAB
% coder/Embedded MATLAB programs, or p-files.
%
% See also switch, case, otherwise, cellstr, regexp.


% Original idea by Mohsen Nosratinia; see the discussion on
% http://stackoverflow.com/questions/17325614/


% Please report bugs and inquiries to:
%
% Name       : Rody P.S. Oldenhuis
% E-mail     : oldenhuis@gmail.com
% Licence    : 2-clause BSD (See License.txt)


% Changelog
%{
2018/June
    Removed affiliation info & updated license

2017/September/08
    - Replaced the "builtin('_brace', ..." construct with a
      two-liner-temporary construct. This is to accomodate the removal of
      that undocumented functionality which was removed in R2015a.
    - Changed 'error' calls from error() to throwAsCaller(), to give
      a more intuitive error stack (excluding getCases() itself).

2013/November/08
	- Included credits to Mohsen (oops...)

2013/November/06
    - First version that passes all tests
    - Implemented 'error' and 'eval'

2013/July
    - Initial version
%}
function varargout = getCases(varargin)

    % If you find this work useful, please consider a donation:
    % https://www.paypal.me/Rodyo/3.5

    % First things first
    assert(nargin <= 2,...
           'Too many input arguments.');

    doEval  = false;
    doError = false;
    if nargin > 0

        assert(all(cellfun('isclass', varargin, 'char')),...
            'All input arguments to GETCASES must be of type ''char''.');

        doEval  = any(strcmpi(varargin, 'eval'));
        doError = any(strcmpi(varargin, 'error'));

        if doError && nargout ~= 0,...
                error([mfilename ':no_output'],...
                      'Too many output arguments');
        end
    end

    % Find the callsite
    stack = dbstack('-completenames');
    assert(numel(stack) >= 2,...
           [mfilename ':not_standalone'], [...
           'GETCASES() must be called inside a switch structure within a ',...
           'script or a function.']);

    fileName = stack(2).file;
    callsite = stack(2).line;
    clear stack

    % Load relevant code
    try
        fid = fopen(fileName);
        OC  = onCleanup(@() any(fid==fopen('all')) && fclose(fid));
    catch ME
        ME2 = MException([mfilename ':io_error'],...
                         'Could not open source file.');
        throw(addCause(ME2, ME));
    end

    assert(fid >= 0,...
           [mfilename ':io_error'],...
           'Could not open source file.');

    % Read all code
    try
        code = textscan(fid, '%s', 'Delimiter','\n');
        code = code{1};

        % Trim whitespace
        code = regexprep(code, '^\s*', '');     % Remove leading whitespace
        code = regexprep(code, '\s*$', '');     % Remove trailing whitespace

    catch ME
        fclose(fid);
        ME2 = MException([mfilename ':read_error'],...
                         'Could not read file.');
        throw(addCause(ME2, ME));
    end

    fclose(fid);
    clear fid filename

    % We're going to shrink the code a lot. The callsite is a line number,
    % which is hard to keep track of. This makes it easier:
    callsite = [false(callsite-1,1); true; false(numel(code)-callsite,1)];
    code = [code num2cell(callsite)];
    code = code(~cellfun('isempty', code(:,1)),:); % Remove empty lines
    clear callsite

    % Remove block comments
    blockComments = ~cellfun('isempty', regexp(code(:,1), '^%{\s*$'));
    if any(blockComments)

        blockStarts = find(blockComments);
        blockEnds   = find(~cellfun('isempty', regexp(code(:,1), '^%}\s*$')));

        for ii = numel(blockStarts):-1:1
            inds = blockStarts(ii) : blockEnds(find(blockEnds>blockStarts(ii),1,'first'));
            code(inds,:) = [];
        end

        clear blockEnds blockStarts inds ii
    end
    clear blockComments

    % Remove other comment lines
    code(:,1) = regexprep(code(:,1), '^%.*$', '');
    code      = code(~cellfun('isempty', code(:,1)),:);

    % Remove trailing comments
    % NOTE: we have to be careful not to delete percent signs
    % inside strings (like in sprintf statements etc.)
    %
    % NOTE: regex from Peter J. Acklam
    % http://www.mathworks.com/matlabcentral/fileexchange/4645-matlab-comment-stripping-toolbox
    %
    % See also the discussion on
    % http://stackoverflow.com/questions/17359425/how-to-remove-trailing-comments-via-regexp
    %
    code(:,1) = regexprep(code(:,1), ...
                          '((^|\n)(([\]\)}\w.]''+|[^''%])+|''[^''\n]*(''''[^''\n]*)*'')*)[^\n]*',...
                          '$1');

    % Recombine all continued lines
    continued = regexp(code(:,1), '\.\.\..*');
    if ~all(cellfun('isempty', continued))
        for ii = numel(continued):-1:1
            if ~isempty(continued{ii})
                code{ii,1} = [ code{ii,1}(1:continued{ii}-1) code{ii+1,1} ];
                code(ii+1,:) = [];
            end
        end
    end
    code = code(~cellfun('isempty', code(:,1)),:);
    clear continued

    % Remove any leading strings and other irrelevant code
    code(:,1) = regexprep(code(:,1), '^''.*('')\1*''[\s,;]*', '');
    code(:,1) = regexprep(code(:,1), '^''[^'']*''[\s,;]*', '');
    code(:,1) = regexprep(code(:,1), '^[\[\{]+.*[\]\}]+[\s,;]*', '');

    % Find all valid switch-block opening statements, and all 'end' keywords
    switchLines = findValidKeywords('switch\s');
    endLines    = findValidKeywords('end');

    if ~any(switchLines) || ...
       ~any(endLines) || ...
       find(switchLines,1,'first') > find([code{:,2}]) || ...
       find(endLines,1,'last')     < find([code{:,2}])

        error([mfilename ':not_in_switch'], [...
              'GETCASES() must be called from inside a ''switch'' control ',...
              'structure.']);
    end

    % Remove everything before the first 'switch' and after the last 'end'
    firstSwitch = find(switchLines, 1,'first');
    lastEnd     = find(endLines, 1,'last');
    keep        = firstSwitch:lastEnd;

    code        = code(keep,:);
    switchLines = switchLines(keep);
    endLines    = endLines(keep);

    clear firstSwitch lastEnd

    keep        = ~cellfun('isempty', code(:,1));
    code        = code(keep,:);
    switchLines = switchLines(keep);
    endLines    = endLines(keep);

    clear keep

    % Find all valid block-opening statements
    openBlock = {'for' 'while' 'try' 'if' 'function' 'spmd' 'parfor'};
    openLines = switchLines;
    for ii = 1:numel(openBlock)
        openLines = openLines + findValidKeywords(openBlock{ii}); end

    clear openBlock ii

    % Traverse the code from the callsite up, until the first unmatched
    % 'switch' is found. Also detect any nested control structures.
    closed    = 0;
    nestRange = {};
    unmatchedOpens = [];
    for line = find([code{:,2}])-1 : -1 : 1

        if endLines(line)
            if ~closed
                closeLine = line; end
            closed = closed + endLines(line);
        end

        if openLines(line)
            closed = closed - openLines(line);
            if closed == 0
                nestRange = [nestRange line:closeLine]; end  %#ok<AGROW>
        end

        if closed < 0
            % We found an unmatched start of a control structure.
            % If it is not a 'switch', save it for later
            if ~switchLines(line)
                closed = 0;
                unmatchedOpens = [unmatchedOpens line]; %#ok<AGROW>
                continue;

            % Otherwise, we've found our switch:
            else
                break;
            end
        end

    end

    % Invalid call site; repeat this error
    if closed >= 0
        error([mfilename ':not_in_switch'], [...
              'GETCASES() must be called from inside a ''switch'' ',...
              'control structure.']);
    end

    clear switchLines closed

    % Chop off all any nested structures thus found
    if ~isempty(nestRange)
        code     ([nestRange{:}],:) = [];
        openLines([nestRange{:}])   = [];
        endLines ([nestRange{:}])   = [];
    end

    % And chop off all code before the first non-matched 'switch'
    code      = code     (line:end,:);
    openLines = openLines(line:end);
    endLines  = endLines (line:end);

    % Find the corresponding non-matched 'end' after the callsite.
    % Also detect any nested control structures in the process
    opened = 0;
    nestRange = {};
    for line = find([code{:,2}])+1 : size(code,1)

        if openLines(line)
            if ~opened
                openLine = line; end
            opened = opened + openLines(line);
        end

        if endLines(line)
            opened = opened - endLines(line);
            if opened == 0
                nestRange = [nestRange openLine:line]; end  %#ok<AGROW>
        end

        if opened < 0
            % We've found an unmatched 'end'. Check if we have any leftover
            % unmatched opens from the previous loop
            if ~isempty(unmatchedOpens)
                nestRange = [nestRange unmatchedOpens(end):line]; %#ok<AGROW>
                unmatchedOpens(end) = [];
                opened = 0;
                continue;

            % If this is not the case, we've found the correct 'end'
            else
                break;
            end
        end

    end

    % Chop off all code after the corresponding 'end'. Also, we don't need
    % the callsite information anymore:
    code = code(1:line,1);
    clear opened line openLines endLines unmatchedOpens

    % And/or any nested structures thus found
    if ~isempty(nestRange)
        code([nestRange{:}]) = []; end

    clear nestRange

    % Fully shrunk code -- we should now have the essence of the switch we
    % were called from. Now its time to find the cases:

    cases = regexp(code(findValidKeywords('case\s')), 'case\s+', 'split');
    cases = cellfun(@(x)(char(x{2:end})), cases, 'UniformOutput', false);
    cases = cellstr(char(cases));
    cases = regexprep(cases, '\s*,*$', '');
    cases = regexprep(cases, '^\s+', '');

    % Evaluate all cases and/or issue error
    if doEval

        newCases = cases;
        success  = true;

        for ii = 1:numel(cases)
            newCases{ii} = evalin('caller', newCases{ii});

            if ischar(newCases{ii})
                continue;
            elseif isnumeric(newCases{ii}) || islogical(newCases{ii})
                newCases{ii} = num2str(newCases{ii});
            else
                warning([mfilename ':toString_more_complex'], [...
                        'A datatype that is not readily converted to ',...
                        'string was received. Not converting...']);
                success = false;
                break
            end
        end

        if success
            cases = newCases; end

        clear newCases success
    end

    if doError
        % Get the 'switch' value as well.
        switchValue = regexp(code{1}, '[,;\s]*switch\s+([{}[]()''\w]*)[,\s]*$', 'tokens');
        switchValue = switchValue{1};

        caseStr = cellfun(@(x)['''' regexprep(x,'%','%%') ''', '], ...
                          cases(1:end-1),...
                          'UniformOutput', false);
        caseStr = cat(2, caseStr{:}, ' and ''', cases{end}, '''.');

        % TODO: num2str() is not sufficient
        ME = MException([mfilename ':invalid_case'],...
                        ['Unhandled case: ''%s''.\nValid cases are ' caseStr], ...
                        num2str(evalin('caller', switchValue{1})));
        throwAsCaller(ME);
    end

    % All done!
    varargout{1} = cases;


    % Find valid keywords
    function valids = findValidKeywords(keyword)

        % Find all candidate lines in the code
        valids = ~cellfun('isempty', regexp(code(:,1), ['^.*' keyword]));

        % none might be found
        if any(valids)
            % check for invalid leading characters; remove when found
            valids(valids) = ...
                ~cellfun('isempty', regexp(code(valids,1), ['^.*[,;\s]+' keyword '[\s%,;]*((\.)\1\1)*'])) | ...
                ~cellfun('isempty', regexp(code(valids,1), ['^' keyword '[\s%,;]*((\.)\1\1)*']));
        end
    end

end
