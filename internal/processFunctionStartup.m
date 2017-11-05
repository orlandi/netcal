function [params, var] = processFunctionStartup(options, varargin)
if(isempty(options))
  params = struct;
  var = varargin(2:end);
else
  optionsClass = options;
  params = optionsClass().get;
  var = varargin;
  if(length(varargin) >= 1 && isa(varargin{1}, class(optionsClass)))
    params = varargin{1}.get;
    if(length(varargin) > 1)
      var = varargin(2:end);
    else
      var = [];
    end
  end
end