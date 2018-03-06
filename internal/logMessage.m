function logMessage(jEditboxList, text, severity, varargin)
if(nargin >= 4)
  moveCaret = varargin{1};
else
  moveCaret = true;
end
try
  if(isempty(jEditboxList))
    if(iscell(text))
      cellfun(@(x)fprintf('%s\n', strrep(x,'<br/>',sprintf('\n'))), text);
    else
      fprintf('%s\n', strrep(text,'<br/>',sprintf('\n')));
    end
    return;
  end
  for it = 1:length(jEditboxList)
    jEditbox = jEditboxList(it);
    if(isempty(jEditbox))
      if(iscell(text))
        cellfun(@(x)fprintf('%s\n', strrep(x,'<br/>',sprintf('\n'))));
        else
        fprintf('%s\n', strrep(text,'<br/>',sprintf('\n')));
      end
      continue;
    end

    % Ensure we have an HTML-ready editbox
    HTMLclassname = 'javax.swing.text.html.HTMLEditorKit';
    if ~isa(jEditbox.getEditorKit,HTMLclassname)
      jEditbox.setContentType('text/html');
    end

    % Parse the severity and prepare the HTML message segment
    if(nargin < 3 || isempty(severity))
       severity = {'i'};
    end
    if(iscell(severity))
      severity = severity{1};
    end
    if(isempty(severity))
      severity = 'i';
    end

    switch(lower(severity(1)))
      case 'i',   color='black';
      case 'w',   color='blue';
      case 't',   color='black'; % Title
      otherwise,    color='red';beep;
    end

    if(~iscell(text) && strcmp(text, 'clear'))
      jEditbox.setText('');
      if(moveCaret)
        jEditbox.setCaretPosition(0);
      end
      continue;
    end
    endPosition = jEditbox.getDocument.getLength;
    if(endPosition == 0) 
      jEditbox.setText('<html><head></head><body></body></html>');
    end
    currentHTML = char(jEditbox.getText);
    
    if(iscell(text))
      fullText = [];
      for itt = 1:length(text)
        curLine = text{itt};
        if(strcmp(curLine, 'clear'))
          jEditbox.setText('');
          %if(moveCaret)
          jEditbox.setCaretPosition(0);
          %end
          endPosition = jEditbox.getDocument.getLength;
          if(endPosition == 0) 
            jEditbox.setText('<html><head></head><body></body></html>');
          end
          currentHTML = char(jEditbox.getText);
          fullText = [];
          continue;
        end
        if(length(text) > 5 && strcmp(curLine, '<tag>'))
          msgTxt = curLine(6:end);
        else
          msgTxt = ['<font size="4" color=',color,'>',curLine,'</font>'];
          if(strcmp(lower(severity(1)), 't'))
            msgTxt = ['<b>', msgTxt, '</b>'];
          end
        end
        msgTxt = [ msgTxt '<br />'];
        if(strncmp(curLine, '-----', 5))
          msgTxt = '<hr>';
        end
        fullText = [fullText, msgTxt];
      end
      msgTxt = fullText;
    else
      if(length(text) > 5 && strcmp(text, '<tag>'))
        msgTxt = text(6:end);
      else
        msgTxt = ['<font size="4" color=',color,'>',text,'</font>'];
        if(strcmp(lower(severity(1)), 't'))
          msgTxt = ['<b>', msgTxt, '</b>'];
        end
      end
      msgTxt = [ msgTxt '<br />'];
      if(strncmp(text, '-----', 5))
        msgTxt = '<hr>';
      end
    end
    % Place the HTML message segment at the bottom of the editbox
    jEditbox.setText(strrep(currentHTML,'</body>',msgTxt));
    endPosition = jEditbox.getDocument.getLength;
    if(moveCaret)
      jEditbox.setCaretPosition(endPosition); % end of content
    end
  end
catch ME
  logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
end
end