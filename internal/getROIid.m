function ROIid = getROIid(ROI)
if(iscell(ROI) && ischar(ROI{1}.ID))
    ROIid = cell(size(ROI));
    for i = 1:length(ROI)
        ROIid{i} = ROI{i}.ID;
    end
else
    ROIid = zeros(size(ROI));
    for i = 1:length(ROI)
        ROIid(i) = ROI{i}.ID;
    end
end
