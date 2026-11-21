function helpText = generateAutomaticHelpFile(file, varargin)

  if(length(varargin) < 1)
    showHeader = true;
  else
    showHeader = varargin{1};
  end
  fID = fopen(file,'r');
  insideProps = false;
  %mdFile = sprintf('# Help\n');
  mdFile = '';
  block = {};
  while(~feof(fID))
    line = strrep(strtrim(fgetl(fID)),'"',''''); % There's a bug with ""
    if(~isempty(line))
      block{end+1} = strtrim(line);
    end
    if(~isempty(line) && ~feof(fID))
      continue;
    end
    % Look for the classdef block
    blockBody = [];

    for i = 1:length(block)
      if(~isempty(strfind(block{1}, 'classdef')))
        if(regexp(block{i},'[%]*'))
          if(length(block{i}) > 1 && ~isempty(strtrim(block{i}(2:end))))
            lineText = strtrim(block{i}(2:end));
            if(i == 2)
              splitText = strsplit(lineText);
              lineText = strjoin(splitText(2:end));
            else
              splitText = strsplit(lineText);
              %if(strcmpi(splitText{1}, 'Copyright') || (length(splitText) > 1 && strcmpi(strjoin(splitText(1:2)), 'See also')) || strcmpi(splitText{1}, 'Class'))
              if(strcmpi(splitText{1}, 'Copyright') || (length(splitText) > 1 && strcmpi(strjoin(splitText(1:2)), 'See also')))
                break;
              end
            end
            blockBody = [blockBody, sprintf('%s\n', lineText)];
          elseif(length(block{i}) == 1)
            blockBody = [blockBody, sprintf('\n')];
          end
        end
      end
    end
    if(~isempty(blockBody))
      if(showHeader)
        mdFile = [mdFile, sprintf('%s \n___\n', blockBody)];
      end
    end
    % Look for the first properties block
    for i = 1:length(block)
      if(strcmpi(block{i}, 'properties'))
        insideProps = true;
      end
      if(strcmpi(block{i}, 'methods'))
        % We are done
        fclose(fID);
        helpText = mdFile;
        return;
      end
    end
    % Do nothing until we are inside properties
    if(~insideProps)
      block = [];
      continue;
    end
    
    % Now find the first line inside the block with a header that
    % isn't properties to define a new header
    foundHeader = false;
    header = '';
    for i = 1:length(block)
      if(~foundHeader && isempty(strfind(block{i}, 'classdef')) && ~strcmpi(block{i}, 'properties') && isempty(regexp(block{i},'[%]*')))
        foundHeader = true;
        header = strsplit(block{i});
        header = strsplit(header{1}, '@');
        header = ['## ' header{1}];
      end
    end
    % Now that we have a header, turn all comments into text
    if(foundHeader)
      % First we do a pass to see if the block belongs to a struct (they need to be parsed differently)
      strFound = false;
      for i = 1:length(block)
        if(strfind(lower(block{i}), '= struct') | ~strfind(lower(block{i}), '=struct'))
          strFound = true;
        end
      end
      blockBody = [];
      if(strFound)
        for i = 1:length(block)
          if(regexp(block{i},'[%]*'))
            newLine = strsplit(strtrim(block{i}(2:end)));
            if(length(newLine) == 1 && strcmp(newLine{1}(end), ':'))
              % It;s a new header
              blockBody = [blockBody, sprintf('### %s\n',block{i}(2:end-1))];
            else
              blockBody = [blockBody, sprintf('%s\n',block{i}(2:end))];
            end
          end
        end
      else
        for i = 1:length(block)
          if(regexp(block{i},'[%]*'))
            blockBody = [blockBody, sprintf('%s\n',block{i}(2:end))];
          end
        end
      end
      
      
    end
    mdFile = [mdFile, sprintf('%s\n%s\n',header, blockBody)];
    block = [];
  end
  fclose(fID);
  helpText = mdFile;
end
