# Use Contour Image
If you have performed ROI detection with another software and your output is a binary image with ROI contours you can easily import them in NETCAL. The first step is to set that image as the active image:
1. Menu **Analysis &rarr; Fluorescence &rarr; Change Active Image**
2. Change **Selection** to *external file*
3. Select the desired file in **External File**

Next step is to perform the ROI detection, for that use:
1. Menu **Analysis &rarr; Fluorescence &rarr; ROI detection &rarr; Automatic ROI detection**
2. Change **automaticType** to *binaryContour*

This should automatically create a ROI list based on the contours defined on the external image. To recover the average fluorescence file as the active image do:
1. Menu **Analysis &rarr; Fluorescence &rarr; Change Active Image**
2. Change **Selection** to *average fluorescence*

## View ROI
You can also do all of this within the **View &rarr; ROI** menu:
1.  Change the **Image** on the left side of the window to *Custom* and choose your contour file
2. **Add ROI &rarr; Automatic**
3. Change **automaticType** to *binaryContour*


## Pipeline
1. The Active Image function is in **Fluorescence &rarr; Basic** or **Misc**
2. The Automatic ROI detection is in **Fluorescence &rarr; Basic**