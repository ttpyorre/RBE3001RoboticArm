classdef Camera < handle
    properties        
        % Properties
        params;
        cam;
        cam_pose;
        cam_IS;
    end
    
    methods
        function self = Camera()
            % CAMERA Construct an instance of this class
            self.cam = webcam(2); % Get camera object
            self.params = self.calibrate(); % Run Calibration Function
            [self.cam_IS, self.cam_pose] = self.getCameraPose();
        end

        function shutdown(self)
            % SHUTDOWN shutdown script which clears camera variable
            clear self.cam;
        end
      
        function params = calibrate(self)
            % CALIBRATE Calibration function
            % This function will run the camera calibration, save the camera parameters,
            % and check to make sure calibration worked as expected
            % The calibrate function will ask if you are ready. To calibrate, you must press
            % any key, then the system will confirm if the calibration is successful

            % NOTE: This uses the camcalib.m file for camera calibration. If you have placed
            % your camera calibration script elsewhere, you will need to change the command below

            params = 0;
            try
                disp("Clear surface of any items, then press any key to continue");
                pause;
                disp("Calibrating");
                cameraCalibration;
                %camcalib; % Change this if you are using a different calibration script
                params = cameraParams;
                disp("Camera calibration complete!");
            catch exception
                msg = getReport(exception);
                disp(msg)
                disp("No camera calibration file found. Plese run camera calibration");
            end          
        end
        
        % Returns an undistorted camera image
        function img = getImage(self)
            raw_img =  snapshot(self.cam);
            [img, new_origin] = undistortFisheyeImage(raw_img, self.params.Intrinsics, 'OutputView', 'full');
        end

        
        function [newIs, pose] = getCameraPose(self)
            % GETCAMERAPOSE Get transformation from camera to checkerboard frame
            % This function will get the camera position based on checkerboard.
            % You should run this function every time the camera position is changed.
            % It will calculate the extrinsics, and output to a transformation matrix.
            % Keep in mind: this transformation matrix is a transformation from pixels
            % to x-y coordinates in the checkerboard frame!

%             % 1. Capture image from camera
            raw_img =  snapshot(self.cam);
% %             % 2. Undistort Image based on params
            [img, newIs] = undistortFisheyeImage(raw_img, self.params.Intrinsics, 'OutputView', 'full');
