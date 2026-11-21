function menuTutorialOpen(~, ~, tutorialFile)
  [fpa, fpb, fpc] = fileparts(tutorialFile);
  hFig = figure('name', ['Tutorial: ' fpb], 'NumberTitle', 'off',...
    'toolbar','none','menubar','none');
  hFig.Position = setFigurePosition(gcbf, 'width', 600, 'height', 700);
  tutFile = fileread(tutorialFile);
  gap = 0.025;
  hFigPanel = MarkdownPanel('Parent', hFig, 'Position',  [gap, gap, 1-2*gap, 1-2*gap]);
  set(hFigPanel, 'Content', tutFile);

 % Setup a timer to refresh the MarkdownPanel periodically
  timerFcnB = @(s,e)set(hFigPanel, 'Content', char(hFigPanel.Content));
  doctimer = timer( ...
      'Period',        1, ...
      'BusyMode',      'drop', ...
      'TimerFcn',      timerFcnB, ...
      'ExecutionMode', 'fixedRate');

  % Destroy the timer when the panel is destroyed

  L = addlistener(hFigPanel, 'ObjectBeingDestroyed', @timerCallbackB);
  setappdata(hFig, 'Timer', L);

  % Start the refresh timer
  start(doctimer)
  function timerCallbackB(~, ~)
    stop(doctimer);
    delete(doctimer);
  end
end