%% Load image(s)
[filenames, path] = uigetfile('*.*', 'MultiSelect', 'on');
if isa(filenames,'char')
    filenames = {filenames};
end

for fi=1:size(filenames, 2)
    filename = filenames{1,fi};
    img = imread(fullfile(path, filename));

    %% Select ROI
    figure('Name',filename,'NumberTitle','off');
    imshow(img)
    hFig = gcf;
    set(hFig,'units','normalized','outerposition',[0 0 1 1]);
    roi = drawrectangle('Color',[1 0 0]);
    roi.Position = floor(roi.Position);
    img = img(roi.Position(2):roi.Position(2)+roi.Position(4), roi.Position(1):roi.Position(1)+roi.Position(3), :);
    close all
    
    %% RBG image to hsv
    img_hsv = rgb2hsv(img);
    img_v = img_hsv(:,:,2);
    
    %% Contrast-Limited Adaptive Histogram Equalization (CLAHE)
    img_eq = adapthisteq(img_v);
    % imshowpair(img_eq, img_v, 'montage')
    
    %% Image quantization
    thresh = multithresh(img_v,2);
    img_v_quan = imquantize(img_v,thresh);
    % imshowpair(img_v_quan, img_v, 'montage')
    
    % img_v_kmeans = imsegkmeans(uint8(img_v*255),3);
    % img_eq_kmeans = imsegkmeans(uint8(img_eq*255),3);
    % imshowpair(img_v_kmeans, img_eq_kmeans, 'montage')
    
    
    %% Watershed segmentation
    img_test = (img_v_quan==3);
    
    D = bwdist(~img_test);
    D = -D;
    L = watershed(D);
    mask = imextendedmin(D,2);
    % imshowpair(img,mask,'blend')
    
    D2 = imimposemin(D,mask);
    Ld2 = watershed(D2);
    bw3 = img_test;
    bw3(Ld2 == 0) = 0;
    imshow(bw3)
    
    
    %% BlobAnalysis System object to find the centroid of the flies
    hblob = vision.BlobAnalysis( ...
                    'AreaOutputPort', false, ...
                    'BoundingBoxOutputPort', false, ...
                    'OutputDataType', 'single',...
                    'MinimumBlobArea', 20,...
                    'MaximumBlobArea', 10000, ...
                    'MaximumCount', 1500);
    Centroid = step(hblob, bw3);   % Calculate the centroid
    numFlies = numFliesFun(Centroid);  % and number of flies.
    
    %% Plot results
    figure
    ax1 = subplot(1,1,1);
    im = imshow(img);
    hFig = gcf;
    set(hFig,'units','normalized','outerposition',[0 0 1 1]);
    t=title([filename '   ' 'Number of flies: ' num2str(numFlies)]);
    hold(ax1, 'on')
    sc = scatter(Centroid(:,1), Centroid(:,2), 15, 'red', 'filled');
    
    
    %% Edit manually
    while 1
        [x,y,button] = ginput(1);
    
        % Left click (1) - Add point
        if button==1
            Centroid = cat(1, Centroid, [x, y]);
            delete(sc)
            sc = scatter(Centroid(:,1), Centroid(:,2), 15, 'red', 'filled');
    
        % Right click (3) - Remove nearest point
        elseif button==3
            distance = 1000000000;
            pos = 0;
            for i=1:size(Centroid, 1)
                d = sqrt((Centroid(i,1)-x)^2 + (Centroid(i,2)-y)^2);
                if d<distance
                    pos = i;
                    distance = d;
                end
            end
            Centroid(pos,:)=[];
            delete(sc)
            sc = scatter(Centroid(:,1), Centroid(:,2), 15, 'red', 'filled');
    
        % Any keyboard button (e.g. spacebar) - Exit
        else
            disp([filename, ', ', num2str(numFlies)])
            break
        end
        
        % update count
        numFlies = numFliesFun(Centroid);
        t.String = [filename '   ' 'Number of flies: ' num2str(numFlies)];
    end

    %% (Optional) Save image with annotation
    answer = questdlg('Save result image?', ...
	    'Save', ...
	    'Save', 'Save and choose folder', 'No', 'Save');
    % Handle response
    filename_save = replace(filename, '.', '_count.');
    switch answer
        case 'Save'
            saveas(hFig, fullfile(path, filename_save))
        case 'Save and choose folder'
            savepath = uigetdir;
            saveas(hFig, fullfile(savepath, filename_save))
        case 'No'
            close all
    end
    close all

end

%% Function for flies calculation
function num = numFliesFun(points)
    num = size(points,1);
end









