#@ File(label="Select the first tile", style="file") myFileOri
#@ Integer(label="number of tiles along X",value=8,persist=true) tileX
#@ Integer(label="number of tiles along Y",value=14,persist=true) tileY
#@ Integer(label="max number of time points to analyse",value=999,persist=true) maxTp

/*
 * Macro for correcting, stitching and aligning time lapse mosaic images acquired with a custom 
 * microscope 
 * 
 * Written by S.Herbert sherbert@pasteur.fr 
 * 
 * DO NOT FORGET TO SWITCH ON PROCESS/BINARY/OPTIONS/ BLACK BACKGROUND
 */

setBatchMode(true);

// PARAMS //
hyperFoldName = "hyperFolderSingleTiff"; // name of the folder to dump the hypoerstack image sequence
tempHyperTpName = "tempHyperTp"; // name of the temporary time point opened to be processed
nDigits = 3; // number of digits into the file name time or slice description
contourTpName = "contourTiles"; // name of the multitiff image containing only the contour tiles of the specific timepoint
fFCorrTp = "fFCorr"; // flat field corrected tiles of a single time point
hyperFFCorrFoldName = "hyperFFCorr"; // Folder name for flat-field corrected tile list
tileOverlap = 20; // tile overlap ratio
mosaicFoldName = "stitchedTimePoints"; // Name of the stitcher output folder
mosaicRegFoldName = "regMosaic"; // Name of the output folder for registered mosaic
movieOutputFoldName = "outputMovie"; // Name of the folder containing the movie
movieOutputName = "regMovie"; // Name of the movie after alignment (registration)
outParams = "analysisParams.txt"; // Name of the output file to remember the parameters used

// stitch options
stitchOpts = newArray(4);
stitchOpts[0] = "Linear Blending"; // fusion_method
stitchOpts[1] = 0.30; // regression_threshold
stitchOpts[2] = 4; // max/avg_displacement_threshold
stitchOpts[3] = 3; // absolute_displacement_threshold
// *PARAMS* //

run("Close All");

// Load images in virtual stack
// run("Image Sequence...", "open="+myFileOri+" sort use"); => For virtual stack; better but requires virtual stack investigation...

// Load images
run("Image Sequence...", "open="+myFileOri+" sort");

// invert images
run("Invert", "stack");

// Reshuffle the stack into an hyperstack
//print("nSlices="+nSlices);
tilesPerTp = tileX*tileY;
totFrame = nSlices/tilesPerTp;
run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices="+tilesPerTp+" frames="+totFrame+" display=Color");

// Save the hyperstack as single tiff for later work
myRootDir = getDirectory("image");
myRootDir = myRootDir+"/.."; // Yes, it's ugly and OS specific, but it's good enough for the moment...
myHyperDir = myRootDir+"/"+hyperFoldName;

File.makeDirectory(myHyperDir); 
run("Image Sequence... ", "format=TIFF save="+myHyperDir+"/hyperbrutes_t001_z001.tif");

run("Close All");


// Work on each independant time frame for flat field filtering, mosaic stitching and registered mosaic stitching
tempFFCOutFolder = myRootDir+"/"+hyperFFCorrFoldName+"/";
File.makeDirectory(tempFFCOutFolder);
File.makeDirectory(myRootDir+"/"+mosaicFoldName);
File.makeDirectory(myRootDir+"/"+mosaicRegFoldName);

// delete previous images in the mosaic folder
fileList = getFileList(myRootDir+"/"+mosaicFoldName);
for (i=0; i<fileList.length; i++) {
	print(myRootDir+"/"+mosaicFoldName +"/"+fileList[i]);
	File.delete(myRootDir+"/"+mosaicFoldName +"/"+fileList[i]);
}
// delete previous images in the registered mosaic folder
regFileList = getFileList(myRootDir+"/"+mosaicRegFoldName);
for (i=0; i<regFileList.length; i++) {
	print(myRootDir+"/"+mosaicRegFoldName +"/"+regFileList[i]);
	File.delete(myRootDir+"/"+mosaicRegFoldName +"/"+regFileList[i]);
}


