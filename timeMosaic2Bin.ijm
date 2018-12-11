#@ File(label="Select the registered movie", style="file") myRegFile
#@ Boolean(label="Apply a bandpass FTT filter",value=true,persist=true) doFFTbandpass
#@ Integer(label="Largest structure size (pixel)",value=40,persist=true) highPass
#@ Integer(label="Smallest structure size (pixel)",value=3,persist=true) lowPass
#@ String(label="Suppress bands in image",choices={"None","Vertical","Horizontal"}) suppressBands
#@ Integer(label="Tolerance angle",value=45,persist=true) angleTol

/*
 * Macro for thresholding time lapse mosaic images acquired with a custom microscope 
 * 
 * Written by S.Herbert sherbert@pasteur.fr 
 * 
 * DO NOT FORGET TO SWITCH ON PROCESS/BINARY/OPTIONS/ BLACK BACKGROUND
 */

 setBatchMode(true);

// PARAMS //
binMovieName = "binarizedMovie"; // Name of the movie after binarization and filtering
// *PARAMS* //

run("Close All");

// Open the movie
open(myRegFile);

// Save directory
myOutputDir = getDirectory("image");

// run an fft bandpass filter
if (doFFTbandpass) {
	fftParams = "filter_large="+highPass+" filter_small="+lowPass;
	fftParams = fftParams+" suppress="+suppressBands;
	fftParams = fftParams+" tolerance="+angleTol;
	run("Bandpass Filter...", fftParams+" autoscale saturate process");
}


// make binary
run("Make Binary", "method=MaxEntropy background=Default calculate black");

// clean image based on particle caracteristics
run("Erode", "stack");run("Erode", "stack"); // Should look for a nicer way of morphological opening but same result in the end
run("Dilate", "stack");run("Dilate", "stack");
run("Analyze Particles...", "size=2000-Infinity circularity=0.00-0.40 show=Masks exclude clear stack");
rename(binMovieName);
// invert images
run("Invert", "stack");
saveAs("Tiff", myOutputDir+"/"+binMovieName);





