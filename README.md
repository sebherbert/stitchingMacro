# stitchingMacro
performs a flat field correction followed by a 2D+t stitching, registration and binarization


# Analysis protocol
1. Run the tiles2timeMosaic.ijm macro to reconstruct the mosaic into a single stitched file named regMovie.tif that will be the input of the next macro
1. It is better to crop the black borders in the regMovie.tif file, to not disturb the intensity profile with arbitrary empty points => This can be done using the "crop" function of Fiji.
1. Run the intensityFluctuationCorrection.ijm macro to stabilize the image intensity across the timepoints. This step can be skipped.
1. Run timeMosaic2Bin.ijm macro to apply an FFT bandpass filter (or not, you can decide in the GUI) to the images followed by a binarization process