totFrame =  minOf(totFrame, maxTp); // limit the number of timepoints to use
mosaicHeight = newArray(totFrame);
mosaicWidth = newArray(totFrame);

for (tp=1; tp<=totFrame; tp++){
	// Open the whole tp
	timeStr = "t"+elongateNum2Str(nDigits, tp);
	run("Image Sequence...", "open="+myHyperDir+" file="+timeStr+" sort");
	rename(tempHyperTpName);

	contourExtract(tempHyperTpName);
	
	// Correct chip dirt => Work only on contour to avoid long term mushroom growth issues
	tempFCCNameOut = ""+fFCorrTp+"_"+timeStr+"_tile";
	flatFieldCorrect(timeStr, tempHyperTpName, tempFFCOutFolder, tempFCCNameOut);
	
	// Correct light intensity => maybe later if needed.

	// Run stiching
	imSize = runStitching(timeStr, tempFFCOutFolder, tempFCCNameOut, stitchOpts);
	mosaicWidth[tp-1] = imSize[0];
	mosaicHeight[tp-1] = imSize[1];	
	
	run("Close All");
}

// align all mosaics
// checkMosaicsSize() => not needed anymore v2.3
File.makeDirectory(myRootDir+"/"+movieOutputFoldName);
alignMosaics()

// Save parameters into a txt file
PathParamsFile = myRootDir+"/"+movieOutputFoldName+"/"+outParams;
File.open(PathParamsFile);
File.append("Image analysis parameters", PathParamsFile);
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
File.append("Analysis performed the: "+year+"/"+month+1+"/"+dayOfMonth, PathParamsFile);
File.append("Input directory: "+myRootDir, PathParamsFile);
File.append("number of tiles along X: "+tileX, PathParamsFile);
File.append("number of tiles along Y: "+tileY, PathParamsFile);
File.append("max number of time points to analyse: "+maxTp, PathParamsFile);
File.append("TileOverlap="+tileOverlap, PathParamsFile);
File.append("", PathParamsFile); // skip line
File.append("Stitching options", PathParamsFile);
File.append("fusion_method: "+stitchOpts[0], PathParamsFile);
File.append("regression_threshold: "+stitchOpts[0], PathParamsFile);
File.append("max/avg_displacement_threshold: "+stitchOpts[0], PathParamsFile);
File.append("absolute_displacement_threshold: "+stitchOpts[0], PathParamsFile);

IJ.log("Done stitching");

function alignMosaics(){
	/*
	 * Because slight modifications of the position or rotation of the sample have appeared, we realign the 
	 * individual mosaics based on their content
	 */
 	 
	virtualRegDescriptor = "source="+myRootDir+"/"+mosaicFoldName+" ";
	virtualRegDescriptor = virtualRegDescriptor+"output="+myRootDir+"/"+mosaicRegFoldName+" ";
	virtualRegDescriptor = virtualRegDescriptor+"feature=Rigid registration=[Rigid                -- translate + rotate                  ] shrinkage";
	run("Register Virtual Stack Slices", virtualRegDescriptor);

	run("Close All");

	// resave as a single multitiff file
	run("Image Sequence...", "open="+myRootDir+"/"+mosaicRegFoldName+"/MosaicTest_t001.tif sort");
	saveAs("Tiff", myRootDir+"/"+movieOutputFoldName+"/"+movieOutputName);
	
}
 
 
function checkMosaicsSize(){
	/*
	 * Because of the stitching, all mosaics are not exactly the same size (only a couple of pixel different),
	 * this can be due to rotation or placement.
	 * Open each mosaic
	 * Resize the image canvas
	 * Overwrite the mosaic
	 */
	for (tp=1; tp<=totFrame; tp++){
		timeStr = "t"+elongateNum2Str(nDigits, tp);
		open(myRootDir+"/"+mosaicFoldName+"/MosaicTest_"+timeStr+".tif");
		run("Canvas Size...", "width="+maxOfArray(mosaicWidth)+" height="+maxOfArray(mosaicHeight)+" position=Center");
		saveAs("Tiff", myRootDir+"/"+mosaicFoldName+"/MosaicTest_"+timeStr+".tif");
	}
	run("Close All");
}


