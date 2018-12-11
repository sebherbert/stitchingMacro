#@ File(label="Select the regMovie (after cropping the black borders)", style="file") myRegFile
#@ Integer(label="provide the size of a single tile along X",value=960,persist=false) sizeTileX
#@ Integer(label="provide the size of a single tile along Y",value=600,persist=false) sizeTileY


/*
 * Macro for correction the intensity fluctuations in a time lapse images acquired 
 * with a custom brightfield microscope 
 * 
 * To do so, the image is divided by the intensity distribution mode across the whole image. 
 * Although correcting illumination artefacts, this type of stabilisation is known to diminish 
 * the overall range of the signal intensity
 * 
 * Written by S.Herbert sherbert@pasteur.fr 
 */

// PARAMS //
outImageName = "intStable_regMovie"
// *PARAMS* //

// Load image
run("Close All");
open(myRegFile);
myOutputDir = getDirectory("image");

// Extract  dimensions
getDimensions(width, height, channels, slices, frames);

/*/ Extract borders method
ROIcoords = ROIborders(sizeTileX, sizeTileY, width, height);
// Fill the inside rectangle with 0
makeRectangle(ROIcoords[0], ROIcoords[1], ROIcoords[2], ROIcoords[3]);
setForegroundColor(0, 0, 0);
run("Fill", "stack");
// Use border for ratio based intensity correction
*/

// Modal intensity method
if ( roiManager("count")!= 0) { // make sure there is no previous ROI
	roiManager("delete");	
}
// create a ROI over the whole image
run("Select All");
roiManager("Add");

// Prepare image
//run("Median...", "radius=5 stack"); // To smoothen out small differences and improve mode eval
run("32-bit"); // to allow for intensity division

// Set the measurements to Mode only and measure all frame
run("Set Measurements...", "modal redirect=None decimal=1");
roiManager("multi measure");

// Divide each slice by the mode intensity
for (i=1; i<=nSlices; i++) {
  	setSlice(i);
	modeInt = getResult("Mode1", i-1);
	run("Divide...", "value="+modeInt+" slice");
}

// Set image back to 8 bits to save memory
setAutoContrasts();
run("8-bit");

// Resave image
saveAs("Tiff", "/media/sherbert/Data/Projects/Own_Project/macro_for_stitch/outputMovie/intStable_regMovie.tif");



function ROIborders(sizeTileX, sizeTileY, width, height) {
	// create a contour ROI of the image
	x0 = sizeTileX;
	y0 = sizeTileY;
	w = width-2*sizeTileX;
	h = height-2*sizeTileY;
	
	if (x0<100 || y0<100) { // check coordinates
		print("tile sizes are suspiciously small, please double check: x0="+x0+"pix y0="+y0+"pix");
	}
	if (w<0 || h<0) {
		exit("Error: width and height of the cut region are larger than image itself");
	}
	ROIcoords = newArray(x0, y0, w, h);
	return ROIcoords;
}

function setAutoContrasts(){
	 AUTO_THRESHOLD = 5000;
	 getRawStatistics(pixcount);
	 limit = pixcount/10;
	 threshold = pixcount/AUTO_THRESHOLD;
	 nBins = 256;
	 getHistogram(values, histA, nBins);
	 i = -1;
	 found = false;
	 do {
	         counts = histA[++i];
	         if (counts > limit) counts = 0;
	         found = counts > threshold;
	 }while ((!found) && (i < histA.length-1))
	 hmin = values[i];
	 
	 i = histA.length;
	 do {
	         counts = histA[--i];
	         if (counts > limit) counts = 0; 
	         found = counts > threshold;
	 } while ((!found) && (i > 0))
	 hmax = values[i];

	 setMinAndMax(hmin, hmax);
}
 