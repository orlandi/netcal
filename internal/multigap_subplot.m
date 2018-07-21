function ax = multigap_subplot(R, C, varargin)
% multigap_subplot creates "subplot" axes with adjustable gaps and margins
%
% ha = tight_subplot(Nh, Nw, gap, marg_h, marg_w)
params.gap_R = 0.02;
params.gap_C = 0.02;
params.margin_TB = 0.05;
params.margin_LR = 0.05;
params.ratio_R = [];
params.ratio_C = [];
params.mode = 'tight';
params.Parent = [];
params = parse_pv_pairs(params,varargin); 

gap_R = params.gap_R;
gap_C = params.gap_C;
margin_TB = params.margin_TB;
margin_LR = params.margin_LR;
ratio_R = params.ratio_R;
ratio_C = params.ratio_C;

if(strcmp(params.mode,'tight'))
    mode = 'Position';
elseif(strcmp(params.mode,'loose'))
    mode = 'OuterPosition';
else
    error('multigap:errMode','Mode not recognized. Options are "tight" and "loose"')
end
if numel(gap_R) == 1
    gap_R = ones(R-1,1)*gap_R;
elseif(numel(gap_R) ~= R-1)
    error('multigap:errGap','Wrong number of elements in gap_R. Should be R-1')
end
if numel(gap_C) == 1
    gap_C = ones(C-1,1)*gap_C;
elseif(numel(gap_C) ~= C-1)
    error('multigap:errGap','Wrong number of elements in gap_C. Should be C-1')
end

if numel(margin_TB) == 1
    margin_TB = [1,1]*margin_TB;
end
if numel(margin_LR) == 1
    margin_LR = [1,1]*margin_LR;
end
if(isempty(ratio_R))
    ratio_R = ones(R,1)/R;
elseif(length(ratio_R) ~= R)
    error('multigap:errRatio','Wrong number of elements in ratio_R. Should be R')
end
if(isempty(ratio_C))
    ratio_C = ones(C,1)/C;
elseif(length(ratio_C) ~= C)
    error('multigap:errRatio','Wrong number of elements in ratio_C. Should be C')
end

axh = (1-sum(margin_TB)-sum(gap_R))*ratio_R;
axw = (1-sum(margin_LR)-sum(gap_C))*ratio_C;

py = 1-margin_TB(1)-axh(1);

ha = [];
ii = 0;
for ih = 1:R
    px = margin_LR(1);
    %py
    for ix = 1:C
        ii = ii+1;
        if(isempty(params.Parent))
          ha = [ha; axes('Units','normalized', mode,[px py axw(ix) axh(ih)])];
        else
          ha = [ha; axes('Units','normalized', mode,[px py axw(ix) axh(ih)], 'Parent', params.Parent)];
        end
        %    'XTickLabel','', ...
         %   'YTickLabel','');
        if(ix < C)
            px = px+axw(ix)+gap_C(ix);
        end
    end
    if(ih < R)
        py = py-axh(ih+1)-gap_R(ih);
    end
    
end

%ax = zeros(R, C);
% idx = 1;
% for i = 1:R
%     for j = 1:C
%         ax(i,j) = ha(idx);
%         idx = idx + 1;
%     end
% end
%ax = reshape(ha, [R, C]);
ax = reshape(ha, [C R])';
%ax = permute(ax, [2 1]);


