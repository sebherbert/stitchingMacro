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
prefBinMovieName = "bin_"; // Name of the movie after binarization and filtering
prefFFTMovieName = "FFT_"; // Name of the movie after FFT
outParams = "analysisParams.txt"; // Name of the output file to remember the parameters used
// Thresholding step
binMethod = "MaxEntropy"; // binarization threshold method
doCalculate = 1;
// Analyze particle step
binMinSize = 2000; // smallest object acceptable in binarization
binCirc = "0.00-0.40"; // circularity of the detected object
// *PARAMS* //

run("Close All");

// Open the movie
open(myRegFile);

// Save directory
myOutputDir = getDirectory("image");
myCurrentImageName = getInfo("image.filename");

// run an fft bandpass filter
if (doFFTbandpass) {
	fftParams = "filter_large="+highPass+" filter_small="+lowPass;
	fftParams = fftParams+" suppress="+suppressBands;
	fftParams = fftParams+" tolerance="+angleTol;
	run("Bandpass Filter...", fftParams+" autoscale saturate process");
}
// Save temp file
myCurrentImageName = prefFFTMovieName+myCurrentImageName;
saveAs("Tiff", myOutputDir+"/"+myCurrentImageName);

// make binary
// new image name
myCurrentImageName = prefBinMovieName+myCurrentImageName;
binParams = "method="+binMethod+" background=Default";
if (doCalculate) {
	binParams = binParams+" calculate";
}
binParams =  binParams+" black";
run("Make Binary", binParams);

// clean image based on particle caracteristics
run("Erode", "stack");run("Erode", "stack"); // Should look for a nicer way of morphological opening but same result in the end
run("Dilate", "stack");run("Dilate", "stack"); // Also if changed here, should also change the output params text file
run("Analyze Particles...", "size="+binMinSize+"-Infinity circularity="+binCirc+" show=Masks exclude clear stack");
rename(myCurrentImageName);
// invert images
run("Invert", "stack");
saveAs("Tiff", myOutputDir+"/"+myCurrentImageName);

// Save Parameters
PathParamsFile = myOutputDir+"/"+outParams;
if (!File.exists(PathParamsFile)){
	File.open(PathParamsFile);	
}
// Could look for the "Image binarisation parameters" string and delete anything after
// => a default of this is the analysis of the same source with different parameters 
File.append("\nImage binarisation parameters", PathParamsFile);
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
File.append("Analysis performed the: "+year+"/"+month+1+"/"+dayOfMonth, PathParamsFile);
File.append("Input directory: "+myOutputDir, PathParamsFile);

File.append("\nFFT parameters", PathParamsFile); // FFT params
File.append("Apply a bandpass FTT filter: "+doFFTbandpass, PathParamsFile);
if (doFFTbandpass) {
	File.append("Largest structure size (pixel): "+highPass, PathParamsFile);
	File.append("Smallest structure size (pixel): "+lowPass, PathParamsFile);
	File.append("Suppress bands in image: "+suppressBands, PathParamsFile);
	File.append("Tolerance angle: "+angleTol, PathParamsFile);
}

File.append("\nBinarisation parameters", PathParamsFile); //binarisation params
File.append("binarization parameters:\n"+binParams, PathParamsFile);

File.append("\nPost binarization parameters", PathParamsFile); // post binarisation params
File.append("Do Opening twice", PathParamsFile);
File.append("Object minimum size: "+binMinSize, PathParamsFile);
File.append("Object circularity: "+binCirc, PathParamsFile);

// exit macro
IJ.log("Done Binarizing");
