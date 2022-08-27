function [Bat_Position_Vec] = Batflight()
% THIS Function simulates and plots a bat flght in a room 
% Types of movement:
% linear (Point 2 Point) - Constant Velocity, Constant angle (teta)
% Circles - Constant velocity and angular velocity (dteta)
% Eights - 
% RandomFlight (dvelocity, dteta are gausian variables)

% ObstaclesAVoidance - when the bat approaches obstacle it manuvers to avoid
% the hit
%  simulates 2d flight

%%%%%%%%%%%%%
% Simulation Paramaters
%%%%%%%%%%%%%
global Terrain;
global xyResolution;
global SampleTime;

xyResolution = 0.01; % 0.01=1cm
SimulationTime = 20; % Sec
SampleTime = 0.001; % 0.001= 1miliSec
NumOfSaples = SimulationTime/SampleTime; % The total number of samples
TimeVec= [0:SampleTime:SimulationTime];
AvoidObstacleFlag= true; % to manuver away from absticles
AnimationFlag = false; % Animate Bat Movement in time
DebugFlag = 1; % run more DATA for inside functin debug
%%%%%%%%%%%%%

%%%%%%%%%%%%%%
% The Terrain Parameters- closed room 10X10X10m with Rectanguler Obsticle
% if Terrain(x,y)= 0 - there is no obsticle at x,y
% if Terrain(x,y)= 1 - there is an obsticle at x,y
Xmax = 10; Ymax = 10; Zmax = 10; % meters
[Xcor, Ycor] = meshgrid(0:xyResolution:Xmax,0:xyResolution:Xmax);
Terrain = zeros( ceil(Xmax/xyResolution)+1 , ceil(Ymax/xyResolution)+1 );
Terrain(1,:)=1;  Terrain(end,:)=1;   Terrain(:,1)=1;   Terrain(:,end)=1; % Room Walls
TerrainLIMITS = size(Terrain);

% Rectangle Obsticle #1
XWidth = 0.5; YWidth = 1; % meters
DownLeftY = 2.5;DownLeftX = 3;% position of left buttom corner (meters)
xRect= [ ceil(DownLeftX/xyResolution) : (ceil(DownLeftX/xyResolution)...
+ ceil(XWidth/xyResolution)) ];
yRect= [ ceil(DownLeftY/xyResolution) : (ceil(DownLeftY/xyResolution)...
+ ceil(YWidth/xyResolution)) ];
Terrain(yRect,xRect) = 1;

% Rectangle Obsticle #2
XWidth = 2.5; YWidth = 3.5; % meters
DownLeftY = 5.5 ;DownLeftX = 6;% position of left buttom corner (meters)
xRect= [ ceil(DownLeftX/xyResolution) : (ceil(DownLeftX/xyResolution)...
+ ceil(XWidth/xyResolution)) ];
yRect= [ ceil(DownLeftY/xyResolution) : (ceil(DownLeftY/xyResolution)...
+ ceil(YWidth/xyResolution)) ];
Terrain(yRect,xRect) = 1;


% PLOT The Terrain 
close all
figure (1)
contour(Xcor,Ycor,Terrain)
axis([ -1,Xmax+1, -1, Ymax+1]);
xlabel('x [m]'); ylabel('y [m]');
title('The Room')
%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%
% BAT FLIGHT - Basic Parameters
MaxVelocity = 12 ; % m/s
NominalVelocity = MaxVelocity*0.25; % m/s 
MaxAccelaration = 20; % [m/sec^2] ~2g 
NominalAccel = MaxAccelaration*0.5; % m/s^2
MinDistanceAllowedM = 0.3; % [m] The minimum range the bat can be near Obsticle
FlightTypeFlag = 'linear'; % 'random' or 'linear' or 'circle'

% BAT SONAR BASIC
BatBeamWidth = pi/6; % radians
BatDetectionRange = 2; % meters
BatPRF = 25; % [1/sec] Trasmits per seconds
%%%%%%%%%%%%%%%%%%%%%%

% STARTING Point
StartX0 = 5; StartY0= 2; % meters
Teta0 = pi/4 ; % Direction in radian 
Accel0 = 0; % No accelaration
Dteta0 = 0; % straight Line