function contourExtract(tempHyperTpName){
	/*  
	 *  Evaluate the coordinates of the image contour
	 *  Substack the contour of the image from the (already open) full timepoint
	 */
	
	substackI = ""; // List of the contour tiles indexes
	for (posI=1; posI<=tileX; posI++){ // first row indices
		substackI = substackI+posI+",";
	}
	for (lineI=2; lineI<tileY; lineI++){ // sides of the image
		substackI = substackI+((lineI-1)*tileX+1)+","+(lineI*tileX)+",";
	}
	for (posI=tileX*(tileY-1)+1; posI<=tileX*tileY; posI++){ // last row indices
		substackI = substackI+posI+",";
	}
	substackI = substring(substackI,0,lengthOf(substackI)-1);	
	selectWindow(tempHyperTpName);
	// print("substackI="+substackI);
	run("Make Substack...", "  slices="+substackI);
	rename(contourTpName);
}


function flatFieldCorrect(timeStr, tempHyperTpName, tempFFCOutFolder, tempFCCNameOut){
	/*
	 *  Calculates the median image (camera chip constant markers)
	 *  Corrects the whole timePoint
	 *  Saves
	 */
	selectWindow(contourTpName);
	run("Z Project...", "projection=Median");
	titleMedImage=getTitle();
	imageCalculator("Subtract create 32-bit stack", tempHyperTpName,titleMedImage);
	rename(fFCorrTp+"_"+timeStr);
	run("8-bit");
	run("Image Sequence... ", "format=TIFF name="+tempFCCNameOut+" start=1 digits=3 save="+tempFFCOutFolder+tempFCCNameOut+"001.tif");
}	


function elongateNum2Str(nDigits, number){
	/*
	 * to fit a number into a number of nDigits digits 
	 */
	if (number<10) {
		outNumber = "00"+number;
	} else if (number<100){
		outNumber = "0"+number;
	} else if (number<1000){
		outNumber = ""+number;
	}
	return outNumber; 
}


function runStitching(timeStr, tempFFCOutFolder, tempFCCNameOut, stitchOpts){
	/*
	 * Deals with the call to the stitcher
	 */
	stitchOptions  = " type=[Grid: snake by columns]";
	stitchOptions += " order=[Down & Left]";
	stitchOptions += " grid_size_x="+tileX+" grid_size_y="+tileY;
	stitchOptions += " tile_overlap="+tileOverlap;
	stitchOptions += " first_file_index_i=1";
	stitchOptions += " directory="+tempFFCOutFolder;
	stitchOptions += " file_names="+tempFCCNameOut+"{iii}.tif";
	stitchOptions += " output_textfile_name=TileConfiguration_script_"+timeStr+".txt";
	stitchOptions += " fusion_method=["+stitchOpts[0]+"]";
	stitchOptions += " regression_threshold="+stitchOpts[1];
	stitchOptions += " max/avg_displacement_threshold="+stitchOpts[2];
	stitchOptions += " absolute_displacement_threshold="+stitchOpts[3];
	stitchOptions += " compute_overlap";
	stitchOptions += " ignore_z_stage";
	stitchOptions += " computation_parameters=[Save computation time (but use more RAM)]";
	stitchOptions += " image_output=[Fuse and display]";
	stitchOptions += " output_directory=["+myRootDir+"/"+mosaicFoldName+"]";

	run("Grid/Collection stitching", stitchOptions);
	
	run("Save", "save="+myRootDir+"/"+mosaicFoldName+"/MosaicTest_"+timeStr+".tif");
	imSize = newArray(getWidth,getHeight);
	run("Close All");

	return imSize;
}


//Returns the maximum of the array
function maxOfArray(array) {
    min=0;
    for (a=0; a<lengthOf(array); a++) {
        min=minOf(array[a], min);
    }
    max=min;
    for (a=0; a<lengthOf(array); a++) {
        max=maxOf(array[a], max);
    }
    return max;
}



