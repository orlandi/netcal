function fn_nicegraph(ha)
% function fn_nicegraph([ha])
%---
% see also fn_labels, fn_scale, fn_plotscale

% Thomas Deneux
% Copyright 2005-2017

if nargin==0, ha = gca; end

set(ha,'tickdir','out','ticklength',[.03 1],'box','off')