%%%%%%%%%%
% Position, Velocity and Time in Simulation Index (no units)
X0 = StartX0/xyResolution;
Y0 = StartY0/xyResolution;
V0 = NominalVelocity*SampleTime/xyResolution;
% DTETA = Omega*SampleTime;
% MaxdTeta = MaxOmega*SampleTime;
DetectionRange = BatDetectionRange / xyResolution;
RegTimeToSonar = 1/BatPRF/SampleTime; % regular- in free terrain
ManuverTimeToSonar = 1/BatPRF/SampleTime/10; % PRF when Manuvering
MinDistanceAllowed = MinDistanceAllowedM/xyResolution;
% Initial V0,Xbati,Ybati
% (xBati, yBati) - The position of the Bat in the simulation
Velocity = V0;
xBati= zeros(1,NumOfSaples); 
yBati= zeros(1,NumOfSaples); % Initial
xBati(1) = X0; 
yBati(1) = Y0;
%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%
% THE MAIN FUNCTION
%%%%%%%%%%%

Teta = Teta0*ones(1,NumOfSaples); % Initial Linear movement 
% DTetaManuever = 0; % Initial

    tTimeToSonar = 0; % Time to next search, at the start- SEARCH
    ManueverFlag = zeros(1,NumOfSaples); % Fector of the times when the bat avoids obticle
    SonarTimesVec = zeros(1,NumOfSaples); %Vector of the pulses time- zeros when no pulse transmittes
    % Help Vectors for debuggind
    if DebugFlag == 1
        IsFreeVec = ones(1,NumOfSaples);
        xFind = [];
        yFind = [];
    end % if DebugFlag
    
 if (AvoidObstacleFlag)     
    for nTime = [1:NumOfSaples]     %nTime- the time vector insample
        if tTimeToSonar == 0
            SonarTimesVec(nTime) = 1;
            [IsFREE,ObsRange,ObsAngle,NearestObsRange,NearestObsAngle] =...
                FindObsticle(xBati(nTime),yBati(nTime),Teta(nTime),...
                BatBeamWidth, DetectionRange, TerrainLIMITS); % % DetectionDistance,BatBeamWidth);
            % IsFREE= 1 if there is no obstacle
            % (ObsRAnge,ObsAngle) - vector of the positions of the obstcles
            % .. range and angle from the bat
            if (~IsFREE)
                 % The Position of the Obsicles found
                if DebugFlag == 1
                    IsFreeVec(nTime) = IsFREE;
                    xFind = [xFind, xBati(nTime)+ObsRange.*cos(Teta(nTime)+ObsAngle)];
                    yFind = [yFind, yBati(nTime)+ObsRange.*sin(Teta(nTime)+ObsAngle)];
                end %% if DebugFlag
                if NearestObsRange <= MinDistanceAllowed
                    ManueverFlag(nTime:nTime+ManuverTimeToSonar-1) = 1;  % if manuver is needed- keep manuver until the next pulse
                    tTimeToSonar = ManuverTimeToSonar; % while manuver allways check Distace
                else % if NearestObsRange
                    ManueverFlag(nTime) = 0;
                    DTetaManuever = 0;
                    tTimeToSonar = RegTimeToSonar; 
                end % if NearestObsRange
            end % if ~IsFree
        else % if tTimeToSonar is not zero  no search- continue to flight
%             tTimeToSonar = tTimeToSonar -1;
        end % if tTimeToSonar
        tTimeToSonar = tTimeToSonar -1;
        if tTimeToSonar == -1 
            tTimeToSonar = RegTimeToSonar;
        end % if tTimeToSonar
%         Movement of the BAT
        [xBati(nTime+1),yBati(nTime+1),Teta(nTime+1)] = BatMovemet(...
                xBati(nTime),yBati(nTime), Teta(nTime), FlightTypeFlag,...
                ManueverFlag(nTime), MaxAccelaration, V0,...
                NearestObsRange,NearestObsAngle) ;
    end  % for nTime - Time     
elseif (~AvoidObstacleFlag)% AvoidObstacle  - open Space movement
    Teta = Teta0; 
    ManueverFlag = 0;
    DTetaManuever = 0;
    NearestObsRange = 0;
    NearestObsAngle = 0;
    for nTime = [1:NumOfSaples]     %nTime- the time
%             [xBati(nTime+1),yBati(nTime+1),Teta(nTime+1)] =  ...
%              BatMovemet(xBati(nTime),yBati(nTime), Teta(nTime),FlightTypeFlag, ManueverFlag,...
%              DTetaManuever,DTETA, V0); 
         [xBati(nTime+1),yBati(nTime+1),Teta(nTime+1)] = BatMovemet(...
            xBati(nTime),yBati(nTime), Teta(nTime), FlightTypeFlag,...
            ManueverFlag, MaxAccelaration, V0,...
            NearestObsRange,NearestObsAngle) ;
        end % for nTime   
