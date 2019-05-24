%Clear all,close all
clc, close all, clear all

%Initialise Array of label image name and OCR name
global nameArray ;
nameArray = [];

% Select the input-folder that contains the reference image
refDir=uigetdir('','Select the reference image folder');
%refDir='C:\Users\SCRMIMG\Desktop\Reference';

% Select the input-folder that contains the subfolders to process
inputDir=uigetdir('','Select the folder containing the data to automatically rename');
%inputDir='C:\Users\SCRMIMG\Desktop\Mock';

% Check to make sure that folder actually exists.  Warn user if it doesn't.
if ~isdir(inputDir)
    errorMessage = sprintf('Error: The following folder does not exist:\n%s', inputDir);
    uiwait(warndlg(errorMessage));
    return;
end

%List of folders & files in th einput directory
cd(inputDir);
list = dir;

% https://uk.mathworks.com/help/matlab/ref/isdir.html
% onlyFolders = listing([listing.isdir]); onlyFolders.name
onlyFolders = list([list.isdir]);   %listing only folders

% https://uk.mathworks.com/matlabcentral/answers/283340-open-and-process-files-in-subfolders
onlyFolders = list(~ismember({list.name},{'.' '..'}));  %excluding '.' & '..' folders

for i=1:length(onlyFolders) % process each slide subfolder
    subFolderName = onlyFolders(i).name;
    path = fullfile(inputDir,onlyFolders(i).name)
    cd(path)
    listOfFiles = dir('Label*.tif');    % identify the label image file
    for k = 1:length(listOfFiles)
        fullFileName = fullfile(inputDir, onlyFolders(i).name, listOfFiles(k).name);
        baseFileName = listOfFiles(k).name;
        fprintf(1, 'Now reading %s\n', fullFileName);
        distorted = imread(fullFileName);
        distorted = rgb2gray(distorted);
        % Reference image path
        refBaseName = 'reference.tif';
        refFileName = fullfile(refDir,refBaseName );
        % reference image for the slide label orientation. Has to be updated if different slide used
        reference = imread(refFileName);
        reference = rgb2gray(reference);
        ptsOriginal  = detectSURFFeatures(reference);
        ptsDistorted = detectSURFFeatures(distorted);
        [featuresOriginal,   validPtsOriginal]  = extractFeatures(reference,  ptsOriginal);
        [featuresDistorted, validPtsDistorted]  = extractFeatures(distorted, ptsDistorted);
        indexPairs = matchFeatures(featuresOriginal, featuresDistorted);
        matchedOriginal  = validPtsOriginal(indexPairs(:,1));
        matchedDistorted = validPtsDistorted(indexPairs(:,2));
        %figure('Name','01');
        %showMatchedFeatures(reference,distorted,matchedOriginal,matchedDistorted);
        title('Putatively matched points (including outliers)');
        [tform, inlierDistorted, inlierOriginal] = estimateGeometricTransform(...
            matchedDistorted, matchedOriginal, 'similarity');
        %figure('Name','02');
        %showMatchedFeatures(reference,distorted, inlierOriginal, inlierDistorted);
        title('Matching points (inliers only)');
        legend('ptsOriginal','ptsDistorted');
        Tinv  = tform.invert.T;
        ss = Tinv(2,1);
        sc = Tinv(1,1);
        scale_recovered = sqrt(ss*ss + sc*sc);
        theta_recovered = atan2(ss,sc)*180/pi;
        outputView = imref2d(size(reference));
        recovered  = imwarp(distorted,tform,'OutputView',outputView);
        %figure('Name','Registered Pair');, imshowpair(reference,recovered,'montage')
        aligned_crop = imcrop(recovered,[5 230 1040 670]);
        %figure('Name','Crop');, imshow(aligned_crop);
        ocrResults = ocr(aligned_crop);
        ocrResults.Words;
        lenWords=length(ocrResults.Words);
        n=0;
        
        % Identify block name among OCR words
        for j = 1:lenWords
            currentWord=string(ocrResults.Words{j});
            if (regexp(currentWord,'\w*[Ss][Ll]\w*'))
                disp(currentWord)
                newName=currentWord
                fileName= string(listOfFiles(k).name);
                Array = [fullFileName baseFileName newName];
                nameArray=[nameArray; Array];
                n=1;
            end
        end
        disp(n);
        
        % routine to check if a word has been identified for the block
        if n == 0
            errorMsg = string('not recognised');
            fileName= string(listOfFiles(k).name);
            errorArray = [fullFileName baseFileName errorMsg];
            nameArray=[nameArray; errorArray];
        end
        
        %https://uk.mathworks.com/help/vision/ref/ocrtext-class.html
        bboxes = locateText(ocrResults, '\w*[Ss][Ll]\w*', 'UseRegexp', true);
        %bboxes = locateText(ocrResults, '.*>SL\w*', 'UseRegexp', true);
        img = insertShape(aligned_crop, 'FilledRectangle', bboxes);
        figure('Name','Crop'); 
        %imshow(img);
        
    end
    cd(inputDir)
    %inPath =[inputDir filesep onlyFolders(i).name filesep]
    source =[onlyFolders(i).name]
    if n ==1
        outPath=string(newName)
    end
    if n == 0
        outPath= string('unknown')
    end
    destination =char(outPath)
    movefile (path, destination)
end


close all
nameArray