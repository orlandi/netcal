function hh = merge_multigap_subplot(ax, rowRange, colRange)
% Returns the handle to the new axes

% Get the axis in matrix form

idxs = [];
for i = rowRange
    for j = colRange
        idxs = [idxs; sub2ind(size(ax), i, j)];
    end
end

% Now get all the positions and do the merging
pos = zeros(length(idxs), 4);
for i = 1:length(idxs)
    pos(i,:) = get(ax(idxs(i)), 'Position');
    set(ax(idxs(i)), 'Visible', 'off');
end
x = min(pos(:,1));
y = min(pos(:,2));
[~,lastelemw] = max(pos(:,1));
[~,lastelemh] = max(pos(:,2));
w = pos(lastelemw,3)+pos(lastelemw,1)-x;
h = pos(lastelemh,4)+pos(lastelemh,2)-y;
%pos
%[x y w h]
hh = axes('Units','normalized', ...
          'position',[x, y, w, h]);
          %'XTickLabel','', ...
          %'YTickLabel','');