end % if Avoid Flag


%%%%%%%%%
% FindObsticle Function
%%%%%%%%%
function[IsFree,Distance,Alpha,NearestDistance,NearestAngle] = ...
        FindObsticle(xCurrent,yCurrent,AngleView,BeamWidth, ...
        DetectionDistance, LIMITS)
% This funtion will find if ther is an pbsticle in the detection range...
% and return the range and angle from the current point
% Outputs:
    % Isfree = 1 if there was no obstacle Found
    % Distance is the Distance between the bat and the obstacle
    % Alpha is the angle between the bat flight direction and the obstacle
    % NearestDitance is the Ditnce to the nearst obstacle from the bat or frrom
    % the bat direction flight
    % NearestAngle is the angle between the bat and the nearest obstacle  
% Inputs: 
    % xCurrent,yCurrent,AngleView - position and direction of the bat
    % BeamWidth, DetectionDistance - THe detection Sonar Beam-Width and
    % distance
    % global Terrain;
    
    dt=0.1; % the step size for the angle in radians
    Distance=zeros(1,ceil(BeamWidth/dt)); % INIT
    Alpha=zeros(1,ceil(BeamWidth/dt));%INIT
    n=0;  
    for ScanAngle = (AngleView-BeamWidth/2):dt:(AngleView+BeamWidth/2)
        for D = [0:DetectionDistance]
            tempY = round(yCurrent+D.*sin(ScanAngle));
            tempX = round(xCurrent+D.*cos(ScanAngle));
            % Check the limits of terrain
            if (tempY > LIMITS(1)) || (tempX > LIMITS(2)) 
                break
            elseif (tempY <= 0) || (tempX <=0)
                break
            end %limits
            % find obstacles in Terrain (the closest non-zeros at each alpha)
           if Terrain(tempY,tempX) ~= 0
              n=n+1;
              Distance(n) = D;
              Alpha(n) = ScanAngle-AngleView;
              break % finds only the closest obstacle for each alpha
           else
                
           end %if Terrain()
        end %D
    end %ScanAngle
    % Outputs
    if n > 0
        Distance = Distance(1:n);
        Alpha = Alpha(1:n);
        IsFree = 0; % There is an obstacle
%         ObsDistaneFromLinear = Distance.*abs(tan(Alpha)); % for calculates if we neend to mauver 
%         [NearestDistance,nn] = min(min(ObsDistaneFromLinear, Distance));
%         NearestAngle = Alpha(nn);
    else %if n=0  means it is free
        Distance = [];
        Alpha = [];
        IsFree = 1; % There is NO obstacle
        NearestDistance = [];
        NearestAngle = [];
    end % if n
  
end % FindObstacle Function



%%%%%%%%%
% BatMovemet Function
%%%%%%%%%

% function[xBNext,yBNext,TetaBNext] =  BatMovemet(xB,yB, TetaB, FlightType, ManFlag, DTetaMan, DTetaBat, Vel);
function[xBNext,yBNext,TetaBNext, ManFlag] = ...
        BatMovemet(xB,yB, TetaB, FlightType,, MaxAccel, CurrentVelocity,...
        ObsticleRange, ObsticleAngle,MinDistanceToManuever,IsFreeFlag)
% This funtion will calculate tne new position(x,y,teta) of the  bat
% output arguments: 
    % xBNext -the x coordinate ,  yBNext -the y coordinate , 
    % TetaBNext- the angle of the bat
    % ManFlag - the bat manuvers
