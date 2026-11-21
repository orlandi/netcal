function self = newMarkdownPanel24(parent, content)

 % Create a java control because the builtin editbox doesn't easily return the current value
  h = content; 
  je = javax.swing.JEditorPane('text', h);
  jp = javax.swing.JScrollPane(je);
  originalWarnings = warning();
  warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved');
  [~, hcomp] = javacomponent(jp, [0 0 1 1], parent);
%  set(hcomp, 'Position', [0 0 0.5 1])
  gap = 0.025;
  set(hcomp, 'Units', 'norm', 'position', [gap, gap, 1-2*gap, 1-2*gap])

  warning(originalWarnings);
  % Construct the MarkdownPanel object
  twitter = 'https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css';
  %self = struct;
  panel = MarkdownPanel( ...
      'Content',      h, ...
      'Parent',       parent, ...
      'StyleSheets',  twitter, ...
      'Classes',      'container');
  % Set the option to enable smooth live previews
  self = hcomp;
  %self.htmlComponent = panel.htmlComponent;
  %self.jbrowser = panel.jbrowser;
  panel.Options.smoothLivePreview = true;
  % Setup a timer to refresh the MarkdownPanel periodically
  timerFcn = @(s,e)set(panel, 'Content', char(je.getText()));
  htimer = timer( ...
      'Period',        1, ...
      'BusyMode',      'drop', ...
      'TimerFcn',      timerFcn, ...
      'ExecutionMode', 'fixedRate');
  % Destroy the timer when the panel is destroyed
  function stopAndDeleteTimer()
      stop(htimer);
      delete(htimer);
  end
  L = addlistener(panel, 'ObjectBeingDestroyed', @(s,e)stopAndDeleteTimer());
  setappdata(parent, 'Timer', L);
  % Start the refresh timer
  start(htimer)

end