%             % 3. Detect checkerboard in the image
%             [imagePoints, boardSize] = detectCheckerboardPoints(img);
% %             % 4. Compute transformation
%             [R, t] = extrinsics(imagePoints, self.params.WorldPoints, newIs);
%             
%             pose = [   R,    t';
%                     0, 0, 0, 1]; % do NOT take out commented from comments

         pose = [0.997157428203660,-0.0433281923006824,0.0616419591692043,-116.058048229114;
             0.0742207389998434,0.423972268935247,-0.902628825750771,-43.2660222444101;
             0.0129747940476872,0.904638150271065,0.425982947773226,350.438401521913;
             0,0,0,1];


        end
        
            function [BW,maskedRGBImage] = createMaskGreen(self,RGB)
            %createMask  Threshold RGB image using auto-generated code from colorThresholder app.
            %  [BW,MASKEDRGBIMAGE] = createMask(RGB) thresholds image RGB using
            %  auto-generated code from the colorThresholder app. The colorspace and
            %  range for each channel of the colorspace were set within the app. The
            %  segmentation mask is returned in BW, and a composite of the mask and
            %  original RGB images is returned in maskedRGBImage.

            % Auto-generated by colorThresholder app on 23-Feb-2022
            %------------------------------------------------------


            % Convert RGB image to chosen color space
            I = rgb2hsv(RGB);

            % Define thresholds for channel 1 based on histogram settings
            channel1Min = 0.265;
            channel1Max = 0.252;

            % Define thresholds for channel 2 based on histogram settings
            channel2Min = 0.000;
            channel2Max = 1.000;

            % Define thresholds for channel 3 based on histogram settings
            channel3Min = 0.000;
            channel3Max = 1.000;

            % Create mask based on chosen histogram thresholds
            sliderBW = ( (I(:,:,1) >= channel1Min) | (I(:,:,1) <= channel1Max) ) & ...
                (I(:,:,2) >= channel2Min ) & (I(:,:,2) <= channel2Max) & ...
                (I(:,:,3) >= channel3Min ) & (I(:,:,3) <= channel3Max);

            % Create mask based on selected regions of interest on point cloud projection
            I = double(I);
            [m,n,~] = size(I);
            polyBW = false([m,n]);
            I = reshape(I,[m*n 3]);

            % Convert HSV color space to canonical coordinates
            Xcoord = I(:,2).*I(:,3).*cos(2*pi*I(:,1));
            Ycoord = I(:,2).*I(:,3).*sin(2*pi*I(:,1));
            I(:,1) = Xcoord;
            I(:,2) = Ycoord;
            clear Xcoord Ycoord

            % Project 3D data into 2D projected view from current camera view point within app
            J = self.rotateColorSpaceGreen(I);

            % Apply polygons drawn on point cloud in app
            polyBW = self.applyPolygonsGreen(J,polyBW);

            % Combine both masks
            BW = sliderBW & polyBW;

            % Initialize output masked image based on input image.
            maskedRGBImage = RGB;

            % Set background pixels where BW is false to zero.
            maskedRGBImage(repmat(~BW,[1 1 3])) = 0;

        end

        function J = rotateColorSpaceGreen(self,I)

            % Translate the data to the mean of the current image within app
            shiftVec = [-0.076740 -0.039640 0.523173];
            I = I - shiftVec;
            I = [I ones(size(I,1),1)]';

            % Apply transformation matrix
            tMat = [0.556078 -0.386945 0.000000 -0.229197;
                    0.259440 0.753089 0.289840 -0.789063;
                    0.082570 0.239680 -0.910697 8.933837;
                    0.000000 0.000000 0.000000 1.000000];

            J = (tMat*I)';
        end

        function polyBW = applyPolygonsGreen(self,J,polyBW)

            % Define each manually generated ROI
            hPoints(1).data = [-0.321142 -0.200141;
                -0.265175 -0.167935;
                -0.225199 -0.319766;
                -0.206544 -0.490001;
                -0.281166 -0.600424;
                -0.337132 -0.517607];

            % Iteratively apply each ROI
            for ii = 1:length(hPoints)
                if size(hPoints(ii).data,1) > 2
                    in = inpolygon(J(:,1),J(:,2),hPoints(ii).data(:,1),hPoints(ii).data(:,2));
                    in = reshape(in,size(polyBW));
                    polyBW = polyBW | in;
                end
            end

        end



            function [BW,maskedRGBImage] = createMaskYellow(self,RGB)
                %createMask  Threshold RGB image using auto-generated code from colorThresholder app.
                %  [BW,MASKEDRGBIMAGE] = createMask(RGB) thresholds image RGB using
                %  auto-generated code from the colorThresholder app. The colorspace and
                %  range for each channel of the colorspace were set within the app. The
                %  segmentation mask is returned in BW, and a composite of the mask and
                %  original RGB images is returned in maskedRGBImage.

                % Auto-generated by colorThresholder app on 02-Mar-2022
                %------------------------------------------------------


                % Convert RGB image to chosen color space
                I = rgb2hsv(RGB);

                % Define thresholds for channel 1 based on histogram settings
                channel1Min = 0.000;
                channel1Max = 1.000;

                % Define thresholds for channel 2 based on histogram settings
                channel2Min = 0.000;
                channel2Max = 1.000;

                % Define thresholds for channel 3 based on histogram settings
                channel3Min = 0.000;
                channel3Max = 1.000;

                % Create mask based on chosen histogram thresholds
                sliderBW = (I(:,:,1) >= channel1Min ) & (I(:,:,1) <= channel1Max) & ...
                    (I(:,:,2) >= channel2Min ) & (I(:,:,2) <= channel2Max) & ...
                    (I(:,:,3) >= channel3Min ) & (I(:,:,3) <= channel3Max);

                % Create mask based on selected regions of interest on point cloud projection
                I = double(I);
                [m,n,~] = size(I);
                polyBW = false([m,n]);
                I = reshape(I,[m*n 3]);

                % Convert HSV color space to canonical coordinates
                Xcoord = I(:,2).*I(:,3).*cos(2*pi*I(:,1));
                Ycoord = I(:,2).*I(:,3).*sin(2*pi*I(:,1));
                I(:,1) = Xcoord;
                I(:,2) = Ycoord;
                clear Xcoord Ycoord

                % Project 3D data into 2D projected view from current camera view point within app
                J = self.rotateColorSpaceYellow(I);

                % Apply polygons drawn on point cloud in app
                polyBW = self.applyPolygonsYellow(J,polyBW);

                % Combine both masks
                BW = sliderBW & polyBW;

                % Initialize output masked image based on input image.
                maskedRGBImage = RGB;

                % Set background pixels where BW is false to zero.
                maskedRGBImage(repmat(~BW,[1 1 3])) = 0;

                end

                function J = rotateColorSpaceYellow(self,I)

                % Translate the data to the mean of the current image within app
                shiftVec = [-0.069305 -0.018339 0.541554];
                I = I - shiftVec;
                I = [I ones(size(I,1),1)]';

                % Apply transformation matrix
                tMat = [0.620189 0.129731 0.000000 -0.567767;
                    -0.091659 0.876716 0.032285 -0.438701;
                    -0.003207 0.030675 -0.922705 9.145210;
                    0.000000 0.000000 0.000000 1.000000];

                J = (tMat*I)';
                end

                function polyBW = applyPolygonsYellow(self,J,polyBW)

                % Define each manually generated ROI
                hPoints(1).data = [-0.261302 0.059607;
                    -0.127963 -0.025470;
                    -0.297862 -0.359701;
                    -0.420448 -0.408316;
                    -0.334423 -0.113586];

                % Iteratively apply each ROI
                for ii = 1:length(hPoints)
                    if size(hPoints(ii).data,1) > 2
                        in = inpolygon(J(:,1),J(:,2),hPoints(ii).data(:,1),hPoints(ii).data(:,2));
                        in = reshape(in,size(polyBW));
                        polyBW = polyBW | in;
                    end
                end

                end


            function [BW,maskedRGBImage] = createMaskRed(self,RGB)
                %createMask  Threshold RGB image using auto-generated code from colorThresholder app.
                %  [BW,MASKEDRGBIMAGE] = createMask(RGB) thresholds image RGB using
                %  auto-generated code from the colorThresholder app. The colorspace and
                %  range for each channel of the colorspace were set within the app. The
                %  segmentation mask is returned in BW, and a composite of the mask and
                %  original RGB images is returned in maskedRGBImage.

                % Auto-generated by colorThresholder app on 23-Feb-2022
                %------------------------------------------------------


                % Convert RGB image to chosen color space
                I = rgb2hsv(RGB);

                % Define thresholds for channel 1 based on histogram settings
                channel1Min = 0.000;
                channel1Max = 1.000;

                % Define thresholds for channel 2 based on histogram settings
                channel2Min = 0.000;
                channel2Max = 1.000;

                % Define thresholds for channel 3 based on histogram settings
                channel3Min = 0.000;
                channel3Max = 1.000;

                % Create mask based on chosen histogram thresholds
                sliderBW = (I(:,:,1) >= channel1Min ) & (I(:,:,1) <= channel1Max) & ...
                    (I(:,:,2) >= channel2Min ) & (I(:,:,2) <= channel2Max) & ...
                    (I(:,:,3) >= channel3Min ) & (I(:,:,3) <= channel3Max);

                % Create mask based on selected regions of interest on point cloud projection
                I = double(I);
                [m,n,~] = size(I);
                polyBW = false([m,n]);
                I = reshape(I,[m*n 3]);

                % Convert HSV color space to canonical coordinates
                Xcoord = I(:,2).*I(:,3).*cos(2*pi*I(:,1));
                Ycoord = I(:,2).*I(:,3).*sin(2*pi*I(:,1));
                I(:,1) = Xcoord;
                I(:,2) = Ycoord;
                clear Xcoord Ycoord

                % Project 3D data into 2D projected view from current camera view point within app
                J = self.rotateColorSpaceRed(I);

                % Apply polygons drawn on point cloud in app
                polyBW = self.applyPolygonsRed(J,polyBW);

                % Combine both masks
                BW = sliderBW & polyBW;

                % Initialize output masked image based on input image.
                maskedRGBImage = RGB;

                % Set background pixels where BW is false to zero.
                maskedRGBImage(repmat(~BW,[1 1 3])) = 0;

            end

            function J = rotateColorSpaceRed(self,I)

                % Translate the data to the mean of the current image within app
                shiftVec = [-0.091100 -0.037293 0.548035];
                I = I - shiftVec;
                I = [I ones(size(I,1),1)]';

                % Apply transformation matrix
                tMat = [0.409979 -0.655446 0.000000 0.031650;
                    0.440849 0.589086 0.167165 -0.786052;
                    0.082165 0.109793 -0.896905 9.022360;
                    0.000000 0.000000 0.000000 1.000000];

                J = (tMat*I)';
            end

            function polyBW = applyPolygonsRed(self,J,polyBW)

                % Define each manually generated ROI
                hPoints(1).data = [0.291976 -0.300212;
                    0.390478 -0.401047;
                    0.230061 -0.808969;
                    0.187846 -0.648550;
                    0.227247 -0.291045];

                % Iteratively apply each ROI
                for ii = 1:length(hPoints)
                    if size(hPoints(ii).data,1) > 2
                        in = inpolygon(J(:,1),J(:,2),hPoints(ii).data(:,1),hPoints(ii).data(:,2));
                        in = reshape(in,size(polyBW));
                        polyBW = polyBW | in;
                    end
                end

            end



  

        function [BW,maskedRGBImage] = createMaskOrange(self,RGB)
            %createMask  Threshold RGB image using auto-generated code from colorThresholder app.
            %  [BW,MASKEDRGBIMAGE] = createMask(RGB) thresholds image RGB using
            %  auto-generated code from the colorThresholder app. The colorspace and
            %  range for each channel of the colorspace were set within the app. The
            %  segmentation mask is returned in BW, and a composite of the mask and
            %  original RGB images is returned in maskedRGBImage.

            % Auto-generated by colorThresholder app on 23-Feb-2022
            %------------------------------------------------------


            % Convert RGB image to chosen color space
            I = rgb2hsv(RGB);

            % Define thresholds for channel 1 based on histogram settings
            channel1Min = 0.021;
            channel1Max = 0.017;

            % Define thresholds for channel 2 based on histogram settings
            channel2Min = 0.000;
            channel2Max = 1.000;

            % Define thresholds for channel 3 based on histogram settings
            channel3Min = 0.000;
            channel3Max = 1.000;

            % Create mask based on chosen histogram thresholds
            sliderBW = ( (I(:,:,1) >= channel1Min) | (I(:,:,1) <= channel1Max) ) & ...
                (I(:,:,2) >= channel2Min ) & (I(:,:,2) <= channel2Max) & ...
                (I(:,:,3) >= channel3Min ) & (I(:,:,3) <= channel3Max);

            % Create mask based on selected regions of interest on point cloud projection
            I = double(I);
            [m,n,~] = size(I);
            polyBW = false([m,n]);
            I = reshape(I,[m*n 3]);

            % Convert HSV color space to canonical coordinates
            Xcoord = I(:,2).*I(:,3).*cos(2*pi*I(:,1));
            Ycoord = I(:,2).*I(:,3).*sin(2*pi*I(:,1));
            I(:,1) = Xcoord;
            I(:,2) = Ycoord;
            clear Xcoord Ycoord

            % Project 3D data into 2D projected view from current camera view point within app
            J = self.rotateColorSpaceOrange(I);

            % Apply polygons drawn on point cloud in app
            polyBW = self.applyPolygonsOrange(J,polyBW);

            % Combine both masks
            BW = sliderBW & polyBW;

            % Initialize output masked image based on input image.
            maskedRGBImage = RGB;

            % Set background pixels where BW is false to zero.
            maskedRGBImage(repmat(~BW,[1 1 3])) = 0;

        end

        function J = rotateColorSpaceOrange(self,I)

            % Translate the data to the mean of the current image within app
            shiftVec = [-0.077899 -0.040444 0.522805];
            I = I - shiftVec;
            I = [I ones(size(I,1),1)]';

            % Apply transformation matrix
            tMat = [0.284849 -0.788517 0.000000 0.214952;
                0.551820 0.407031 0.000000 -0.673644;
                0.000000 0.000000 -0.956380 9.160254;
                0.000000 0.000000 0.000000 1.000000];

            J = (tMat*I)';
        end

        function polyBW = applyPolygonsOrange(self,J,polyBW)

            % Define each manually generated ROI
            hPoints(1).data = [0.098205 -0.100163;
                0.167985 -0.025532;
                0.331699 -0.198362;
                0.251184 -0.496886;
                0.154565 -0.233713];

            % Iteratively apply each ROI
            for ii = 1:length(hPoints)
                if size(hPoints(ii).data,1) > 2
                    in = inpolygon(J(:,1),J(:,2),hPoints(ii).data(:,1),hPoints(ii).data(:,2));
                    in = reshape(in,size(polyBW));
                    polyBW = polyBW | in;
                end
            end

        end
        
        function [color, location] = findColorBall(self)
            
            imBall = self.getImage();  
            
            for c = 1:5
                %RED
                if c == 1
                    try 
                        disp('checking red');
                        % Threshold the image
                        [x,y] = self.createMaskRed(imBall);


                        xy = self.findLocation(y);

                        %check range
                        if xy(1) < 50 || xy(1) > 125 || xy(2) < -100 || xy(2) > 100
                            continue
                        end

                        color = 'red';
                        location = xy;
                        disp('red found');
                        break
                    catch
                        disp('no red found');
                        continue
                    end
                end %RED

                %YELLOW
                if c == 2
                    try 
                         disp('checking yellow');
                        % Threshold the image
                        [x,y] = self.createMaskYellow(imBall);


                        xy = self.findLocation(y);
                        %check range
                        if xy(1) < 50 || xy(1) > 125 || xy(2) < -100 || xy(2) > 100
                            continue
                        end

                        color = 'yellow';
                        location = xy;
                         disp('yellow found');
                        break
                    catch
                        disp('no yellow found');
                        continue
                    end
                end %YELLOW

                %GREEN
                if c == 3
                    try 
                         disp('checking green');
                        % Threshold the image
                        [x,y] = self.createMaskGreen(imBall);


                        xy = self.findLocation(y);
                        %check range
                        if xy(1) < 50 || xy(1) > 125 || xy(2) < -100 || xy(2) > 100
                            continue
                        end

                        color = 'green';
                        location = xy;
                         disp('green found');
                        break
                    catch
                        disp('no green found');
                        continue
                    end
                end %GREEN

                %ORANGE
                if c == 4
                    try 
                         disp('checking orange');
                        % Threshold the image
                        [x,y] = self.createMaskOrange(imBall);


                        xy = self.findLocation(y);
                        %check range
                        if xy(1) < 50 || xy(1) > 125 || xy(2) < -100 || xy(2) > 100
                            continue
                        end

                        color = 'orange';
                        location = xy;
                         disp('orange found');
                        break
                    catch
                        disp('no blue found');
                        continue
                    end
                end %ORANGE    
                %BLUE
                if c == 5
                    try 
                         disp('checking blue');
                        % Threshold the image
                        [x,y] = self.createMaskBlue(imBall);


                        xy = self.findLocation(y);
                        %check range
                        if xy(1) < 50 || xy(1) > 125 || xy(2) < -100 || xy(2) > 100
                            continue
                        end

                        color = 'blue';
                        location = xy;
                         disp('blue found');
                        break
                    catch
                        error('no balls chief');
                    end
                end %BLUE  
            end %FOR
            
            return
        end
        
        function xy = findLocation(self, image)
            
            F0CH = [0, 1, 0, 50;
            1, 0, 0, -100;
            0, 0, -1, 0;
            0, 0, 0, 1];
        
            %height of the ball in mm
            ballHeight = 10;

            %height of the camera in mm
            camHeight = 110;

            ratio = ballHeight/camHeight;

            %distance from the origin of the checker board to the camera (measured
            %along y-axis in mm
            camToBoardLen = 350;
            
            %convert to grey scale
            BW = rgb2gray( image );

            %fill in image
            fillI = imfill(BW,'holes');

            %find circle and centroid
            [centers, radii] = imfindcircles(fillI,[6 30]);
            centersStrong = centers(1,:);
            radiiStrong = radii(1);
            viscircles(centersStrong, radiiStrong,'EdgeColor','b');

            
            pw = pointsToWorld(self.cam_IS, self.cam_pose(1:3,1:3),self.cam_pose(1:3,4),[centers(1) centers(2)]);

            %y coordinate needs to be fixed for visual error
            pw = pw + (ratio * [125 - pw(1), camToBoardLen - pw(2)]);

            pos = F0CH*[pw(1); pw(2); 0; 1];
            
            xy = [pos(1), pos(2)];
            
            return
            
        end
        
        function [BW,maskedRGBImage] = createMaskBlue(self,RGB)
           %createMask  Threshold RGB image using auto-generated code from colorThresholder app.
            %  [BW,MASKEDRGBIMAGE] = createMask(RGB) thresholds image RGB using
            %  auto-generated code from the colorThresholder app. The colorspace and
            %  range for each channel of the colorspace were set within the app. The
            %  segmentation mask is returned in BW, and a composite of the mask and
            %  original RGB images is returned in maskedRGBImage.

            % Auto-generated by colorThresholder app on 02-Mar-2022
            %------------------------------------------------------


            % Convert RGB image to chosen color space
            I = rgb2hsv(RGB);

            % Define thresholds for channel 1 based on histogram settings
            channel1Min = 0.000;
            channel1Max = 1.000;

            % Define thresholds for channel 2 based on histogram settings
            channel2Min = 0.000;
            channel2Max = 1.000;

            % Define thresholds for channel 3 based on histogram settings
            channel3Min = 0.000;
            channel3Max = 1.000;

            % Create mask based on chosen histogram thresholds
            sliderBW = (I(:,:,1) >= channel1Min ) & (I(:,:,1) <= channel1Max) & ...
                (I(:,:,2) >= channel2Min ) & (I(:,:,2) <= channel2Max) & ...
                (I(:,:,3) >= channel3Min ) & (I(:,:,3) <= channel3Max);

            % Create mask based on selected regions of interest on point cloud projection
            I = double(I);
            [m,n,~] = size(I);
            polyBW = false([m,n]);
            I = reshape(I,[m*n 3]);

            % Convert HSV color space to canonical coordinates
            Xcoord = I(:,2).*I(:,3).*cos(2*pi*I(:,1));
            Ycoord = I(:,2).*I(:,3).*sin(2*pi*I(:,1));
            I(:,1) = Xcoord;
            I(:,2) = Ycoord;
            clear Xcoord Ycoord

            % Project 3D data into 2D projected view from current camera view point within app
            J = self.rotateColorSpaceBlue(I);

            % Apply polygons drawn on point cloud in app
            polyBW = self.applyPolygonsBlue(J,polyBW);

            % Combine both masks
            BW = sliderBW & polyBW;

            % Initialize output masked image based on input image.
            maskedRGBImage = RGB;

            % Set background pixels where BW is false to zero.
            maskedRGBImage(repmat(~BW,[1 1 3])) = 0;

            end

            function J = rotateColorSpaceBlue(self,I)

           % Translate the data to the mean of the current image within app
            shiftVec = [-0.064455 -0.036853 0.547833];
            I = I - shiftVec;
            I = [I ones(size(I,1),1)]';

            % Apply transformation matrix
            tMat = [0.627444 0.228948 -0.000000 -0.624525;
                -0.190722 0.741549 0.113513 -0.391227;
                -0.023906 0.092950 -0.905601 9.115128;
                0.000000 0.000000 0.000000 1.000000];

            J = (tMat*I)';
            end

            function polyBW = applyPolygonsBlue(self,J,polyBW)

            % Define each manually generated ROI
            hPoints(1).data = [-1.176898 -0.532912;
                -0.774742 -0.493949;
                -0.668289 -0.639177;
                -1.191092 -0.802115;
                -1.228942 -0.600213];

            % Iteratively apply each ROI
            for ii = 1:length(hPoints)
                if size(hPoints(ii).data,1) > 2
                    in = inpolygon(J(:,1),J(:,2),hPoints(ii).data(:,1),hPoints(ii).data(:,2));
                    in = reshape(in,size(polyBW));
                    polyBW = polyBW | in;
                end
            end

            end


    end
            


end


