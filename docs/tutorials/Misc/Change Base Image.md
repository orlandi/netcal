# Change Base Image
By default NETCAL uses as default image the average fluorescence image obtained from the preprocessing step. However, sometimes you might want to use a different one. You might want to visualize the ROI on top of the bright field, or you obtained a much better image in some other way. To change the image you can proceed as follows:
1. Menu **Analysis &rarr; Fluorescence &rarr; Change Active Image**
2. Change **Selection** to *external file* (If you want to use an external file)
3. Select the desired file in **External File**

Now if you go to **View &rarr; ROI** or **View &rarr; Groups** you should see the new image in use. If you want to go back to the old image, repeat the steps, but in **Selection** choose the average fluorescence image instead.

## Pipeline
1. The Active Image function in **Fluorescence &rarr; Basic** or **Misc**