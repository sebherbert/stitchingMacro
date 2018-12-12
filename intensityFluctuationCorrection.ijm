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
prefIntStable = "intStable_";
outParams = "analysisParams.txt"; // Name of the output file to remember the parameters used
medRad = 5; // use a median filter (in pixels)
corrMethod = "Divide"; // Use a division to correct the intensity shifts
// *PARAMS* //

// Load image
run("Close All");
open(myRegFile);
myOutputDir = getDirectory("image");
myCurrentImageName = getInfo("image.filename");

// Extract  dimensions
getDimensions(width, height, channels, slices, frames);

// Modal intensity method
if ( roiManager("count")!= 0) { // make sure there is no previous ROI
	roiManager("delete");	
}
// create a ROI over the whole image
run("Select All");
roiManager("Add");

// Prepare image
run("Median...", "radius="+medRad+" stack"); // To smoothen out small differences and improve mode eval
if (bitDepth()==8 || bitDepth()==16){
	setMinAndMax(0, 2^bitDepth()-1 );
	run("32-bit"); // to allow for intensity division
}

// Set the measurements to Mode only and measure all frame
run("Set Measurements...", "modal redirect=None decimal=1");
roiManager("multi measure");

// Divide each slice by the mode intensity
for (i=1; i<=nSlices; i++) {
  	setSlice(i);
	modeInt = getResult("Mode1", i-1);
	run(corrMethod+"...", "value="+modeInt+" slice");
}

// Set image back to 8 bits to save memory
setAutoContrasts();
run("8-bit");

// Resave image
outImageName = prefIntStable+myCurrentImageName;
saveAs("Tiff", myOutputDir+"/"+outImageName);

// Save parameters 
PathParamsFile = myOutputDir+"/"+outParams;
if (!File.exists(PathParamsFile)) {
	File.open(PathParamsFile);	
}
File.append("\nImage intensity stabilisation parameters", PathParamsFile);
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
File.append("Analysis performed the: "+year+"/"+month+1+"/"+dayOfMonth, PathParamsFile);
File.append("Input file: "+myOutputDir+myCurrentImageName, PathParamsFile);
File.append("Radius of the median filter: "+medRad, PathParamsFile);
File.append("Correction method: "+corrMethod, PathParamsFile);

// Clean up the Desktop
if (isOpen("Results")) {
   selectWindow("Results");
   run("Close");
} 

// exit macro
IJ.log("Done stabilizing the intensities");


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
 