% Inptus: 
    % xB,yB, TetaB- current position
    % Vel = teh velocity of the bat
    % FlightType = 'linear', 'lircle', random'
    % ManFlag, DTetaMan - flag weather to nmanuver, and teh differncial angle
    % DTetaBat =- the differntial angle of the bat ' from its accelartion
    % GLOBAL Terrain, xyResolution, SampleTime
    % ObstacleRange, ObstacleAngle - are the distance and angle betwin the
    % bat (or its path) and the obsicles found
    
    % Flight parameters
    KdTeta = 1;  % Parameter fo dteta
    StdRand = 1; % the STD of the random Flight
    MaxOmega = MaxAccel/CurrentVelocity; % Maximum Radian Velocity [rad/sec]
    MaxDTetaBat = MaxOmega*SampleTime; % the maximum chande in time-frame
    Kdt= 2; % parameter [1:5] -1 -the fastrst manuver 
    NominalDTetaBat = MaxDTetaBat/Kdt; 
    
    % calculations for manuever
    if (~IsFreeFlag)
        ObsDistaneFromLinear = Distance.*abs(tan(Alpha));
        [NearestDistance,nn] = min(min(ObsDistaneFromLinear, Distance));
        NearestAngle = Alpha(nn);
        if NearestDistance <= MinDistanceToManuever
                ManFlag = 1;  % if manuver is needed- keep manuver until the next pulse
                tTimeToSonar = ManuverTimeToSonar; % while manuver allways check Distace
            else % if NearestDistance
                ManFlag = 0; 
        end % if NearestDistance
    else % if (~IsFreeFlag)
       ManFlag = 0;
    end % if (~IsFreeFlag)
    if ManFlag == 0 % no need to manuver
        switch FlightType
            case 'linear'
                dTeta = 0; 
            case 'circle'
                dTeta =  NominalDTetaBat*KdTeta;
            case 'random'
               dTeta = NominalDTetaBat*StdRand*randn; 
            otherwise
                disp('other value')
        end % switch FlightType
    elseif ManFlag == 1
%         dTeta = DTetaMan;
        [NearestDistance,nn] = min(min(ObsDistaneFromLinear, Distance));
        NearestAngle = Alpha(nn);
        dTeta = -sign(ObsticleAngle)*NominalDTetaBat;
    end; % if ManFlag
    TetaBNext = TetaB+ dTeta;;
    xBNext = xB + CurrentVelocity.*cos(TetaBNext) ;
    yBNext = yB + CurrentVelocity.*sin(TetaBNext) ;
end% BatMovement Function

% % % Eight with lines
% % % Teta0 = 0; % Test
% % % Teta1 = -pi/18; % the straight Line direction
% % % dTetaFirstCycle = -1*SampleTime*ones(1,floor(abs(Teta1-Teta0)/Omega/SampleTime));
% % % Line = 2*(V0/Omega)/abs(tan(Teta1))/xyResolution;
% % % dTetaCycle = SampleTime*Omega*[...
% % %     zeros(1,floor(Line)),...
% % %     ones(1,floor((pi+abs(Teta1))/SampleTime)),...
% % %     zeros(1,floor(Line))...
% % %     -1*ones(1,floor((pi+abs(Teta1))/SampleTime))...
% % %     ];
% % % dTeta = [dTetaFirstCycle , dTetaCycle, dTetaCycle , dTetaCycle];



%%%%%%%%%
% Final DATA
%%%%%%%%%%

xBatPos = xBati*xyResolution;
yBatPos = yBati*xyResolution;
if (AvoidObstacleFlag) && (DebugFlag)
    xObsFinds = xFind*xyResolution;
    yObsFinds = yFind*xyResolution;
end % AvoidObs

% PLOTS
hold on
title('BAT Movement #1')
plot(xBatPos,yBatPos,'ok')
if (AvoidObstacleFlag)
    plot(xBatPos(find(SonarTimesVec)),yBatPos(find(SonarTimesVec)),'g*') % the position when sonar
%     plot(xObsFinds,yObsFinds,'+r')
end % AvoidObs


%%%%%%%%%%%%
% animation
%%%%%%%%%%%%
if AnimationFlag
     f1 = figure(2);
    subplot(2,1,1)
    contour(Xcor,Ycor,Terrain)
    axis([ -1,Xmax+1, -1, Ymax+1]);
    title('Bat Movement Animation')
    h = animatedline('Color','k'); % subplot(2,1,1)
    hprevoius = animatedline('Color','c'); % Show prev location
    axis([min(xBatPos),max(xBatPos),min(yBatPos),max(yBatPos)]);
    subplot(2,1,2)
    title('Bat Current Direction Animation')
    axis([0,SimulationTime,min(Teta)/pi,max(Teta)/pi+eps])
    g = animatedline; % subplot(2,1,2)
    
    TimeSpeed = 20; % THe higher TimeSpeed the faster simulation
    for n2Time = 2:TimeSpeed:length(TimeVec)
        figure(f1)
        subplot(2,1,1)
        hold on
        addpoints(hprevoius,xBatPos(max(1,n2Time-20)),yBatPos(max(1,n2Time-20)));
        drawnow
        addpoints(h,xBatPos(n2Time),yBatPos(n2Time));
        drawnow 
        subplot(2,1,2)
        addpoints(g,TimeVec(n2Time),Teta(n2Time)/pi);
        drawnow
    end
end % AnimationFlag
end % BatFlight Fuction :-)
    
    





