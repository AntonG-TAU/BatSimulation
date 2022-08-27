function [OutputData, varargout] = BatFlightForGui(varargin)

% BatFlightForGui(varargin) MATLAB code for BatGUI1
%      BatFlightForGui, calculates & creates the flight of the bat.
%
%      OutputData =  BatFlightForGui() returns the Struct of the 
%       data calculated for the bat with default parameters and empty room terrain.
%
%      BatPos =  BatFlightForGui(AllParams) returns the vecor of the 
%       position of the bat with AllParams parameters in empty room terrain.
%
%      BatPos =  BatFlightForGui(AllParams,Terrain) returns the vector of the 
%      position of the bat with the parameters AllParams in the desired Terrain.
%
%      [BatPos, SonarTimesVec] =  BatFlightForGui()- returns the bat position
%      and the timesthe bat transmit pulses.
%
%      [BatPos, SonarTimesVec, ManuversTime] = =  BatFlightForGui() returns
%      also the times the bat is manuevering- hunting or avoiding obsticles
%  Outputs:
%   OutputData - A STRUCT with the data calculated:
%         OutputData.BatPos = [xBatPos ; yBatPos]; - The Position of the
%         Bat
%         OutputData.SonarTimesVec = SonarTimesVec; - the Times the bat
%         ransmitted a sonar pulse. '1' if there was a pulse at that sample
%         time, '0'  if none.
%         OutputData.ObsManueverFlag = ObsManueverFlag; -times the bat
%         manvuevers to avoid obsticle, '1' / '0'
%         OutputData.HuntingFlag = HuntingFlag; - Times the bat manuevres
%         to hunt prey/ '1' / '0'
%         OutputData.ObsticlesFound.ObsTimes = IsObsVec; - Times the bat
%         finds OBsticle
%         OutputData.ObsticlesFound.ObsPos = [xObsFinds ; yObsFinds]; -
%         thePlaces of the Obsticles found an estimated by the bat
%         % OutputData.PreyFound.PreyTimes = IsPreyVec; - Times the bat
%         finds Prey
%         % OutputData.PreyFound.PreyPos = [xPreyFinds ; yPreyFinds]; - the 
%           Positions of the prey found an estimated by the bat
%          OutputData.PulseWidthVec - the time period of each
%          sonar pulse
%           OutputData.BatDirection = Teta; 

%  Inputs:
%    Terrain :the Terrain Matrix
% 
%     AllParams: a STRUCT with the following vaiables: (if default)
%           AllParams.SimParams :
    %           xyResolution: 0.0100
    %           SimulationTime: 20
    %           SampleTime: 1.0000e-04
    %           AvoidObsticleFlag: 1
    %           AnimationFlag: 1
    %           DebugFlag: 1
%     AllParams.BatFlight :
%           MaxVelocity: 6
%           NominalVelocity: 1.5000
%           MaxAccelaration: 20
%           NominalAccel: 10
%           MinDistanceAllowed: 0.1000
%           FlightTypeFlag: 'random'
%     AllParams.BatSonar :
%           BatBeamWidth: 0.5236
%           BatDetectionRange: 2
%           BatInterferenceRange: 16
%           BatNominalPRF: 20
%           BatMaxPRF: 100
%           PulseTimeLong: 0.0030
%           PulseTimeShort: 1.0000e-03
%           BandWidth: 1
%           CenterFreq: 80
%
%   Should Be All Versions 04Nov21_omer
%   Nov2021

warning('off', 'signal:findpeaks:largeMinPeakHeight')
warning('off', 'MATLAB:catenate:DimensionMismatch')
warning('off', 'MATLAB:inpolygon:ModelingWorldLower')
warning('off', 'MATLAB:polyshape:repairedBySimplify')
warning('off', 'MATLAB:polyshape:boolOperationFailed')


NofInputs = nargin;

switch NofInputs
    case 0
%         Params = CreateSimDefaultParams();
        filename ='DATA\DefaultParamsTable.xlsx';
        Params   = ReadDefaultParamsTable(filename);
        AllParams.SimParams        = Params.SimParams;
        AllParams.BatFlightParams  = Params.BatFlight;
        AllParams.BatSonarParams   = Params.BatSonar;
        AllParams.TerrainParams    = Params.Terrain;
        AllParams.PreyFlightParams = Params.PreyFlight;
        [Terrain, Xmax,Ymax,Zmax, Xmin, Ymin, Zmin] =...
            BuildEnvironment(AllParams.TerrainParams,...
                    AllParams.SimParams.xyResolution,'Empty Room');
    case 1
        AllParams = varargin{1};
        [Terrain, Xmax,Ymax,Zmax, Xmin, Ymin, Zmin] = ...
            BuildEnvironment(AllParams.TerrainParams,...
                AllParams.SimParams.xyResolution,'Empty Room');
    case 2
       AllParams = varargin{1};
        Terrain =  varargin{2};
        Xmax =  AllParams.TerrainParams.Xmax;
        Ymax =  AllParams.TerrainParams.Ymax;
        Zmax =  AllParams.TerrainParams.Zmax;
        Xmin =  AllParams.TerrainParams.Xmin;
        Ymin =  AllParams.TerrainParams.Ymin;
        Zmin =  AllParams.TerrainParams.Zmin;
end % switch

NumOfOutputs = nargout;

%%%%%%%%%%%%%
% Simulation Paramaters
%%%%%%%%%%%%%
xyResolution      = AllParams.SimParams.xyResolution; 
SimulationTime    = AllParams.SimParams.SimulationTime; 
SampleTime        = AllParams.SimParams.SampleTime; 
NumOfSamples      = floor(SimulationTime/SampleTime); % The total number of samples
% TimeVec= 0:SampleTime:SimulationTime;
AvoidObsticleFlag = AllParams.BatFlightParams.AvoidObsFlag; % to manuver away from absticles
IsAnyPreyFlag     = AllParams.SimParams.IsPreyFlag;
SoundV0           = AllParams.SimParams.SoundV0; % Sound velocity
NumberOfBats      = AllParams.SimParams.TotalBatsNumber;
NumberOfPreys     = AllParams.SimParams.TotalPreysNumber;

% New Vars Nov2021
%%% FULL Acoustic Signal Nov2021
if isfield(AllParams.SimParams, 'FsAcoustic')
    FsAcoustic = AllParams.SimParams.FsAcoustic;
else
    FsAcoustic = 200e3;
end % if isfield(AllParams.SimParams, 'FsAcoustic')

if ~isfield(AllParams.SimParams, 'AcousticsCalcFlag')
    AllParams.SimParams.AcousticsCalcFlag = 0;
end
if ~isfield(AllParams.SimParams, 'DetectConsps')
    if strcmp(AllParams.SimParams.TestMode, 'swarm')
        AllParams.SimParams.DetectConsps = 1;
    else
        AllParams.SimParams.DetectConsps = 0;
    end % if strcmp
end
if ~isfield(AllParams.SimParams, 'DetectObs')
    AllParams.SimParams.DetectObs = 0;
end
if ~isfield(AllParams.SimParams, 'DetectPrey')
    AllParams.SimParams.DetectPrey = 1;
end
AcousticNumel = FsAcoustic*AllParams.SimParams.SimulationTime + 1;


plot_flag = 0;

% TimeIntervalForMoveCalc = 1e-3; % SampleTime; % Determine the interval of the movement of the bat and prey
% KSamplesForMove = floor( TimeIntervalForMoveCalc / SampleTime ); 
%%%%%%%%%%%%%%%%%%%
% BAT FLIGHT - Basic Parameters
MaxVelocity = AllParams.BatFlightParams.MaxVelocity ; % m/s
NominalVelocity = AllParams.BatFlightParams.NominalVelocity; % m/s 
MaxAccelaration = AllParams.BatFlightParams.MaxAccelaration;
NominalAccel = AllParams.BatFlightParams.NominalAccel;
MinDistanceAllowedM = AllParams.BatFlightParams.MinDistanceAllowed;
FlightTypeFlag = AllParams.BatFlightParams.FlightTypeFlag;
PreyHuntingFlag = AllParams.BatFlightParams.PreyHuntingFlag;
minCatchPreyDistance = AllParams.BatFlightParams.minCatchPreyDistance;
%%%%%%%%%%%%%%
% BAT SONAR Paramaters

%%% update parameters for special modes
% switch AllParams.SimParams.TestMode
%     case 'swarm'
%        echolocation_params =  load('D:\Omer\BatSimulation\All Directories_backup\Bat Simulation Emerging Swarm\DATA\Rhinoporma_echolocation.mat');
%        echolocation_params = echolocation_params.Rhinoporma_echolocation;
%        AllParams.BatSonarParams.IPI_Search = echolocation_params.SearchIPI;
%        AllParams.BatSonarParams.ChirpSpan_Search = echolocation_params.SearchBW;
%        AllParams.BatSonarParams.TerminalFreq = echolocation_params.SearcTerminalFreq;
%        
%     case 'foraging'
%         
%     otherwise
%         
% end % switch AllParams.SimParams.TestMode

BatBeamWidth      = AllParams.BatSonarParams.BatBeamWidth;
BatDetectionRange = AllParams.BatSonarParams.BatDetectionRange;
BatNominalPRF     = AllParams.BatSonarParams.BatNominalPRF; 
BatMaxPRF         = 1/(AllParams.BatSonarParams.IPI_BuzzStart*1e-3) * 2 ; %% NEw-Swarm, OLD: AllParams.BatSonarParams.BatMaxPRF; 
BatLongPulse      = AllParams.BatSonarParams.PulseTimeLong;
BatShortPulse     = AllParams.BatSonarParams.PulseTimeShort;
CenterFreq        = AllParams.BatSonarParams.CenterFreq;
ChirpFlag         = AllParams.BatSonarParams.ChirpFlag;
ChirpSpan         = AllParams.BatSonarParams.ChirpSpan*ChirpFlag; % zero if not chirping
PulseDetectionTH  = AllParams.BatSonarParams.PulseDetectionTH;
UniqueFreqsFlag   = AllParams.BatSonarParams.UniqueFreqsFlag; % 'Random'/ 'MaxDiff'
% ObsMemSize        = AllParams.BatSonarParams.ObsMemorySize; % number of relvant pulses to count

% % % PulseDetectionTH = -120; %dB the mininuump puls energy that can be detected
% CreateSonarPulseOnlineFlag= 1;
PulsePower = AllParams.BatSonarParams.PulsePower;
% PulseMinPower = AllParams.BatSonarParams.PulseMinPower;

% NoiseLevel = 0.1;
NoiseLevel = 10.^(AllParams.BatSonarParams.NoiseLeveldB/20); % for Acousitcs

%%%% Classifier PreyItems
PreyGlintTime = AllParams.BatSonarParams.PreyGlintTime;


%%%%%%%%%%%%%%
% Prey Flight Parameters
PreyMaxVelocity = AllParams.PreyFlightParams.PmaxVelocity ; % m/s
PreyNominalVelocity = AllParams.PreyFlightParams.PNominalVelocity; % m/s 
PreyMaxAccelaration = AllParams.PreyFlightParams.PMaxAccelaration;
PreyNominalAccel = AllParams.PreyFlightParams.PNominalAccel;
PreyMinDistanceAllowedM = AllParams.PreyFlightParams.PMinDistanceAllowed;
PreyFlightTypeFlag = AllParams.PreyFlightParams.PFlightTypeFlag;


%%%%%
% TERRAIN Parameters
% TerrainLIMITS = size(Terrain);
PMinDist = AllParams.PreyFlightParams.PMinDistanceAllowed;
% LIMITS of the Room
minX = (Xmin) / xyResolution;
maxX = (Xmax) / xyResolution;
minY = (Ymin) / xyResolution;
maxY = (Ymax) / xyResolution;
RoomLimits= [minX, minY, maxX, maxY];

%%% New Jun2022
for k = 1:2:size(Terrain,1)-1
    polyTerrain{k} = polyshape( Terrain(k,:),Terrain(k+1,:));
end 


% Position, Velocity and Time in Simulation Index (no units)
V0 = NominalVelocity*SampleTime/xyResolution;
PreyV0 = PreyNominalVelocity*SampleTime/xyResolution;
DetectionRange = BatDetectionRange / xyResolution;
xySoundVelocity = SoundV0*SampleTime/xyResolution;
RegTimeToSonar = 1/BatNominalPRF/SampleTime; % regular- in free terrain
MinTimeToSonar = 1/BatMaxPRF/SampleTime; % PRF when hunting
StepPRF = (RegTimeToSonar- MinTimeToSonar)./10; % The Steps for calculating PRFs when the manuervers
LongPulse = BatLongPulse/SampleTime;
ShortPulse = BatShortPulse/SampleTime;
CurrentPulseWidth = LongPulse;
StepPulseTime=  (LongPulse- ShortPulse)./10;
MinDistanceAllowed = MinDistanceAllowedM/xyResolution;
PreyMinDistanceAllowed = PreyMinDistanceAllowedM/xyResolution; 
minCatchPreyDistanceXY = minCatchPreyDistance / xyResolution;
ProbToDetect = AllParams.BatSonarParams.ProbToDetect;
NPulsesBack = AllParams.BatFlightParams.HuntedMemorySize;

% Sonar Parametes
SensorAnalyzeDelay = 1e-3/SampleTime; % 1 msec Latency for analyzing the DATA from the Pulse
PulseRecievedTimeToAnalyze = 2*DetectionRange/xySoundVelocity + SensorAnalyzeDelay; 
% PulseRecievedTimeToAnalyze is the maximum time from the farest target
    % from the bat, for star is twice max detection_distance/ sound_velocity


%%% Initial General Parmaters %%%
MaxNumberOfPulses = ceil(NumOfSamples/MinTimeToSonar)*2; % the Maximum numer of pulses in the simulaton
% EchosStructBuild - contain the echos from prey and from obs

% EchosStructBuild(MaxNumberOfPulses) = struct('NumOfEchos',[],'EchosTimes',[], 'EchosAttenuation',[],...
%     'TransmittedPulseTime',[], 'EchosAngles',[],'TargetIndex',[], 'EchosCenterFreq',[], 'TransmittedPulseNum',[]); 

% FindsStructBuild(MaxNumberOfPulses) = struct('nTimesFinds',[],...
%     'xFinds',[], 'yFinds',[], 'TotalNumOfTimesFinds',[],'PreyNum',[]) ;

TransmittedPulsesStruct(MaxNumberOfPulses) = ...
        struct('PulseNum',[] ,'PulsePower',[] , 'StartPulseTime',[], ...
            'PulseWidth',[], 'ChirpMinMaxFreqs',[], 'PulseFreqsCommands' ,[],'IPItoNextPulse',[] ,... % XXXX AcousticSig Nov2021
            'PulseDuration', [], 'ManueverTypePower', [], 'JARPulsesLeft',  [], ...
            'TxAcousticSig', [], 'PreyAcousticSignature', []);
        
% Vector2Preys(NumberOfPreys) = struct('Dist2Prey',[] , 'Angle2Prey',[]);

%%% JAR MODE %%%% 
IsJarModeNotExist = isempty( find(strcmp('JARMode',...
    fields(AllParams.BatSonarParams)),1) );
if IsJarModeNotExist
    AllParams.BatSonarParams.JARMode = 0; 
end % if  IsJarModeExist

%%% Bi-Stat Detection MODE %%%% 
% AllParams.BatSonarParams.BiStatMode = 1;
IsBiStatNotExist = isempty( find(strcmp('BiStatMode',...
    fields(AllParams.BatSonarParams)),1) );
if IsBiStatNotExist
    AllParams.BatSonarParams.BiStatMode = 0; 
end % if  IsJarModeExist

%%% React to conspecific behavior %%%
if sum( strcmp('ReactToBatsFlag', fields(AllParams.BatFlightParams)) ) == 0
    AllParams.BatFlightParams.ReactToBatsFlag = 0; 
end % if  React to conspecific behavior

%%% Phantom Echoes from conspecifics Mode %%%
if sum( strcmp('ReactToBatsFlag', fields(AllParams.BatFlightParams)) ) == 0
    AllParams.BatSonarParams.PhantomEchoesFromConsFlag = 0;
end % if Phaantom Echoes

%% Filter Bank  %%%%

FilterBankFlag = 0;
if strcmp(AllParams.BatSonarParams.ReceiverType, 'FilterBank')
    %%% create the impulse respnse of each filter and its main parametes
    Is_fb_nomask_exist = ~isempty( find(strcmp('FilterBank_NoMasking_Flag',...
        fields(AllParams.BatSonarParams)),1) );
    if Is_fb_nomask_exist
        FilterBank_NoMasking_Flag = AllParams.BatSonarParams.FilterBank_NoMasking_Flag;
    else % if Is_fb_nomask_exist
        FilterBank_NoMasking_Flag = 0;
    end % if Is_fb_nomask_exist
    
    FilterBankFlag = 0; % 1 Chhanged on Nov2021
    filterbank_fs_ts =  AllParams.BatSonarParams.FilterBank_Fs * AllParams.SimParams.SampleTime;
    FilterBank =  ...  % FilterBank_Resp %%% Nov2021
        FilterBank_Acous_Resp(AllParams.BatSonarParams.FilterBank_FiltNum, ...
        FsAcoustic, ....   % old : AllParams.BatSonarParams.FilterBank_Fs, ...
        AllParams.BatSonarParams.FilterBank_FreqLow*1000, ...
        AllParams.BatSonarParams.FilterBank_FreqHigh*1000, ...
        AllParams.BatSonarParams.FilterBank_ImpluseRespDuration, ...
        AllParams.BatSonarParams.FilterBank_FreqRes*1000);
    FilterBank.CrossTalkFlg = 1;
    filter_fc = FilterBank.filter_fc;
    %%%% NOV 2021 = To be Removed
%     FilterBank_NumOfSamples = AllParams.BatSonarParams.FilterBank_Fs*SimulationTime + ...
%         numel(FilterBank.filter_timevec) + 1; % Total
%     FilterBank_Fs = AllParams.BatSonarParams.FilterBank_Fs;
%     FilterBank_Ts = 1/FilterBank_Fs; %sec
%     
%     maxPulseSamples_Hr = AllParams.BatSonarParams.PulseDuration_Search * ...
%              1e-3 * FilterBank_Fs;
%     % the duration of the updter vectors in each pulse 
%     FilterBank.time_to_analyze_us = AllParams.BatSonarParams.IPI_Search*1e-3*FilterBank_Fs;
%     det_method = 'Integrated' ; % 'Fcs'- histogram of detections in channels , 'Integrated' - ingration of the channels and than decision 
    %%%% NOV 2021 = To be Removed %%%%%%%%%%
    
    warning('off', 'signal:findpeaks:largeMinPeakHeight')
    warning('off', 'MATLAB:catenate:DimensionMismatch')
% % %     noise_mat = NoiseLevel*randn(numel(FilterBank.fft_freqs), 5*FilterBank.time_to_analyze_us);
         
else % if strcmp(AllParams.BatSonarParams.ReceiverType, 'FilterBank')
    FilterBank = struct();
    
end %% FilterBank
%% 
%% Initial PREY STRUCT %%%

PreyDecisionTime = AllParams.PreyFlightParams.DecisionPeriod; % New Jamming Moth

Vector2Preys(max(1, NumberOfPreys)) = struct('Dist2Prey',[] , 'Angle2Prey',[]);
PREY(max(1, NumberOfPreys)) = struct('PreyX0',[], 'PreyY0',[], 'PreyTeta0',[], 'PreyDteta',[], 'PreyT0',[],...
    'xPrey',[], 'yPrey',[],  'PreyTeta',[], 'PreyPos',[] );
PreysCurrentPos = ones(NumberOfPreys,5);% a matrix of the preys- each row- locations in each time - x,y,teta,vel
for PreyNum = 1:NumberOfPreys
    PREY(PreyNum).IsCaught = 0;
    PREY(PreyNum).CaughtTime = 0;
    [ PREY(PreyNum).PreyX0, PREY(PreyNum).PreyY0, PREY(PreyNum).PreyTeta0, PREY(PreyNum).PreyT0] = ...
        InitPosition(RegTimeToSonar, Xmax, Ymax, xyResolution, Terrain, AllParams, 'Prey', PreyNum);
    PREY(PreyNum).PreyDteta = zeros(1,NumOfSamples+1);
    PREY(PreyNum).xPrey = zeros(1,NumOfSamples+1);
    PREY(PreyNum).yPrey = zeros(1,NumOfSamples+1);
    PREY(PreyNum).PVelocity = zeros(1,NumOfSamples+1);
    PREY(PreyNum).xPrey(1:PREY(PreyNum).PreyT0) = PREY(PreyNum).PreyX0;
    PREY(PreyNum).yPrey(1:PREY(PreyNum).PreyT0) = PREY(PreyNum).PreyY0;
    PREY(PreyNum).PVelocity(1:PREY(PreyNum).PreyT0) = PreyV0 + 0.1*PreyV0*randn(1,1);
    PREY(PreyNum).PreyTeta = PREY(PreyNum).PreyTeta0*ones(1,NumOfSamples+1); % Initial Linear movement
    PreysCurrentPos(PreyNum,:) = ...
        [PreyNum, PREY(PreyNum).PreyX0, PREY(PreyNum).PreyY0, PREY(PreyNum).PreyTeta0, PREY(PreyNum).PVelocity(1)];
    PREY(PreyNum).ChangeDirectionCommand = 0;
    PREY(PreyNum).nToChangeDirection = 0;
    PREY(PreyNum).nToDeicide = 0;
    % Prey Rx Echolocation Calls
    % NEw Apr2022 - Jam_Moth XX
    PREY(PreyNum).RxnTimes       = [];
    PREY(PreyNum).RxLvls         = [];
    PREY(PreyNum).RxBatNumTx     = [];
    PREY(PreyNum).RxBatPulseNum  = [];
    PREY(PreyNum).JammingCommand = []; 
    PREY(PreyNum).JammingnTimes  = []; 

    % Initial Distance and Angle form Bats
    Vector2Preys(PreyNum).Dist2Prey = 10* ones(1,NumOfSamples+1);
    Vector2Preys(PreyNum).Angle2Prey = 4*pi * ones(1,NumOfSamples+1);
end %for PreyNum = 1:NumberOfPreys


%% Initial BAT STRUCT %%%

BAT(NumberOfBats) = struct( );
for BatNum = 1:NumberOfBats
    [BAT(BatNum).BatX0, BAT(BatNum).BatY0, BatTeta0, BatT0] = ...
        InitPosition(RegTimeToSonar, Xmax, Ymax, xyResolution, Terrain, AllParams, 'Bat', BatNum);
    BAT(BatNum).xBati = zeros(1,NumOfSamples+1);
    BAT(BatNum).yBati = zeros(1,NumOfSamples+1);
    BAT(BatNum).xBati(1:BatT0) = BAT(BatNum).BatX0;
    BAT(BatNum).yBati(1:BatT0) = BAT(BatNum).BatY0;
    BAT(BatNum).BatT0 = BatT0;
    BAT(BatNum).Teta = BatTeta0*ones(1,NumOfSamples+1); % Initial Linear movement
    BAT(BatNum).BatDteta = zeros(1,NumOfSamples+1);
    BAT(BatNum).BatVelocity = V0*ones(1,NumOfSamples+1);
    BAT(BatNum).ObsManueverFlag = zeros(1,NumOfSamples+1);
    BAT(BatNum).HuntingFlag = zeros(1,NumOfSamples+1);
    BAT(BatNum).HuntedPrey = zeros(1,NumOfSamples+1);
    BAT(BatNum).Vector2Preys = Vector2Preys;
    BAT(BatNum).CatchPreyTimes =  zeros(1,MaxNumberOfPulses); %The times the bat catches prey
    BAT(BatNum).CatchPreyPos = zeros(MaxNumberOfPulses,2); % The position of the catch
    BAT(BatNum).SonarPulses = zeros(1,NumOfSamples+1); %Vector of the pulses transmitting time- zeros when no pulse transmitted% 
%     BAT(BatNum).EchosFromObsStruct = EchosStructBuild;
%     BAT(BatNum).EchosFromPreyStruct = EchosStructBuild;
    BAT(BatNum).PulseFreqsCommand = CalcFreqsForPulse(CurrentPulseWidth, CenterFreq, ChirpSpan, 'Logarithmic');     
    BAT(BatNum).PRFVec = zeros(1,NumOfSamples+1);
    BAT(BatNum).PulsePower = PulsePower;
    BAT(BatNum).PulsePowerVec = zeros(1,NumOfSamples+1);
    BAT(BatNum).PulseWidthVec = zeros(1,NumOfSamples+1); 
    BAT(BatNum).PulseCurrFreqVec = zeros(1,NumOfSamples+1);
   
    
    BAT(BatNum).EchosFromPreyStruct(MaxNumberOfPulses) = struct(...
        'NumOfEchos',[],...
        'PulseDuration',[],...
        'EchosTimes',[],...
        'EchosAttenuation',[],...
        'EchoDetailed',[],...
        'TransmittedPulseTime',[],...
        'EchosAngles',[],...
        'EchosmDistances',[],...
        'TargetIndex',[],...
        'EchosCenterFreq',[],...
        'TransmittedPulseNum',[]);
    
    BAT(BatNum).EchosFromObsStruct(MaxNumberOfPulses) = ...
        BAT(BatNum).EchosFromPreyStruct(MaxNumberOfPulses);
    
    BAT(BatNum).PreyFindsStruct(MaxNumberOfPulses) = struct(...
        'TransmittedPulseNum',[],...
        'IsAnyPreyDetected', 0,...
        'DetectedPreyNum',[],...
        'DetectedTimes',[],...
        'xFinds', [],...
        'yFinds', [],...
        'PreyNumToHunt',0,...
        'DetecectedPreyWithOutInterference', [],...
        'DetectedTimesWithOutInterfernece', [], ...
        'MissedPreysByProbabilty', [],...
        'MaskedPreys',[],...
        'Dist2DetectedPrey', [], ...
        'Angle2DetectedPrey', [],...
        'RxPowerOfDetectedPreys', [],...
        'SIROfDetectedPreys', [],...
        'SelfCorrealationMaxdB', [],...
        'InterCorrelationMaxdB', [],...
        'DetectionsDFerror', [],...
        'DetectionsRangeErr', [], ...
        'DetectionsRelativeDirectionErr', [], ...
        'IsHuntedPreyMasked', 0, ...
        'BiSonarDetection', 0, ....
        'BiSonarPreyToHunt', 0, ...
        'BiSonarAngle2Prey', 0, ...
        'BiSonarDist2Prey', 0, ...
        'PhantomIsDetected', 0, ...
        'PhantomPreyNum', 0, ...
        'PhantomRxTime', [], ...
        'PhantomEstimatedDistance', [], ...
        'PhantomRealDistance', [], ... 
        'PhantomEstimatedAngle', [], ...
        'PhantomMaxRxPowerDB',  [], ...
        'PhantomPhaseSignal',[], ...
        'FB_unmasked_prey', [], ...
        'FB_unmasked_delays', [], ...
        'FB_detected_masking_delays', [], ...
        'FB_estimated_masker', [], ...
        'ClutteredPrey', [], ...
        'Clutter_nTimes', [] ...
        );
    
    BAT(BatNum).ObsFindsStruct(MaxNumberOfPulses) = BAT(BatNum).PreyFindsStruct(MaxNumberOfPulses);    
    BAT(BatNum).ObsFindsStruct(MaxNumberOfPulses).Angles = [];
    BAT(BatNum).ObsFindsStruct(MaxNumberOfPulses).Distances = [];

    BAT(BatNum).FindsMaskingStruct(MaxNumberOfPulses) = struct(...
        'PulseNum', [],...
        'DetectedPreys', [],...
        'DetectedPreysRxPower', [],...
        'IsAnyPreyMasked', [],...
        'MaskedPreys', [],...
        'masked_prey_idx',[] , ...
        'TotalMaskingTimes', [],...
        'IsCoverTimeJamFlag', [],...
        'CoverTimeJamTimes', [],...
        'IsFwdMaskingJamFlag', [],...
        'FwdMaskingJamTimes', [],...
        'DetecetedPrey2InterferenceRatioDB', [],...
        'SelfCorrealationMaxdB', [], ...
        'InterCorrelationMaxdB', [], ...
        'Ref_MaskedPreys', [],...
        'Ref_TotalMaskingTimes', [],...
        'Ref_FwdMaskingJamTimes', [],...
        'Ref_DetecetedPrey2InterferenceRatioDB', [],...
        'DetectionsDFerror', [],...
        'DetectionsRangeErr', [],...
        'DetectionsRelativeDirectionErr', [], ...
        'InterMinFreq', [], ...
        'InterBW', [], ...
        'InterBatNum', [], ...
        'FB_unmasked_prey', [], ...
        'FB_unmasked_delays', [], ...
        'FB_unmasked_times',[], ...
        'FB_detected_masking_delays', [], ...
        'FB_detected_masking_powers', [] , ...
        'FB_detected_Prey_times', [] , ...
        'FB_estimated_masker', [], ...
        'ClassifierMissedTargets', [], ...
        'ClassifierMaskedTargets', [] ,...
        'DetectionMaskedTargets', [] , ....
        'ClassifierMaskedTimes', [] ,...
        'ClassifierFalseAlarmsTimes', [] ,...
        'ClassifierFalseAlarmsDistances', [] ,...
        'ClassifierFalseAlarmsDOA', [] , ...
        'ClassifierDetecdtedAndTRUE', [], ...
        'ClassifierFullResults', [] ...
        );
    
    %%% PreyFindsStruct_Acous - NOV2021
    if  AllParams.SimParams.AcousticsCalcFlag
        BAT(BatNum).FindsMaskingStruct_Acoustics(MaxNumberOfPulses) = struct(...
            'PulseNum', [], ...
            'DetectedPreys', [],...
            'DetectedPreysRxPower', [], ...
            'CorrelationMissedTargetd', [], ...
            'IsAnyPreyMissedByCorr', ~[], ...
            'IsAnyPreyMasked', [], ...
            'MaskedPreys', [], ...
            'masked_prey_idx',[] , ...
            'TotalMaskingTimes', [], ...
            'AcousticMaskingTimes', [], ...
            'IsCoverTimeJamFlag' , [],...
            'CoverTimeJamTimes' , [], ...
            'IsFwdMaskingJamFlag', [],...
            'FwdMaskingJamTimes', [] ,...
            'DetecetedPrey2InterferenceRatioDB', [], ...
            'SelfCorrealationMaxdB', [], ...
            'InterCorrelationMaxdB', [], ...
            'Ref_MaskedPreys', [],  ...
            'Ref_TotalMaskingTimes', [], ...
            'Ref_FwdMaskingJamTimes', [], ...
            'Ref_DetecetedPrey2InterferenceRatioDB', [],...
            'DetectionsDFerror', [],...
            'DetectionsRangeErr', [],...
            'DetectionsRelativeDirectionErr', [], ...
            'InterMinFreq', [], ...
            'InterBW',   [], ...
            'InterBatNum', [], ...
            'FB_unmasked_prey', [], ...
            'FB_unmasked_delays', [], ...
            'FB_unmasked_times',[], ...
            'FB_detected_masking_delays', [], ...
            'FB_detected_masking_powers', [] , ...
            'FB_detected_Prey_times', [] , ...
            'FB_estimated_masker', [], ...
            'ClassifierMissedTargets', [], ...
            'ClassifierMaskedTargets', [] ,...
            'DetectionMaskedTargets', [] , ....
            'ClassifierMaskedTimes', [] ,...
            'ClassifierFalseAlarmsTimes', [] ,...
            'ClassifierFalseAlarmsDistances', [] ,...
            'ClassifierFalseAlarmsDOA', [] ,...
            'ClassifierDetecdtedAndTRUE', [], ...
            'ClassifierFullResults', [] ...
            );

            BAT(BatNum).FindsMaskingStruct = BAT(BatNum).FindsMaskingStruct_Acoustics ;

    end % if AllParams.SimParams.AcousticsCalcFlag
    
    
    %%% Conspecics- 'Swarm'
%     Test if chane Nov2021
    if strcmp(AllParams.SimParams.TestMode, 'swarm') || AllParams.SimParams.DetectConsps
        BAT(BatNum).EchosFromConspStruct(MaxNumberOfPulses) = ...
            BAT(BatNum).EchosFromPreyStruct(MaxNumberOfPulses);
        BAT(BatNum).Consps_MaskingStruct = BAT(BatNum).FindsMaskingStruct;
        BAT(BatNum).Consps_FindsStruct = BAT(BatNum).PreyFindsStruct;
    end % if strcmp(AllParams.SimParams.TestMode, 'swarm')
    
    BAT(BatNum).ManueverCmdStruct(1) = struct(... % default parmeters for the first Cmd
        'PulseNumToAnalyze',1 , ...
        'ManueverStage', 'Search' , ... % 'Search' / 'Approach' /'Buzz' / 'ObsManuever' / 'AvoidBatMan'
        'ManueverType', 'Foraging', ... % 'Hunting', 'Foraging', 'ObsMan', /'AvoidBatMan' 
        'ManueverPower','RegularForaging', ... %  'RegularForaging' / 'RegularHunt' or 'Buzz' /  'RegularManuever' or 'CrushAvoidance' / 'RegularBatAvoid'
        'PreyNumToHunt', 0, ...
        'Dist2HuntedPrey', nan, ...
        'Angle2HuntedPrey', nan, ...
        'PreyRelativeDirection', nan, ...
        'LastNDetections', zeros(1, NPulsesBack), ...
        'ManueverByPrevStageFlag', 0, ...
        'IsHuntedCaughtFlag', 0, ...
        'HuntedPreyMaskedFlag', 0, ...
        'ManDirectionCommand', 'None', ...
        'ManAccelCommand','None', ...
        'BatToAvoid', 0, ...
        'Dist2Bat', nan, ...
        'Angle2Bat', nan, ...
        'BatRelativeDirection', 0 , ...
        'ReactToBat', 0, ...
        'Dist2ReactBat', nan, ...
        'BatToReact', nan,...
        'JamFalseAlarmFlag', 0, ...
        'Relevant_ConspEcho_Masked', 0, ...
        'BatCrush'   , 0, ...
        'ObsCrush'   , 0, ...
        'xRecover'   , [], ... 
        'yRecover'   , [], ...
        'tetaRecover', [], ...
        'a_Total', zeros(1, 2, 'single'), ...
        'a_Alignment', zeros(1, 2, 'single'), ...
        'a_Cohesion', zeros(1, 2, 'single'), ...
        'a_Separation', zeros(1, 2, 'single'), ...
        'a_Food', zeros(1, 2, 'single'), ...
        'a_Obstacle', zeros(1, 2, 'single') ...
        ); % omer&anton add 'a_...' commands

    BAT(BatNum).ManueverCmdStruct(MaxNumberOfPulses) = BAT(BatNum).ManueverCmdStruct(1);
    
    BAT(BatNum).TransmittedPulsesStruct = TransmittedPulsesStruct;
    BAT(BatNum).nTimeToSonar = 0; % running index for Time left to the next sonar, at the start- SEARCH
    BAT(BatNum).CurrentPulseWidth = LongPulse; % temporal paraeter for each Pulse time 
    BAT(BatNum).CurrentTimeToSonar = RegTimeToSonar; % The temporal PRF dependes in prevoius PRF and cuurent findings 
    BAT(BatNum).ChirpStep = ChirpSpan/CurrentPulseWidth; % The steps of the frequncies if the bat is chirping, zero if not
    BAT(BatNum).nTimeToSonarPulse = CurrentPulseWidth; % counter of the pulse duration
    BAT(BatNum).PulseRecievedTimeToAnalyze = PulseRecievedTimeToAnalyze;
    BAT(BatNum).nTimeToReceiveSignal = 0;% BAT(BatNum).PulseRecievedTimeToAnalyze; % counter for Pulse reciving Reset the timer to recieve the signal
    BAT(BatNum).TimeToDecisionFlagVec = zeros(1,NumOfSamples+1); % at the beginning- decide where to manuver 
    BAT(BatNum).nTimeToMan = 1; % Temporal parameter to manuever period
    BAT(BatNum).CurrentTimeToSonar = RegTimeToSonar; % The temporal PRF dependes in prevoius PRF and cuurent findings 
    BAT(BatNum).CurrentPulseWidth = CurrentPulseWidth;
    BAT(BatNum).CurrentPulseDuration = CurrentPulseWidth;
    BAT(BatNum).ChirpMinMaxFreqs = 0;
    BAT(BatNum).CurrPulseNum = 1;
    BAT(BatNum).NumOfTimesObsFinds =0; 
    BAT(BatNum).NumOfTimesPreyFinds = 0;
    BAT(BatNum).NumOfTimesSonarTransmits = 0;
    BAT(BatNum).NumberOfCatches= 0;
    BAT(BatNum).WaitForRecievedPulseFlag =1;
    BAT(BatNum).CurrAccelFlag = 0;
    BAT(BatNum).SonarFirstFreq = CenterFreq + ChirpSpan/2;
    BAT(BatNum).ChirpStep = ChirpSpan/BAT(BatNum).CurrentPulseWidth;
    BAT(BatNum).SonarFirstPulseFreq = CenterFreq + ChirpSpan/2;
    BAT(BatNum).CurrentPRF = 1./BAT(BatNum).CurrentTimeToSonar/SampleTime;
    BAT(BatNum).ManueverTypeCell = repmat({''},1,NumOfSamples+1); 
    BAT(BatNum).ManueverPowerCell = repmat({''},1,NumOfSamples+1); 
    BAT(BatNum).DetectedPreysUnMasked = 0;
    BAT(BatNum).DetectedTimesUnMasked = 0;
%%% relative structs
    BAT(BatNum).PreyInBeamStruct =[];
    BAT(BatNum).PreysPolarCoordinate =[];
    BAT(BatNum).ObsInBeamStruct(MaxNumberOfPulses) = struct('Distances',[], 'TargetAngle', [],'xOBSTC',[], ...
        'yOBSTC',[],'IsObs',0, 'DetectetedTargetsVec',[]);
%%% Starting Manuever Commands
  
    BAT(BatNum).ManueverType = 'Foraging';
    BAT(BatNum).ManueverPower = 'RegularForaging';
    BAT(BatNum).ManDirectionCommand = 'None';
    BAT(BatNum).ManAccelCommand = 'None'; 
    BAT(BatNum).SpecialManCommandStrct= struct(...
        'PreyNumToHunt',0,...
        'Dist2HuntedPrey',300,...
        'Angle2HuntedPrey','0',...
        'PreyRelativeDirection',0);
%%% Interference Struct
    BAT(BatNum).BatInterference(NumberOfBats) = struct('RecivedInterPulseTimes',[], 'InterPower',[],'InterFreqs',[]);
    BAT(BatNum).AllInterPulses = NoiseLevel*ones(1,NumOfSamples+1);
    BAT(BatNum).AllInterFromEchosPulses = NoiseLevel*ones(1,NumOfSamples+1);
    BAT(BatNum).AllInterEchos =  NoiseLevel*ones(1,NumOfSamples+1);
    %%% ONLINE
    BAT(BatNum).InterferenceFullStruct(NumOfSamples+1) = struct(...
        'Times',[],'Times_precise',[], ...
        'Freqs',[], 'Power', [], ...
        'BATTxNum',[], 'BatTxPulseNum',[]);
    BAT(BatNum).InterferenceDirectVec = NoiseLevel*ones(1,NumOfSamples+1);
    BAT(BatNum).InterferenceVec = NoiseLevel*ones(1,NumOfSamples+1); 
 
    %%% FULL Acoustic Signal Nov2021
    if AllParams.SimParams.AcousticsCalcFlag
        %     BAT(BatNum).AcousticSig_NoiseLvl = NoiseLevel*randn(1,AcousticNumel);

        BAT(BatNum).AcousticSig_PreyEchoes   = zeros(1,AcousticNumel);
        BAT(BatNum).AcousticSig_CospsEchoes  = zeros(1,AcousticNumel);
        BAT(BatNum).AcousticSig_Clutter      = zeros(1,AcousticNumel);
        BAT(BatNum).AcousticSig_TotalInterference = zeros(1,AcousticNumel);
        BAT(BatNum).AcousticSig_ConspsCalls  = zeros(1,AcousticNumel);
        BAT(BatNum).AcousticSig_Calls        = zeros(1,AcousticNumel);
        BAT(BatNum).AcousticSig_All          = zeros(1,AcousticNumel);
        BAT(BatNum).AcousticSig_Wanted       = zeros(1,AcousticNumel);
        BAT(BatNum).RandNoise                = NoiseLevel*randn(1,AcousticNumel);
    else
        BAT(BatNum).AcousticSig_PreyEchoes   = [];
        BAT(BatNum).AcousticSig_CospsEchoes  = [];
        BAT(BatNum).AcousticSig_Clutter      = [];
        BAT(BatNum).AcousticSig_TotalInterference = [];
        BAT(BatNum).AcousticSig_ConspsCalls  = [];
        BAT(BatNum).AcousticSig_Calls        = [];
        BAT(BatNum).AcousticSig_All          = [];
        BAT(BatNum).AcousticSig_Wanted       = [];
        BAT(BatNum).RandNoise                = [];
    end % if AllParams.SimParams.AcousticsCalcFlag

    %% BiStatMode
    if AllParams.BatSonarParams.BiStatMode
        
        for kPrey = 1:NumberOfPreys
            BAT(BatNum).BiStatDetection.Prey(kPrey) = struct( ...
                'nTimes' , zeros(1,NumOfSamples+1), ...
                'RxPower' , NoiseLevel*ones(1,NumOfSamples+1), ...
                'Dist2Prey' , zeros(1,NumOfSamples+1), ...
                'Angle2Prey' , zeros(1,NumOfSamples+1), ...
                'TxBatNum', zeros(1,NumOfSamples+1));
                
        end % for kPery = 1:NumberOfPreys
        BAT(BatNum).BiStatDetection.AllPreyRxPowerMat = NoiseLevel*ones(NumberOfPreys,NumOfSamples+1); 
        BAT(BatNum).BiStatDetection.AllPFreqMat= zeros(NumberOfPreys,NumOfSamples+1) ;
        BAT(BatNum).BiStatDetection.Pulses(MaxNumberOfPulses) = struct(...
            'PreyDetectedBiSonar', [], ...
            'PreyDetectedOnlyByBiSonar', [], ...
            'PreyToHuntBiSonar' , [], ...
            'PreyToHuntRxPowerDB', [], ...
            'PreyToHuntTime', [], ...
            'PreyToHuntFreq', [], ...
            'Dist2HuntedPrey', [], ...
            'Angle2HuntedPrey', [], ...
            'IsPreyJammed', []);
 
    end % if AllParams.BatSonarParams.BiStatMode
    %% Phantom Echoed mode
     if AllParams.BatSonarParams.PhantomEchoesFromConsFlag
         BAT(BatNum).PhantomEchoesStrct(NumOfSamples+1) = struct( ...
             'nTime', [], ...
             'PreyNum', [], ...
             'TxBatNum',[], ...
             'SignalPhase',[], ... % 'Search', 'Approach', 'Buzz'
             'StartnTime', [], ...
             'EndnTime', [] , ...
             'Freqs', [], ...
             'RxPowersDB', [], ...
             'MaxRxPowerDB', [],...
             'Distance2PhantomReal', [],...
             'Angle2Phantom',[] ...
             );
     end % if AllParams.BatSonarParams.PhantomEchoesFromConsFlag
    %%
    
    %% Filter Bank Detector
    if FilterBankFlag
        %%% create the HighResolution RxMat for FilterBatDetection
        % FilterBankRxMat will add all the signals received anf transmitted
        % by the bat
% %         size_FilterBankRxMat = [numel(filter_fc), FilterBank_NumOfSamples];
        

        FilterBank_save_full_mat_flag = 0; % option to save full matrices in us for analyze 
        if FilterBank_save_full_mat_flag
            size_FilterBankRxMat = [numel(filter_fc), FilterBank_NumOfSamples];
            all_zeros_mat = zeros(size_FilterBankRxMat);
            BAT(BatNum).FilterBankRxMat = all_zeros_mat ;
            BAT(BatNum).FilterBankJammingMat = all_zeros_mat ; % after convolution
            BAT(BatNum).FilterBank_Targets_track = zeros(NumberOfPreys+1, FilterBank_NumOfSamples);
            BAT(BatNum).FilterBank_Jamming_track = zeros(NumberOfPreys+1, FilterBank_NumOfSamples);
        
        else % if FilterBank_save_full_mat_flag
            size_FilterBankRxMat = [numel(filter_fc), FilterBank_NumOfSamples];
            BAT(BatNum).FilterBankRxMat = zeros(numel(filter_fc), ...
                round(FilterBank.time_to_analyze_us)+1);
            BAT(BatNum).FilterBankJammingMat = BAT(BatNum).FilterBankRxMat;
            BAT(BatNum).FilterBank_Targets_track = zeros(NumberOfPreys+1, ...
                round(FilterBank.time_to_analyze_us)+1);
            BAT(BatNum).FilterBank_Jamming_track = BAT(BatNum).FilterBank_Targets_track;
            BAT(BatNum).FilterBank_jam_raw_update_mat = ...
                zeros(numel(FilterBank.fft_freqs), 2*round(FilterBank.time_to_analyze_us)) ; % only jamming before convolution
            BAT(BatNum).FilterBank_rx_jam_update_time = 1; 
        end % if FilterBank_save_full_mat_flag

        BAT(BatNum).FilterBank_Pulses_strct(MaxNumberOfPulses) = struct( ...
            'PulseNum', [] , ...
            'PulsePower', [], ...
            'TxTimes_us', [], ...
            'TxStartTime', [] , ...
            'PulseDuration', [],...
            'PulseIPI', [], ...
            'TxFrequncies', [], ...
            'TxActiveFcs', [], ...
            'TxActiveFcs_idx', [], ...
            'Tx_Fcs_StartTimes', [], ...
            'RxEchosFromPrey', [] ...
            );
        
        BAT(BatNum).FilterBank_nomasking_echoes(MaxNumberOfPulses) = struct( ...
            'all_detected_delays', [], ...
            'delays_samples_errors', [], ...
            'linked_delays', [], ...
            'linked_idx', [] , ...
            'estimated_targets', [], ...
            'estimated_errors', [], ...
            'unlinked_delays', [], ...
            'unlinked_est_jammer', [], ...
            'cluster_counts', [], ...
            'counts_th', [], ...
            'cluster_width', [], ...
            'all_detected_rise_times', [], ...
            'powers_db', [], ...
            'link_th',[]);
       
        BAT(BatNum).FilterBank_all_detecetd_echoes(MaxNumberOfPulses) = BAT(BatNum).FilterBank_nomasking_echoes(MaxNumberOfPulses);
        
         BAT(BatNum).FilterBankCurrPulseTimes = zeros(1, maxPulseSamples_Hr);
         BAT(BatNum).FilterBankCurrPulseFreqs = zeros(1, maxPulseSamples_Hr);
    end % if FilterBankFlag
    %%
    %%% 
 %%% JAR counter
    BAT(BatNum).JARPulsesLeft = 0;
    
 %%% Counters
    BAT(BatNum).Counters.PreyFindsStructCount = 0;
    BAT(BatNum).Counters.CountIsPreyDetectedFunc = 0;
    BAT(BatNum).Counters.CountIsConspDetectedFunc = 0;
    BAT(BatNum).Counters.BatManueCounter = 0;
    
%%% Bats unique
% NOV2021
    if NumberOfBats>1
        switch UniqueFreqsFlag 
            %%% Cahnge to zero reference - 25Apr2022 Moth Jam
            case 'Random'
%                 BAT(BatNum).TerminalFreqUnique = AllParams.BatSonarParams.TerminalFreq + ...
%                     AllParams.BatSonarParams.TerminalFreqVariance * randn(1,1);
%                 BAT(BatNum).TerminalFreqFinalBuzzUnique = AllParams.BatSonarParams.TerminalFreqBuzzFinal + ...
%                     AllParams.BatSonarParams.TerminalFreqVariance * randn(1,1)/2;
                BAT(BatNum).TerminalFreqUnique          = AllParams.BatSonarParams.TerminalFreqVariance * randn(1,1);
                BAT(BatNum).TerminalFreqFinalBuzzUnique = AllParams.BatSonarParams.TerminalFreqVariance * randn(1,1)/2;
            case 'MaxDiff'
                FreqSpan = AllParams.BatSonarParams.TerminalFreqVariance*2;
                DeltaFreq = FreqSpan / (NumberOfBats-1);
                
                BAT(BatNum).TerminalFreqUnique          = -AllParams.BatSonarParams.TerminalFreqVariance + DeltaFreq*(BatNum-1);
                BAT(BatNum).TerminalFreqFinalBuzzUnique = -AllParams.BatSonarParams.TerminalFreqVariance + DeltaFreq*(BatNum-1)/2;
            case 'NoDiff' 
                BAT(BatNum).TerminalFreqUnique          = 0;
                BAT(BatNum).TerminalFreqFinalBuzzUnique = 0;
        end % switch UniqueFreqsFlag
    else % if NumberOfBats>1 %%% Random freq
        BAT(BatNum).TerminalFreqUnique = AllParams.BatSonarParams.TerminalFreqVariance * randn(1,1);
        BAT(BatNum).TerminalFreqFinalBuzzUnique = AllParams.BatSonarParams.TerminalFreqVariance * randn(1,1)/2;
        
    end % if NumberOfBats>1
    
    %% Jamming Moth - New Apr2022
    BAT(BatNum).JammingPreyRxnTimes = [];
    BAT(BatNum).JammingPreyRxLvls   = [];
    BAT(BatNum).JammingPreyNumTx    = [];
    BAT(BatNum).JammingPreyPulseNum = [];

    %% Manuever parameters
    BAT(BatNum).CrushesObsNum       = 0;
    BAT(BatNum).CrushesObsnTimes    = [];
    BAT(BatNum).CrushesConspsNum    = 0;
    BAT(BatNum).CrushesConspsnTimes = [];
    BAT(BatNum).Obs_MaskingStruct   = BAT(BatNum).FindsMaskingStruct;
    BAT(BatNum).ExitSuccess         = false;
    BAT(BatNum).ExitnTime           = nan;

end %for BatNum = 1:NumberOfBats

% %     xFindVec=[]; yFindVec=[];

%%%%%%%%%%%
    % DEBUGGING
    % Prey to catch
    % 
    % This section will locate the prey in time and place that the bat should find it
    % DebugCatchFlag is a flag to operate this code
    % DebugTimeToFind is the time in seconds the prey is moving to the
    % debug point
    % DebugDistToFind is the start distance between the bat and prey in that Time 
    % DebugAngleTofind is THe start angle
    DebugCatchFlag = 0;
    DebugTimeToFind = 5/SampleTime;
    DebugDistToFind = 0.5*DetectionRange;
    DebugAngleToFind = 0.2*BatBeamWidth;
 
    %%%%%%%%%%%%%%% New JAm_Moth Apr-2022
    %%%%%%%%%%%%%%% The rx Signal of the calls for all Prey Items %%%%%%%%%%%%%%%%%%%%%%%%
    %% The Moth jamming acoustic signal
    if AllParams.PreyFlightParams.React2BatsFlag
        if AllParams.PreyFlightParams.JamLoadFlg % load the generated signal
            jamPreySignal = AllParams.PreyFlightParams.jamPreySignal;
        else % if AllParams.PreyFlightParams.JamLoadFlg
            jamPreySignal = generateAcousicPreyJamming(AllParams.PreyFlightParams, FsAcoustic);
            AllParams.PreyFlightParams.jamPreySignal = jamPreySignal;
        end % if AllParams.PreyFlightParams.JamLoadFlg

        jamSigAcousticDur = size(jamPreySignal,2);
        jamSigNDur        = ceil(jamSigAcousticDur / (FsAcoustic * AllParams.SimParams.SampleTime) );
        jamSigTxlvl       = max((jamPreySignal).^2);
    end % if AllParams.PreyFlightParams.React2BatsFlag

    % ing Acoustic 
    
%%%%%%%%%%%

%%%%%%%%%%%
% THE MAIN FUNCTION
%%%%%%%%%%%

    %Progress bar
    hWaitBar = waitbar(0,'1','Name','Calculating Bat Flight...',...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(hWaitBar,'canceling',0)

%%%%%%%%%%%%%%%%%%%

for nTime = 1:NumOfSamples     %nTime- the time vector insample
   
    % Progress BAR PLOT
    if mod(nTime,500) == 0 % Progress Bar
%         nTime
%         getappdata(hWaitBar)
        waitbar(nTime / NumOfSamples,hWaitBar);
    end % if mod
    %
    if IsAnyPreyFlag

        for PreyNum = 1:NumberOfPreys
            %% PREY Movement  and Jamming (Ten times per second for saving rntime)
            PREY(PreyNum).nToChangeDirection = PREY(PreyNum).nToChangeDirection +1;
            PREY(PreyNum).nToDeicide = PREY(PreyNum).nToDeicide +1;

%             if PREY(PreyNum).IsCaught == 0 % If the Prey wasnt caught continue flying
                    
                    if PREY(PreyNum).nToChangeDirection >= ceil(0.1 ./ SampleTime)
                        PREY(PreyNum) .nToChangeDirection = 0;
                        PREY(PreyNum).ChangeDirectionCommand = 1;
%                         PREY(PreyNum).JammingCommand = PreyJamDecision(nTime, PREY(PreyNum), AllParams);
                        
                    else % if PREY(PreyNum).nToChangeDirection
                        PREY(PreyNum).ChangeDirectionCommand =0;
                    end % if PREY(PreyNum).nToChangeDirection
                    
                    if AllParams.PreyFlightParams.React2BatsFlag
                        if PREY(PreyNum).nToDeicide >= ceil(PreyDecisionTime ./ SampleTime) 
                            PREY(PreyNum).nToDeicide = 0;

                            % check whether still transmitting - if so no
                            % decision is required
                            if isempty(PREY(PreyNum).JammingnTimes)
                                lastJamnTime = -inf;
                            else
                                lastJamnTime = PREY(PreyNum).JammingnTimes(end);
                            end
                            if nTime - lastJamnTime > jamSigNDur
                                PREY(PreyNum).JammingCommand = PreyJamDecision(nTime, PREY(PreyNum), AllParams);
                            else
                                PREY(PreyNum).JammingCommand = false;
                            end

                            %% The Jamming
                            if PREY(PreyNum).JammingCommand    
                                % write the jamming nTimesAllParams.PreyFlight.
                                PREY(PreyNum).JammingnTimes  = [PREY(PreyNum).JammingnTimes, nTime]; 

                                %%%% add the jamming Signal All Bats
                                for kBat = 1:AllParams.SimParams.TotalBatsNumber
                                    %%% Caluclate the rx-level and timing

                                    if nTime >= BAT(kBat).BatT0
                                        try
                                            ixPrey = BAT(kBat).PreysPolarCoordinate.TargetsID ==  PreyNum;
                                        catch
                                            error('ixPrey = BAT(kBat).PreysPolarCoordinate.TargetsID ==  PreyNum')
                                        end % try

                                        mainFreq = AllParams.PreyFlightParams.JamMainFreq;

                                        bat2PreyStruct.NumOfTargets = 1;
                                        bat2PreyStruct.TargetsID = PreyNum;
                                        bat2PreyStruct.Distances = BAT(kBat).PreysPolarCoordinate.Distances(ixPrey);
                                        bat2PreyStruct.TargetAngle = BAT(kBat).PreysPolarCoordinate.TargetAngle(ixPrey);
                                        bat2PreyStruct.Bat2TargetRelativeAngle = BAT(kBat).PreysPolarCoordinate.Bat2TargetRelativeAngle(ixPrey);
                                        bat2PreyStruct.IsInBeam = BAT(kBat).PreysPolarCoordinate.IsInBeam(ixPrey);

                                        jamRxstruct = calcSigRxlvl( bat2PreyStruct,  'Bat' , ...
                                            mainFreq , nTime, CurrentPulseNum, AllParams);
                                        jamRxLvl = jamSigTxlvl * jamRxstruct.EchosAttenuation;
                                        jamRxstruct.RxLvl = jamRxLvl;
                                        %%% Write thre timings and levels to BAT
                                        try
                                            preyPulseNum = numel(PREY(PreyNum).JammingnTimes);
                                            [BAT(kBat).JammingPreyRxnTimes, BAT(kBat).JammingPreyRxLvls, BAT(kBat).JammingPreyNumTx, BAT(kBat).JammingPreyPulseNum]  =  ...
                                                writePreyRxLevels(jamRxstruct, BAT(kBat), PreyNum, PreyNum, preyPulseNum, 'Bat');

                                            %%% add the attenuated Acoustic jamming to the Interference Acoussic signal


                                            idx1 = round(jamRxstruct.EchosTimes * FsAcoustic *SampleTime );
                                            currRxSig = jamPreySignal * sqrt(jamRxstruct.EchosAttenuation);
                                            BAT(kBat).AcousticSig_ConspsCalls = Add_currEcho_to_full_vec( ...
                                                BAT(kBat).AcousticSig_ConspsCalls, currRxSig, idx1, jamSigAcousticDur);
                                        catch
                                            hey = 'AcousticSig_Calls'
                                        end % try

                                    end  % if nTime >= BAT(kBat).BatT0
                                end % forkBat
                            end % if PREY(PreyNum).JammingCommand
                            
                        end % if PREY(PreyNum).nToChangeDirection
                    end % if React2BatsFlag
                
                %% The movement of prey   
                [PREY(PreyNum).xPrey(nTime+1), PREY(PreyNum).yPrey(nTime+1),PREY(PreyNum).PreyTeta(nTime+1),...
                    PREY(PreyNum).PreyDteta(nTime+1), PREY(PreyNum).PVelocity(nTime+1), PreyObsManueverFlag(nTime)] = ...
                     PreyMovemet...
                    ( PREY(PreyNum).xPrey(nTime), PREY(PreyNum).yPrey(nTime), PREY(PreyNum).PreyTeta(nTime), ...
                    PREY(PreyNum).PVelocity(nTime),...
                    PREY(PreyNum).PreyDteta(nTime), AllParams, Terrain, PREY(PreyNum).ChangeDirectionCommand);
                
            
            PreysCurrentPos(PreyNum,:) = [ PreyNum, PREY(PreyNum).xPrey(nTime+1), PREY(PreyNum).yPrey(nTime+1),...
                    PREY(PreyNum).PreyTeta(nTime+1), PREY(PreyNum).PVelocity(nTime+1)];
        
 
        
        end % for PreyNum = 1:NumberOfPreys
        


        %%% DEBUG for catch
        % this code Moves the prey to a point the bat is supposed to
        % find it in time DebugTimeToFind
        if DebugCatchFlag && (nTime == DebugTimeToFind)
            for n= min(NumberOfPreys,NumberOfBats)
                PREY(n).xPrey(nTime) = BAT(n).xBati(nTime) + DebugDistToFind*cos(BAT(n).Teta(nTime)+DebugAngleToFind);
                PREY(n).yPrey(nTime) = BAT(n).yBati(nTime) + DebugDistToFind*sin(BAT(n).Teta(nTime)+DebugAngleToFind);
            end % for n
        end % DebugCatchFlag
        %%% END OF DEBUG
    end % if IsPreyFlag
    
    %%
    %%%% Bats Behavior %%%
    for BatNum = 1:NumberOfBats
%         setappdata(h,'canceling',0); % getappdata(h) %%%%% DEBUG GGGGGIIIINNNNGGG

     %%%%% New June 2022 = ExitSuccess: if the bat has exited the cave no
     %%%%% need to coninnue
        if nTime >= BAT(BatNum).BatT0 && ~BAT(BatNum).ExitSuccess
             
            %% Is it time for Transmitting Sonar?  
           
            if BAT(BatNum).nTimeToSonar == 0 
                %%
                %%% Sonar Decision %%%
                % BatSonarDecision []  - Returns :  BAT.CurrentTimeToSonar - the IPI to next sonar
                % BAT.CurrentPulseWidth, BAT.PulseRecievedTimeToAnalyze, BAT.ChirpStep , BAT.PulseFreqsCommand;
                % BAT.PulsePower
                BAT(BatNum).NumOfTimesSonarTransmits = BAT(BatNum).NumOfTimesSonarTransmits+1;
                try
                    [ BAT(BatNum)] = BatSonarDecision( BAT(BatNum), BAT(BatNum).CurrPulseNum, AllParams);
                catch
                    oops = 'BatSonarDecision lalalala' %%% XXXXX %%%
                end % try
                
                %%%%%%%% New June 2022 = ExitSuccess %%%%%%
                if strcmp(AllParams.SimParams.TestMode, 'caveExit')
                  switch AllParams.TerrainParams.Type
                      case {'Room-L', 'Room-L obs'}
                          yExit = (Ymax-3) / xyResolution; % copied from BuildEnvironment 
                          if strcmp(AllParams.TerrainParams.Type, 'Room-L obs');
                              yExit = (8.8) / xyResolution;
                          end % if
                          if BAT(BatNum).yBati(nTime) >= yExit
                              BAT(BatNum).ExitSuccess = true;
                              BAT(BatNum).ExitnTime   = nTime;
                              % final Position
                              BAT(BatNum).yBati(nTime+1:end) = Xmax / xyResolution; % BAT(BatNum).yBati(nTime);
                              BAT(BatNum).xBati(nTime+1:end) = Ymax / xyResolution; % BAT(BatNum).xBati(nTime);
                          end
                      case 'Room-U'
                           yExit = (Ymax-1.5) / xyResolution; % copied from BuildEnvironment 
                           xExit = (Xmax-3) / xyResolution;
                          if BAT(BatNum).yBati(nTime) >= yExit && BAT(BatNum).xBati(nTime) >= xExit
                              BAT(BatNum).ExitSuccess = true;
                              BAT(BatNum).ExitnTime   = nTime;
                              % final Position
                              BAT(BatNum).yBati(nTime+1:end) = Xmax / xyResolution; % BAT(BatNum).yBati(nTime);
                              BAT(BatNum).xBati(nTime+1:end) = Ymax / xyResolution; % BAT(BatNum).xBati(nTime);
                          end
                  end % switch  BatDATA.AllParams.TerrainParams.Type
                end % if strcmp(AllParams.SimParams.TestMode, 'caveExit')


                %%% updating the timers and parmetres of the pulse %%%%
                BAT(BatNum).nTimeToReceiveSignal = 0; % Reset nTimeToReceiveSignal
                %                 BAT(BatNum).NumOfTimesSonarTransmits = BAT(BatNum).NumOfTimesSonarTransmits+1; % total number of transmitted pulses
                BAT(BatNum).nTimeToSonarPulse = 1; % Reset Pulse timer,Time Left to transmitting the pulse
                BAT(BatNum).nTimeToSonar = BAT(BatNum).CurrentTimeToSonar; % Default Command until next Decision (not necessery)
                BAT(BatNum).PRFVec(nTime) = 1./BAT(BatNum).CurrentTimeToSonar/SampleTime;
                BAT(BatNum).PulseWidthVec(nTime)= BAT(BatNum).CurrentPulseWidth;
                BAT(BatNum).PulsePowerVec(nTime) = BAT(BatNum).PulsePower;
                BAT(BatNum).WaitForRecievedPulseFlag = 1;
                %                 PulseCenterFreq = BAT(BatNum).PulseFreqsCommand(round(end/2)); % the Center freq for calculte attenuations
                %%% The Transmitted Sonar Struct %%%%
                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).PulseNum = BAT(BatNum).NumOfTimesSonarTransmits;
                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).PulsePower = BAT(BatNum).PulsePower;
                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).StartPulseTime = nTime;
                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).PulseWidth =...
                    BAT(BatNum).CurrentPulseWidth;
                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).PulseDuration =...
                    BAT(BatNum).CurrentPulseDuration;
                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).PulseFreqsCommands = ...
                    BAT(BatNum).PulseFreqsCommand; %%% XXXXX %%%
                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).ManueverTypePower = ...
                    [BAT(BatNum).ManueverType , BAT(BatNum).ManueverPower];
                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).IPItoNextPulse = ...
                    BAT(BatNum).CurrentTimeToSonar;
                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).JARPulsesLeft = ...
                    BAT(BatNum).JARPulsesLeft;
                
                
                %%% create the HighResolution RxMat for FilterBatDetection
                
                
                %%% Creating the Sonar Pulse and Chirp %%%%
                
                %             if ( BAT(BatNum).nTimeToSonarPulse <=  BAT(BatNum).CurrentPulseWidth)
                %                 try
                PulsenTimes = nTime: (nTime + BAT(BatNum).CurrentPulseDuration-1);
                BAT(BatNum).SonarPulses(PulsenTimes) = 1; % updating the output vector for sonar times
                BAT(BatNum).PulseCurrFreqVec(PulsenTimes) = BAT(BatNum).PulseFreqsCommand;
                BAT(BatNum).PulsePowerVec(PulsenTimes) = BAT(BatNum).PulsePower;
                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).ChirpMinMaxFreqs = ...
                    BAT(BatNum).ChirpMinMaxFreqs; % XXXX %%%%%
                BAT(BatNum).nTimeToSonarPulse = BAT(BatNum).nTimeToSonarPulse+1;
                %                 catch
                %                     hop = 'creating the pulse :-) '
                %                 end % try
                %             end %( if ( BAT(BatNum).nTimeToSonarPulse <=  BAT(BatNum).CurrentPulseWidth) )
                %%
                %% Reconstruct the acoustic signal of the call
                %%% Buliding the Chirp Nov2021
                if AllParams.SimParams.AcousticsCalcFlag
                    nSamples = ceil(BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).PulseWidth * FsAcoustic * SampleTime);
                    try
                        
                        idx1 = round(nTime*FsAcoustic*SampleTime);
                        Acoutic_idx = idx1 : idx1 + nSamples-1;
                        AcousticCall = ReconstractAcousticCall(BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits), FsAcoustic, nSamples );
                        BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).TxAcousticSig = AcousticCall;
                        
                        %%%% create the reference Echo of Prey for classifier (Reference Target Signature) %%%%%
                        if AllParams.BatSonarParams.PreyClassifierFlag
                                 BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).PreyAcousticSignature = ...
                                     multi_echo_gen(AcousticCall, 2, PreyGlintTime,[1 1], 130, FsAcoustic, 0, 0);
                        else
                            BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).PreyAcousticSignature = AcousticCall;
                        end %  if AllParams.BatSonarParams.PreyClassifierFlag

                        BAT(BatNum).AcousticSig_Calls = Add_currEcho_to_full_vec( ...
                            BAT(BatNum).AcousticSig_Calls, AcousticCall, idx1, nSamples);
                    catch
                        hey = 'AcousticSig_Calls'
                    end % try
                end %if AllParams.SimParams.AcousticsCalcFlag
                %% The Objects that can be found by current pulse %%%
                
                %%% checking the pulse distance and angle to find prey or obstacles %%%
                CurrentPulseNum = BAT(BatNum).NumOfTimesSonarTransmits;
                % the Obstacles
                try
                BAT(BatNum).ObsInBeamStruct(CurrentPulseNum) = BatFindObstacles...
                    (BAT(BatNum).xBati(nTime),BAT(BatNum).yBati(nTime),BAT(BatNum).Teta(nTime), ...
                    BatBeamWidth, DetectionRange, Terrain, polyTerrain, AllParams);
                catch
                    warning('ObsInBeamStruct')
                end
                % the Prey
                BAT(BatNum).PreysPolarCoordinate = BatFindTargets...
                    (BAT(BatNum).xBati(nTime),BAT(BatNum).yBati(nTime),BAT(BatNum).Teta(nTime), ...
                    BatBeamWidth, DetectionRange, Terrain, PreysCurrentPos,'Prey');
                BAT(BatNum).PreysRelativePositionVecStr(BAT(BatNum).NumOfTimesSonarTransmits)= BAT(BatNum).PreysPolarCoordinate;
                
                % Other Bats
                OtherBatsCurrentPos = FindPosFromBatsStrct(BAT, BatNum, nTime, NumberOfBats);
                BAT(BatNum).OtherBatsPolarCoordinates = BatFindTargets...
                    (BAT(BatNum).xBati(nTime),BAT(BatNum).yBati(nTime),BAT(BatNum).Teta(nTime), ...
                    BatBeamWidth, DetectionRange, Terrain, OtherBatsCurrentPos,'OtherBats');
                
                %%% Calculate obstacles and Prey found in the X-Y simulation coordinates  %%%
               
                
                %%% And Calcualte the echoes received %%%
                BAT(BatNum).IsObs =  BAT(BatNum).ObsInBeamStruct(CurrentPulseNum).IsObs;
                if (BAT(BatNum).IsObs) % XXX %
                    
                    %%% Calculate the recieved Echos from Obstacles%%%
                    
                    EchosFromObsStruct = ...
                        RecievedEchosFromSonar( BAT(BatNum).ObsInBeamStruct(CurrentPulseNum), 'Obs' ,  BAT(BatNum).PulseFreqsCommand ,...
                        nTime,CurrentPulseNum, AllParams);
                    % %                     BAT(BatNum).EchosFromObsStruct(CurrentPulseNum) = EchosFromObsStruct; % XXX %
                    
                    BAT(BatNum).EchosFromObsStruct(CurrentPulseNum) = EchosFromObsStruct;  % Nov20212
                      
%                     if BAT(BatNum).NumOfObsDetected > 0
%                         BAT(BatNum).NumOfTimesObsFinds = BAT(BatNum).NumOfTimesObsFinds +1;
%                         NumOfTimesObsFinds = BAT(BatNum).NumOfTimesObsFinds;
                        
                        %                         BAT(BatNum).EchosFromObsStruct(NumOfTimesObsFinds) = EchosFromObsStruct; % Nov20212
                        
                        %% clutterVec, Vladimir
                        
                        for i=1:1:size(EchosFromObsStruct.EchoDetailed,2)
                            
                            %%%% Build the Acoustic Signal for the Clutter -
                            %%%% Nov2021
                            if AllParams.SimParams.AcousticsCalcFlag
                                nSamples = ceil(BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).PulseWidth * FsAcoustic * SampleTime);
                                try
                                    idx1 = round((EchosFromObsStruct.TransmittedPulseTime + EchosFromObsStruct.EchosTimes(i) ) * FsAcoustic*SampleTime);
                                    Curr_Obs_Acoustic = ReconstractAcousticEcho(EchosFromObsStruct.EchoDetailed(i), ...
                                        BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).TxAcousticSig, SampleTime, nSamples);
                                    %%% add the result to the acoustic vector
                                    % protection against the end of the simulation
                                    BAT(BatNum).AcousticSig_Clutter = Add_currEcho_to_full_vec( ...
                                        BAT(BatNum).AcousticSig_Clutter, Curr_Obs_Acoustic, idx1, nSamples);
                                    
                                catch
                                    hey = 'ObsEchoProblem'
                                end % try
                            end % if AllParams.SimParams.AcousticsCalcFlag
                        end % for i

%                     end %if BAT(BatNum).NumOfObsDetected > 0
                else % if BAT(BatNum).IsObs
                    
                    BAT(BatNum).NumOfObsDetected = 0;
                    BAT(BatNum).DetectedObs = [];
                end % if IsObs
                
                %% The Echoes from the prey %%%
                
                EchosFromPreyStruct = RecievedEchosFromSonar(BAT(BatNum).PreysPolarCoordinate, 'Prey' ,...
                    BAT(BatNum).PulseFreqsCommand , nTime, CurrentPulseNum, AllParams);
                BAT(BatNum).EchosFromPreyStruct( CurrentPulseNum ) = EchosFromPreyStruct;
                
                %%%%%%%%%%%%%%% New JAm_Moth Apr-2022
                %%%%%%%%%%%%%%% The rx Signal of the calls for all Prey Items %%%%%%%%%%%%%%%%%%%%%%%%
                
                PreyRxlevelofBats = calcSigRxlvl( BAT(BatNum).PreysPolarCoordinate,  'Prey' , ...
                    BAT(BatNum).PulseFreqsCommand , nTime, CurrentPulseNum, AllParams);
               % and the actual rx lvl
               cur_power = 10.^(BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).PulsePower/10);
               PreyRxlevelofBats.RxLvl = cur_power * PreyRxlevelofBats.EchosAttenuation;
                %%% Write the rxtime and levels for each Prey Item\
               for kPrey = 1:NumberOfPreys
                   [PREY(kPrey).RxnTimes, PREY(kPrey).RxLvls, PREY(kPrey).RxBatNumTx, PREY(kPrey).RxBatPulseNum]  =  ...
                       writePreyRxLevels(PreyRxlevelofBats, PREY(kPrey), kPrey, BatNum, BAT(BatNum).NumOfTimesSonarTransmits);
               end % for kPrey

                %%     
                %%% Build the Acoustic Signal for the Prey -
                %%%% Nov2021
                if AllParams.SimParams.AcousticsCalcFlag && AllParams.SimParams.TotalPreysNumber > 0
                    nTxSamples   = numel(BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).TxAcousticSig);
                    nEchoSamples = nTxSamples;
                    for i=1:1:size(EchosFromPreyStruct.EchoDetailed,2)
                        try
                            idx1 = round((EchosFromPreyStruct.TransmittedPulseTime + EchosFromPreyStruct.EchosTimes(i) ) * FsAcoustic*SampleTime);

                            Curr_Prey_Acoustic = ReconstractAcousticEcho(EchosFromPreyStruct.EchoDetailed(i), ...
                                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits).TxAcousticSig, SampleTime, nTxSamples);
                            if AllParams.BatSonarParams.PreyClassifierFlag
                                Curr_Prey_Acoustic = multi_echo_gen(Curr_Prey_Acoustic,2, PreyGlintTime,[1 1], 130, FsAcoustic, 0, 0);
                                nEchoSamples = numel(Curr_Prey_Acoustic);
                            end %  if AllParams.BatSonarParams.PreyClassifierFlag
                            BAT(BatNum).AcousticSig_PreyEchoes = Add_currEcho_to_full_vec( ...
                                BAT(BatNum).AcousticSig_PreyEchoes, Curr_Prey_Acoustic, idx1, nEchoSamples);
                        catch
                            hety= 'EchoPreyAcous'
                        end % try
                    end % for i=1:1:size(EchosFromPreyStruct.EchoDetailed,2)
                end %if AllParams.SimParams.AcousticsCalcFlag

                %% FilterBank Echoes from Prey without acousics- Removed Not Supported
                %%% From Jun2016- Only Acoutics FilterBank

                
                %% Echoes From Conspecifics
                % calculate only in swarm-mode
                if strcmp(AllParams.SimParams.TestMode, 'swarm') || AllParams.SimParams.DetectConsps
                    
                    BAT(BatNum).EchosFromConspStruct( CurrentPulseNum ) = ...
                        RecievedEchosFromSonar(BAT(BatNum).OtherBatsPolarCoordinates, 'Conspecifics' ,...
                        BAT(BatNum).PulseFreqsCommand , nTime, CurrentPulseNum, AllParams);
                    
                    %%% Build the Acoustic Signal for Conspefics
                    %%%%% NOV2021
                    if AllParams.SimParams.AcousticsCalcFlag
                        nSamples = numel(BAT(BatNum).TransmittedPulsesStruct(CurrentPulseNum).TxAcousticSig);
                        for i = 1: 1: BAT(BatNum).EchosFromConspStruct( CurrentPulseNum ).NumOfEchos
                            idx1 = round((BAT(BatNum).EchosFromConspStruct( CurrentPulseNum ).TransmittedPulseTime + ...
                                (BAT(BatNum).EchosFromConspStruct( CurrentPulseNum ).EchosTimes(i)) ) * FsAcoustic*SampleTime);
                            
                            try
                                Curr_Consps_Acoustic = ReconstractAcousticEcho(BAT(BatNum).EchosFromConspStruct( CurrentPulseNum ).EchoDetailed(i), ...
                                    BAT(BatNum).TransmittedPulsesStruct(CurrentPulseNum).TxAcousticSig, SampleTime, nSamples);
                                BAT(BatNum).AcousticSig_CospsEchoes = Add_currEcho_to_full_vec( ...
                                    BAT(BatNum).AcousticSig_CospsEchoes , Curr_Consps_Acoustic, idx1, nSamples);
                            catch
                                hety= 'AcousticSig_CospsEchoes_PROBLEMS'
                            end % try
                        end % for i = 1: 1: BAT(BatNum).EchosFromConspStruct( CurrentPulseNum ).NumOfEchos
                    end %if AllParams.SimParams.AcousticsCalcFlag
                end % if strcmp() swarm-mode
                
                
                
                %% Interference Calculation: Jamming, Direct, Echoes, Bi-Stat, FilterBank %%%
                %% CalculateCrossIntreferenceOnLine
                
                %%% Calculating the Interference caused by this pulse to other bats %%%
                %%% updating the Receiver's bat Intefernce vector with the
                %%% interferences from the emiiter's bat current pulse
                
                %%% The Building of the Acoustic Signal of the Interference is
                %%% executerd for each kRxBat in the function CalculateCrossIntreferenceOnLine
                %%% AcousticSig_ConspsCalls is updated here
                %%%%% NOV2021
                
                %                 try
                if AllParams.SimParams.MaskingByConsps
                    for kRxBat = 1:NumberOfBats
                        if kRxBat ~= BatNum % no self Interfernce
                            try
                                [kRxDirectIntTimes, kRxDirectIntPower, kRxAllIntTimes, kRxAllIntPower,...
                                  kRxAllInterStruct, InterFreqs, BiStatDetectionSrtct, ...
                                    InterEchoesStrct, FilterBank_jam_struct, AcousticSig_ConspsCalls] = ...
                                    CalculateCrossIntreferenceOnLine( ...
                                    BAT, BatNum, kRxBat, PREY, 'xy', AllParams, BAT(BatNum).NumOfTimesSonarTransmits, FilterBank);
                                
                            catch
                                oppsalla = [' CalculateCrossIntreferenceOnLine, BatNum: ', num2str(BatNum), ...
                                    ' Pulse: ', num2str(BAT(BatNum).NumOfTimesSonarTransmits)]
                            end % try
                            BAT(kRxBat).InterferenceDirectVec(kRxDirectIntTimes) = ...
                                BAT(kRxBat).InterferenceDirectVec(kRxDirectIntTimes) + kRxDirectIntPower;
                            BAT(kRxBat).InterferenceVec(kRxAllIntTimes) = ...
                                BAT(kRxBat).InterferenceVec(kRxAllIntTimes) + kRxAllIntPower;
                            
                            BAT(kRxBat).InterferenceFullStruct = kRxAllInterStruct;
                            
                            %%%% update AcousticSig_ConspsCalls
                            BAT(kRxBat).AcousticSig_ConspsCalls = AcousticSig_ConspsCalls;
                            
                            
                            % Bi-Stat Detection Struct
                            if  AllParams.BatSonarParams.BiStatMode
                                BAT(kRxBat).BiStatDetection = BiStatDetectionSrtct;
                            end % if  AllParams.BatSonarParams.BiStatMode
                            
                            % Phantom detection
                            if AllParams.BatSonarParams.PhantomEchoesFromConsFlag
                                [IsAnyPhantomDetectedFlag, PhantomDetectionsStrct] = ...
                                    IsPhantomEchoesDetectected(InterEchoesStrct, BAT, kRxBat, AllParams);
                                if IsAnyPhantomDetectedFlag
                                    BAT(kRxBat).PhantomEchoesStrct = PhantomDetectionsStrct;
                                end % if IsAnyPhantomDetectedFlag
                            end % if AllParams.BatSonarParams.PhantomEchoesFromConsFlag
                            
                            % Filter Bank Detector
                            
                        end % if kRxBat ~= BatNum
                        
                    end % for kRxBat = 1:NumberOfBats
                end % if AllParams.SimParams.MaskingByConsps
                %                 catch
                %                     hopa = 'CalculateCrossIntreferenceOnLine';
                %                 end % try
                %%% Interferece from Prey-items' echoes
                %%
            end % if nTimeToSonar == 0
            

          
           %%
            %%% Receiving the Echo  and decision till next Pulse%%%
            % PulseRecievedTimeToAnalyze - is the delay from the transmitted
            % pulse to anlyzing the pulse
            if BAT(BatNum).WaitForRecievedPulseFlag
                %%% Still Waiting
                if BAT(BatNum).nTimeToReceiveSignal < BAT(BatNum).PulseRecievedTimeToAnalyze
                    BAT(BatNum).nTimeToReceiveSignal = BAT(BatNum).nTimeToReceiveSignal+1;
                    
                    %%% RECEVING and analyzing the Pulse
                elseif BAT(BatNum).nTimeToReceiveSignal == BAT(BatNum).PulseRecievedTimeToAnalyze
                    BAT(BatNum).WaitForRecievedPulseFlag = 0; % Reset the Flag
                    BAT(BatNum).TimeToDecisionFlagVec(nTime) = 1; % If a sonar pulse is recievved- than make make manuver decision
                     
                    %% Pre Detection - For reference
                    %%% %%% Pre - detecting %%%
                    BAT(BatNum).CurrPulseNum = BAT(BatNum).NumOfTimesSonarTransmits;
                    
                    %%% Check if the ocstacles are detected
                    if BAT(BatNum).IsObs
                        try
                            CurrEchoesFromObsStruct =  BAT(BatNum).EchosFromObsStruct(BAT(BatNum).CurrPulseNum);

                            %%% Check if the Obstacles are detected by the bat
                            [BAT(BatNum).NumOfObsDetected, BAT(BatNum).DetectedObs, BAT(BatNum).DetectedObsTimes,~] = ...
                                IsPreyDetected('Obs', CurrEchoesFromObsStruct ,...
                                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits), ...
                                BAT(BatNum).IsObs, [], AllParams);

                            %%% Changed To support Cave Exit - Pre-Detections - Updated again after Jamming
                            %%% Tests
                            % Jun2022
                            BAT(BatNum).NumOfTimesObsFinds = BAT(BatNum).NumOfTimesObsFinds +1;
                            NumOfTimesObsFinds = BAT(BatNum).NumOfTimesObsFinds;
                            BAT(BatNum).ObsInBeamStruct(BAT(BatNum).CurrPulseNum).DetectetedTargetsVec = BAT(BatNum).DetectedObs;

                            BAT(BatNum).ObsFindsStruct(BAT(BatNum).CurrPulseNum).TransmittedPulseNum = ...
                                BAT(BatNum).CurrPulseNum;
                            BAT(BatNum).ObsFindsStruct(BAT(BatNum).CurrPulseNum).DetectedPreyNum     = ...
                                BAT(BatNum).DetectedObs;
                            BAT(BatNum).ObsFindsStruct(BAT(BatNum).CurrPulseNum).DetectedTimes       = ...
                                BAT(BatNum).DetectedObsTimes;
                            BAT(BatNum).ObsFindsStruct(BAT(BatNum).CurrPulseNum).xFinds              = ...
                                BAT(BatNum).ObsInBeamStruct(BAT(BatNum).CurrPulseNum).xOBSTC(BAT(BatNum).DetectedObs) ;
                            BAT(BatNum).ObsFindsStruct(BAT(BatNum).CurrPulseNum).yFinds              = ...
                                BAT(BatNum).ObsInBeamStruct(BAT(BatNum).CurrPulseNum).yOBSTC(BAT(BatNum).DetectedObs) ;
                            BAT(BatNum).ObsFindsStruct(BAT(BatNum).CurrPulseNum).Distances           = ...
                                BAT(BatNum).ObsInBeamStruct(BAT(BatNum).CurrPulseNum).Distances(BAT(BatNum).DetectedObs);
                            BAT(BatNum).ObsFindsStruct(BAT(BatNum).CurrPulseNum).Angle2DetectedPrey  = ...
                                BAT(BatNum).ObsInBeamStruct(BAT(BatNum).CurrPulseNum).TargetAngle(BAT(BatNum).DetectedObs);
                            BAT(BatNum).ObsFindsStruct(BAT(BatNum).CurrPulseNum).Angles              = ...
                                BAT(BatNum).ObsInBeamStruct(BAT(BatNum).CurrPulseNum).TargetAngle(BAT(BatNum).DetectedObs);
                            
                        catch
                            hop = 'CurrEchoesFromObsStruct line 1065'
                        end % try

                    else % BAT(BatNum).IsObs 
                        CurrEchoesFromObsStruct = [];
                    end % if BAT(BatNum).IsObs> 0

                    
                        
                    %%% Check if the Prey is detected: IsPreyDetected -
                    CurrEchosFromPreyStruct = BAT(BatNum).EchosFromPreyStruct(BAT(BatNum).CurrPulseNum);
                    try
                        [BAT(BatNum).NumOfPreyDetected, BAT(BatNum).DetectedPreys, BAT(BatNum).DetectedPreyTimes, ...
                            BAT(BatNum).ClutteredPreyVec, BAT(BatNum).ClutterednTimesVec] = ...
                            IsPreyDetected('Prey', CurrEchosFromPreyStruct, ...
                            BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits), ...
                            BAT(BatNum).NumOfObsDetected, CurrEchoesFromObsStruct, AllParams);
                    catch
                        hop = 'IsPreyDetected line 1073'
                    end % try
                    BAT(BatNum).Counters.CountIsPreyDetectedFunc = BAT(BatNum).Counters.CountIsPreyDetectedFunc+1;
                    
                    %%% 
                    %%% check if conspefics are detected
                    if strcmp(AllParams.SimParams.TestMode, 'swarm') || AllParams.SimParams.DetectConsps
                        try
                            [BAT(BatNum).NumOf_Consps_Detected, BAT(BatNum).Detected_Consps, BAT(BatNum).Detected_Consps_Times, ...
                                BAT(BatNum).Cluttered_Consps_Vec, BAT(BatNum).Cluttered_Consps_nTimesVec] = ...
                                IsPreyDetected('Consp', BAT(BatNum).EchosFromConspStruct( BAT(BatNum).CurrPulseNum ), ...
                                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).NumOfTimesSonarTransmits), ...
                                BAT(BatNum).NumOfObsDetected, CurrEchoesFromObsStruct, AllParams);
                        catch
                            hop = 'IsPreyDetected Consp'
                        end % try
                        
                        BAT(BatNum).Counters.CountIsConspDetectedFunc = BAT(BatNum).Counters.CountIsConspDetectedFunc+1;
                        
                    end % if strcmp(AllParams.SimParams.TestMode, 'swarm')
                    
                   
                    
                  
                    %%  
                   
                    
                    %%% Miss-detection by probabilty
                          BAT(BatNum).MissDetectedPreysByProb = [];
                    if BAT(BatNum).NumOfPreyDetected > 0 
                        if  AllParams.BatSonarParams.MissDetectionProbFlag
                            BAT(BatNum).DetectedPreysAll = BAT(BatNum).DetectedPreys;
                            BAT(BatNum).MissDetectedPreysByProb = IsPreyMissDetected(BAT(BatNum).DetectedPreysAll, ProbToDetect);
                            BAT(BatNum).DetectedPreys = setdiff( BAT(BatNum).DetectedPreysAll , BAT(BatNum).MissDetectedPreysByProb,'stable' ); % the unmissed preys
                            BAT(BatNum).NumOfPreyDetected = length(BAT(BatNum).DetectedPreys);
                            
                        else %  if AllParams.BatSonarParams.MissDetectionProbFlag
                            %                          BAT(BatNum).DetectedPreys = BAT(BatNum).DetectedPreysAll;
                        end % if AllParams.BatSonarParams.MissDetectionProbFlag
                    else % % if BAT(BatNum).NumOfPreyDetected > 0
                        %                      BAT(BatNum).DetectedPreys = BAT(BatNum).DetectedPreysAll;
                    end % if BAT(BatNum).NumOfPreyDetected > 0
                    
                    %% Jamming and masking effects - Prey
                    %%% Checking for Masking from interference
                    
                    CurrPulsePower = BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).CurrPulseNum).PulsePower; % the power of the current pulse
                    % for filter-bank receiver we dont assume pre-detection
                    % becuse thre might be false detections due to masking
%                     if FilterBankFlag
%                         BAT(BatNum).NumOfPreyDetected = NumberOfPreys;
%                         BAT(BatNum).DetectedPreys = CurrEchosFromPreyStruct.TargetIndex; % we check all prey items
%                     end % 
                    
                  %% Acoustics - THe signals
                    %%% update the the Acoustic signal:BAT(BatNum).AcousticSig_All
                    % BAT(BatNum).AcousticSig_All is the vector of the
                    % wanted signal + the releveant interefernce
                    
                    %%% Nov2021
                    % Remark: I summarize the full vectors each time, mayby improve later
                    % BAT(BatNum).RandNoise - is the Noise Vector
                    % each time
                    if AllParams.SimParams.AcousticsCalcFlag
                        %%% The Wanted Signal
                        BAT(BatNum).AcousticSig_Wanted = BAT(BatNum).RandNoise ;
                        if AllParams.SimParams.DetectPrey
                            BAT(BatNum).AcousticSig_Wanted = BAT(BatNum).AcousticSig_Wanted + BAT(BatNum).AcousticSig_PreyEchoes;
                        end
                        if AllParams.SimParams.DetectConsps
                            BAT(BatNum).AcousticSig_Wanted = BAT(BatNum).AcousticSig_Wanted + BAT(BatNum).AcousticSig_CospsEchoes;
                        end %  if foraging_flag
                        if AllParams.SimParams.DetectObs
                            BAT(BatNum).AcousticSig_Wanted = BAT(BatNum).AcousticSig_Wanted + BAT(BatNum).AcousticSig_Clutter;
                        end %  if foraging_flag
                        
                        %%% ADd All Interference to the signal
                        if any([AllParams.SimParams.MaskingByConsps, AllParams.SimParams.MaskingByClutter])
                            BAT(BatNum).AcousticSig_TotalInterference = zeros(1,AcousticNumel);
                            if AllParams.SimParams.MaskingByConsps
                                BAT(BatNum).AcousticSig_TotalInterference = BAT(BatNum).AcousticSig_TotalInterference + BAT(BatNum).AcousticSig_ConspsCalls;
                            end
                            if AllParams.SimParams.MaskingByClutter
                                BAT(BatNum).AcousticSig_TotalInterference = BAT(BatNum).AcousticSig_TotalInterference + BAT(BatNum).AcousticSig_Clutter;
                            end % if clutter_flag
                            
                            %%%%% Summary
                            BAT(BatNum).AcousticSig_All = BAT(BatNum).AcousticSig_Wanted + BAT(BatNum).AcousticSig_TotalInterference;
                        else
                            %%%%% Summary
                            BAT(BatNum).AcousticSig_All = BAT(BatNum).AcousticSig_Wanted;
                        end % if any
                    end % if AllParams.SimParams.AcousticsCalcFlag


% % %                     if AllParams.SimParams.AcousticsCalcFlag
% % %                         %%% The Wanted Signal
% % %                         Acoustic_Noise = BAT(BatNum).RandNoise ;
% % %                         if AllParams.SimParams.DetectPrey
% % %                             Acoustic_Wanted_Sig = Acoustic_Noise + BAT(BatNum).AcousticSig_PreyEchoes;
% % %                         end
% % %                         if AllParams.SimParams.DetectConsps
% % %                             Acoustic_Wanted_Sig = Acoustic_Noise + BAT(BatNum).AcousticSig_CospsEchoes;
% % %                         end %  if foraging_flag
% % %                         if AllParams.SimParams.DetectObs
% % %                             Acoustic_Wanted_Sig = Acoustic_Noise + BAT(BatNum).AcousticSig_Clutter;
% % %                         end %  if foraging_flag
% % %                         
% % %                         %%% All Signal
% % %                         BAT(BatNum).AcousticSig_All = Acoustic_Wanted_Sig ;
% % %                         if AllParams.SimParams.MaskingByConsps
% % %                             BAT(BatNum).AcousticSig_All = BAT(BatNum).AcousticSig_All + BAT(BatNum).AcousticSig_ConspsCalls;
% % %                         end
% % %                         if AllParams.SimParams.MaskingByClutter
% % %                             BAT(BatNum).AcousticSig_All = BAT(BatNum).AcousticSig_All + BAT(BatNum).AcousticSig_Clutter;
% % %                         end % if clutter_flag
% % %                     end % if AllParams.SimParams.AcousticsCalcFlag

                    %% Acoustis Detections, Jamming, Classifier, and masking effects -PreyItems
                    %%%
                    %%% Nov2021
                    if AllParams.SimParams.AcousticsCalcFlag
                        try
                            relevant_idx = round( BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).CurrPulseNum).StartPulseTime* FsAcoustic*SampleTime + ...
                                (1: BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).CurrPulseNum).IPItoNextPulse* FsAcoustic*SampleTime ) );
                            if relevant_idx(end) > AcousticNumel
                                relevant_idx = relevant_idx(1):AcousticNumel;
                            end % if
                            Tx_Acoustic_Call = BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).CurrPulseNum).TxAcousticSig; % the call of the bat
                            Rx_Acoustic_Sig = BAT(BatNum).AcousticSig_All(relevant_idx); % the whole Signal including interferences and noise level
% % %                             Rx_Acoustic_WantedSig = Acoustic_Wanted_Sig(relevant_idx); % the wanted Signal
                            %                                     Rx_Acoustic_Clutter = BAT(BatNum).AcousticSig_Clutter(relevant_idx); % THe Clutter - for tests only


                            %%% The relevenat input and The masking and detections %%%%
                            if AllParams.SimParams.DetectPrey
                                Rx_Acoustic_WantedSig = BAT(BatNum).AcousticSig_Wanted(relevant_idx);
                                CurrDetectedEchoes = CurrEchosFromPreyStruct;

                                [BAT(BatNum).FindsMaskingStruct(BAT(BatNum).CurrPulseNum) ] = ...
                                    Interfernce2DetectedPreys_Acoustics( CurrPulsePower , ...
                                    BAT(BatNum).DetectedPreys, CurrDetectedEchoes, Tx_Acoustic_Call, ...
                                    Rx_Acoustic_WantedSig,  Rx_Acoustic_Sig, BAT(BatNum).CurrPulseNum, ...
                                    BAT, BatNum, AllParams, FilterBank );
                            end

                        catch
                            oooppppsepse = 'Interfernce2DetectedPreys_Acoustics FUCKED'
                        end % try
                    end % if AllParams.SimParams.AcousticsCalcFlag
                        
                    if BAT(BatNum).NumOfPreyDetected > 0

                        %% if Not Acoutic Reconstruction 
                        if ~FilterBankFlag
                            if ~AllParams.SimParams.AcousticsCalcFlag
                                try
                                    [BAT(BatNum).FindsMaskingStruct(BAT(BatNum).CurrPulseNum) ] = ...
                                        Interfernce2DetectedPreys( CurrPulsePower , ...
                                        BAT(BatNum).DetectedPreys, CurrEchosFromPreyStruct, BAT(BatNum).InterferenceDirectVec, ...
                                        BAT(BatNum).InterferenceVec,  BAT(BatNum).InterferenceFullStruct, BAT(BatNum).CurrPulseNum, ...
                                        BAT, BatNum, AllParams, FilterBank );
                                catch
                                    bugggg = ['Interfernce2DetectedPreys :' , 'BatNum = ', num2str(BatNum),' nTime: ', num2str(nTime)]
                                end % try
                    
                    
                            end % if ~AllParams.SimParams.AcousticsCalcFlag
                    
                        else % if ~FilterBankFlag
                    
                        end % if ~FilterBankFlag    

                        %%% Detection after Interfernce
                        % update  all-detection and masked detections
                        % BAT(BatNum).DetectedPreys = BAT(BatNum).FindsMaskingStruct(BAT(BatNum).CurrPulseNum).DetectedPreys;

                        [BAT(BatNum).DetectedPreysUnMasked , TargetInd] = ...
                            setdiff( BAT(BatNum).DetectedPreys ,...
                            BAT(BatNum).FindsMaskingStruct(BAT(BatNum).CurrPulseNum).MaskedPreys ,'stable');

                        BAT(BatNum).DetectedTimesUnMasked = BAT(BatNum).DetectedPreyTimes(TargetInd);

                        
                       %%%%% positions of the detected prey items
                    
                        BAT(BatNum).NumOfDetectedPreys = length( BAT(BatNum).DetectedPreys); % the number of Unmasked taregets
                    
                        BAT(BatNum).NumOfTimesPreyFinds = BAT(BatNum).NumOfTimesPreyFinds +1;
                        NumOfTimesPreyFinds = BAT(BatNum).NumOfTimesPreyFinds ;
                    
                        % caluclulate the current relative position for the prey
                        BAT(BatNum).CurrDetectedPreysPolarCoordinate = BatFindTargets...
                            (BAT(BatNum).xBati(nTime),BAT(BatNum).yBati(nTime),BAT(BatNum).Teta(nTime), ...
                            BatBeamWidth, DetectionRange, Terrain, PreysCurrentPos(BAT(BatNum).DetectedPreys,:),'Prey');
                    
                        % The Position of the Prey found
                        [xFindsCurrentVec, yFindsCurrentVec] = ...
                            PositionInEnvironmentCoordination(BAT(BatNum).xBati(nTime), BAT(BatNum).yBati(nTime),...
                            BAT(BatNum).Teta(nTime), BAT(BatNum).CurrDetectedPreysPolarCoordinate);

                    else % BAT(BatNum).NumOfPreyDetected > 0
                        BAT(BatNum).DetectedPreysUnMasked = 0;
                        BAT(BatNum).DetectedTimesUnMasked = 0;
                    
                        BAT(BatNum).CurrDetectedPreysPolarCoordinate.NumOfTargets = 0;
                        BAT(BatNum).CurrDetectedPreysPolarCoordinate.TargetsID = [];
                        BAT(BatNum).CurrDetectedPreysPolarCoordinate.Distances = [];
                        BAT(BatNum).CurrDetectedPreysPolarCoordinate.TargetAngle = [];
                        BAT(BatNum).CurrDetectedPreysPolarCoordinate.Bat2TargetRelativeAngle = [];
                        BAT(BatNum).CurrDetectedPreysPolarCoordinate.IsInBeam = [];
                    
                    end % if (BAT(BatNum).NumOfPreyDetected > 0)
                    
                    %% Acoustis Detections, Jamming, Classifier, and masking effects - Obstacles and Cluterr
                    
                    if AllParams.SimParams.DetectObs && BAT(BatNum).IsObs && AllParams.SimParams.AcousticsCalcFlag
                        try
                            % Nov2021 - 
                            Rx_Acoustic_WantedSig = BAT(BatNum).AcousticSig_Wanted(relevant_idx);
                            CurrDetectedEchoes = BAT(BatNum).EchosFromObsStruct(BAT(BatNum).CurrPulseNum);

                            [BAT(BatNum).Obs_MaskingStruct(BAT(BatNum).CurrPulseNum) ] = ...
                                Interfernce2DetectedPreys_Acoustics( CurrPulsePower , ...
                                BAT(BatNum).DetectedObs, CurrDetectedEchoes, Tx_Acoustic_Call, ...
                                Rx_Acoustic_WantedSig,  Rx_Acoustic_Sig, BAT(BatNum).CurrPulseNum, ...
                                BAT, BatNum, AllParams, FilterBank );

                        catch
                            oooppppsepse = '  '
                        end % 
                        
                    
                        %%%% XXX update the Obs Finding Struct by the acoustics Detections struct
                        try
                            
                            CurrPulseNum  = BAT(BatNum).CurrPulseNum;
                            ixDetectedObs = ismember(CurrDetectedEchoes.TargetIndex, BAT(BatNum).Obs_MaskingStruct(CurrPulseNum).DetectedPreys);
                            ixUnMasked    = setdiff(BAT(BatNum).Obs_MaskingStruct(CurrPulseNum).DetectedPreys, BAT(BatNum).Obs_MaskingStruct(CurrPulseNum).MaskedPreys);

                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).TransmittedPulseNum    = BAT(BatNum).CurrPulseNum;
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).IsAnyPreyDetected      = any(ixDetectedObs);
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).DetectedPreyNum        = BAT(BatNum).Obs_MaskingStruct(CurrPulseNum).DetectedPreys;
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).DetectedTimes          = CurrDetectedEchoes.EchosTimes(ixDetectedObs) ;
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).xFinds                 = BAT(BatNum).ObsInBeamStruct(CurrPulseNum).xOBSTC(ixDetectedObs);
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).yFinds                 = BAT(BatNum).ObsInBeamStruct(CurrPulseNum).yOBSTC(ixDetectedObs);

                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).Dist2DetectedPrey      = BAT(BatNum).ObsInBeamStruct(CurrPulseNum).Distances(ixDetectedObs);
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).Angle2DetectedPrey     = BAT(BatNum).ObsInBeamStruct(CurrPulseNum).TargetAngle(ixDetectedObs);
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).RxPowerOfDetectedPreys = BAT(BatNum).Obs_MaskingStruct(CurrPulseNum).DetectedPreysRxPower;
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).DetectionsDFerror      = BAT(BatNum).Obs_MaskingStruct(CurrPulseNum).DetectionsDFerror;
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).DetectionsRangeErr     = BAT(BatNum).Obs_MaskingStruct(CurrPulseNum).DetectionsRangeErr;
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).MaskedPreys            = BAT(BatNum).Obs_MaskingStruct(CurrPulseNum).MaskedPreys;
                            %%% Add Localization Errros
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).Distances              = BAT(BatNum).ObsInBeamStruct(CurrPulseNum).Distances(ixDetectedObs) + ...
                                BAT(BatNum).Obs_MaskingStruct(CurrPulseNum).DetectionsRangeErr;
                            BAT(BatNum).ObsFindsStruct(CurrPulseNum).Angles                 = BAT(BatNum).ObsInBeamStruct(CurrPulseNum).TargetAngle(ixDetectedObs) + ...
                                BAT(BatNum).Obs_MaskingStruct(CurrPulseNum).DetectionsDFerror;
% 
                            %                            BAT(BatNum).ObsFindsStructCurrPulseNum).Angle2DetectedPrey = BAT(BatNum).ObsInBeamStruct(CurrentPulseNum).TargetAngle(BAT(BatNum).DetectedObs);

                        catch
                            warning(['Bugg In updataing Clutter Acoutics Struct - ObsFindsStruct, PulseNum:', num2str(BAT(BatNum).CurrPulseNum)])
                        end %try

                    end %  if AllParams.SimParams.DetectObs && BAT(BatNum).isObs
                    
                    %% Acoustis Detections, Jamming, Classifier, and masking effects -Conspecigs wanted echoes (for swarm) =
                    %%%%% XXXXX NOT TESTED %%%%%%%

                    if AllParams.SimParams.DetectConsps
                        % Nov2021 - To Be Tested with SWARM
                         Rx_Acoustic_WantedSig = BAT(BatNum).AcousticSig_Wanted(relevant_idx);
                        CurrDetectedEchoes = BAT(BatNum).EchosFromConspStruct( BAT(BatNum).CurrPulseNum );

                        [BAT(BatNum).Consps_MaskingStruct(BAT(BatNum).CurrPulseNum) ] = ...
                            Interfernce2DetectedPreys_Acoustics( CurrPulsePower , ...
                            BAT(BatNum).Detected_Consps, CurrDetectedEchoes, Tx_Acoustic_Call, ...
                            Rx_Acoustic_WantedSig,  Rx_Acoustic_Sig, BAT(BatNum).CurrPulseNum, ...
                            BAT, BatNum, AllParams, FilterBank );
                        % update Consps_FindsStruct
                        BAT(BatNum).Consps_FindsStruct(BAT(BatNum).CurrPulseNum) = update_Consps_FindsStruct(BAT(BatNum));
                    end

                    %% Update the Struct of Finding - Prey 
                    %%% Nov2021
                        % general
                    try
                        CurrPulseNum = BAT(BatNum).CurrPulseNum;
                        CurrAllTargets = BAT(BatNum).EchosFromPreyStruct(CurrPulseNum).TargetIndex;
                        CurrAllTimes = round(BAT(BatNum).EchosFromPreyStruct(CurrPulseNum).EchosTimes) ...
                            + BAT(BatNum).TransmittedPulsesStruct(CurrPulseNum).StartPulseTime;
                        CurrDetTargets = BAT(BatNum).FindsMaskingStruct(CurrPulseNum).DetectedPreys; % All Targets befor Masking
                        ix_DetTargets = ismember(CurrAllTargets, CurrDetTargets);
                        [~, ix_DetPre] = ismember(CurrDetTargets,BAT(BatNum).CurrDetectedPreysPolarCoordinate.TargetsID); % the differnce between coerration and Peak detection
                        CurrUnMasked = setdiff(CurrDetTargets, BAT(BatNum).FindsMaskingStruct(CurrPulseNum).MaskedPreys, 'stable');
                        ix_UnMasked = ismember(CurrAllTargets, CurrUnMasked);
                        
                        
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).TransmittedPulseNum = CurrPulseNum;
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).IsAnyPreyDetected =  any(CurrDetTargets); %  BAT(BatNum).NumOfDetectedPreys > 0;
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).DetectedPreyNum = CurrUnMasked; ... % BAT(BatNum).DetectedPreysUnMasked;
                    
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).DetectedTimes = CurrAllTimes(ix_UnMasked);  % BAT(BatNum).DetectedTimesUnMasked;
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).PreyNumToHunt = 0;

                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).DetecectedPreyWithOutInterference = CurrDetTargets; % BAT(BatNum).DetectedPreys   ;
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).DetectedTimesWithOutInterfernece = CurrAllTimes(ix_DetTargets); % BAT(BatNum).DetectedPreyTimes(AllDetPreyIndex);
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).MissedPreysByProbabilty = BAT(BatNum).MissDetectedPreysByProb;
                        
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).Dist2DetectedPrey = ...
                            BAT(BatNum).CurrDetectedPreysPolarCoordinate.Distances(ix_DetPre); % (AllDetPreyIndex)
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).Angle2DetectedPrey = ...
                            BAT(BatNum).CurrDetectedPreysPolarCoordinate.TargetAngle(ix_DetPre); %(AllDetPreyIndex); 
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).PreyRelativeDirection = ...
                            BAT(BatNum).CurrDetectedPreysPolarCoordinate.Bat2TargetRelativeAngle(ix_DetPre); %(AllDetPreyIndex);

                        if BAT(BatNum).PreyFindsStruct(CurrPulseNum).IsAnyPreyDetected
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).MaskedPreys = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).MaskedPreys;
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).RxPowerOfDetectedPreys = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).DetectedPreysRxPower;
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).SIROfDetectedPreys = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).DetecetedPrey2InterferenceRatioDB;
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).SelfCorrealationMaxdB = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).SelfCorrealationMaxdB;
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).InterCorrelationMaxdB = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).InterCorrelationMaxdB;
                
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).xFinds = xFindsCurrentVec;
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).yFinds = yFindsCurrentVec;
                            
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).DetectionsDFerror = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).DetectionsDFerror;
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).DetectionsRangeErr = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).DetectionsRangeErr;
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).DetectionsRelativeDirectionErr = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).DetectionsRelativeDirectionErr;
                            
                            % FilterBank
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).FB_unmasked_prey = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).FB_unmasked_prey;
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).FB_unmasked_delays = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).FB_unmasked_delays;
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).FB_detected_masking_delays = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).FB_detected_masking_delays;
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).FB_estimated_masker = ...
                                BAT(BatNum).FindsMaskingStruct(CurrPulseNum).FB_estimated_masker;
                               
                        else % Update nonhunting
                            BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).PreyNumToHunt = ...
                                0;
                            BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).IsHuntedPreyMasked = ...
                                0;
                        end %if BAT(BatNum).PreyFindsStruct(CurrPulseNum).IsAnyPreyDetected
                        
                        % Clutter
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).ClutteredPrey = ...
                                BAT(BatNum).ClutteredPreyVec;
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).Clutter_nTimes = ...
                                 BAT(BatNum).ClutterednTimesVec;
                            
                        BAT(BatNum).Counters.PreyFindsStructCount = BAT(BatNum).Counters.PreyFindsStructCount+1;

                        % estimations with errors
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).Distances  = BAT(BatNum).PreyFindsStruct(CurrPulseNum).Dist2DetectedPrey + ...
                                BAT(BatNum).PreyFindsStruct(CurrPulseNum).DetectionsRangeErr;
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum).Angles = BAT(BatNum).PreyFindsStruct(CurrPulseNum).Angle2DetectedPrey + ...
                                BAT(BatNum).PreyFindsStruct(CurrPulseNum).DetectionsDFerror;
% 
                    catch % try 
                        opppassss = 'update PreyFindsStruct' 
                    end % try update PreyFindsStruct
                    % NEW 16/01
                    %% Bi-Stat Detection %%%
                    if AllParams.BatSonarParams.BiStatMode
                        % check  only for undetected prey if the bi-stat echo is stronger than detecton TH
                        % and than check if it would change the bat decision - only if it's stronger than the srorngest echo from prey
%                         try
                            [BAT(BatNum).BiStatDetection.Pulses(BAT(BatNum).CurrPulseNum) ] = BiStatPreyDetection(...
                                BAT(BatNum).BiStatDetection, ...
                                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).CurrPulseNum),...
                                BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits), AllParams);
%                         catch
%                             pop =' BiStatDetection'
%                         end % try BiStatDetection
                        
                        % check if BiStat detections are interferred -
                        % only if the bi-stat leads to hunting decision
                        if BAT(BatNum).BiStatDetection.Pulses(BAT(BatNum).CurrPulseNum).PreyToHuntBiSonar ~=0
%                             try
                                IsBiStatDetectionJammed = FindBiStatJamming(...
                                    BAT(BatNum).BiStatDetection.Pulses(BAT(BatNum).CurrPulseNum), ....
                                    BAT(BatNum).InterferenceFullStruct, AllParams);
%                             catch
%                                 pop= ' IsBiStatDetectionJammed'
%                             end % try
                            BAT(BatNum).BiStatDetection.Pulses(BAT(BatNum).CurrPulseNum).IsPreyJammed = IsBiStatDetectionJammed;
                            
                            % update PreyFindsStruct
                            if ~IsBiStatDetectionJammed
                                BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).IsAnyPreyDetected = 1;
% % %                                 BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).PreyNumToHunt = ...
% % %                                    BAT(BatNum).BiStatDetection.Pulses(BAT(BatNum).CurrPulseNum).PreyToHuntBiSonar;
                               BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).BiSonarDetection = 1;
                               BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).BiSonarPreyToHunt = ...
                                   BAT(BatNum).BiStatDetection.Pulses(BAT(BatNum).CurrPulseNum).PreyToHuntBiSonar;
                               BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).BiSonarAngle2Prey = ...
                                   BAT(BatNum).BiStatDetection.Pulses(BAT(BatNum).CurrPulseNum).Angle2HuntedPrey;
                                BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).BiSonarDist2Prey = ...
                                   BAT(BatNum).BiStatDetection.Pulses(BAT(BatNum).CurrPulseNum).Dist2HuntedPrey;
                             
                            else % if ~IsBiStatDetectionJammed
                                BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).BiSonarDetection = 0;
                                
                            end %    if ~IsBiStatDetectionJammed 
                        else % if BAT(BatNum).BiStatDetection.Pulses(BAT(BatNum).CurrPulseNum).PreyToHuntBiSonar ~=0
                            BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).BiSonarDetection = 0;
                        end % if if BAT(BatNum).BiStatDetection.Pulses(BAT(BatNum).CurrPulseNum).
                    end % if AllParams.BatSonarParams.BiStatMode
                        
                    %%    
                    %% Phantom echoes anlaysis
                    % New 26/06/19
                    
                    % the phantoms echoes will be anayzed as targets only
                    % if: (1) they are in the same phase as the transmitted
                    % call (option in AllParams) ; the phantom echos are
                    % not first
                
                    if AllParams.BatSonarParams.PhantomEchoesFromConsFlag
                        IsPhantomDetected = 0;
%                         try
                            [IsPhantomDetected, BAT(BatNum).CurrPhantomAnalysisStrct ] = PhantomAnalysis(...
                                BAT(BatNum).PhantomEchoesStrct, ...
                                BAT(BatNum).TransmittedPulsesStruct(BAT(BatNum).CurrPulseNum),...
                                BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits), AllParams);
                            
                            if IsPhantomDetected
                                %%% update PreyFindsStruct
                                BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits) = ...
                                    MergeStructs( BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits), ...
                                    BAT(BatNum).CurrPhantomAnalysisStrct);
                            end % IsPhantomDetected
%                         catch
%                             oops = 'PhantomAnalysis'
%                         end % try
                    end % if AllParams.BatSonarParams.PhantomEchoesFromConsFlag
                    
                    %% Jamming  of Conspecic Echoes
                    
% %                     if strcmp(AllParams.SimParams.TestMode, 'swarm') 
% %                         if BAT(BatNum).NumOf_Consps_Detected > 0
% %                             try
% %                                 [BAT(BatNum).Consps_MaskingStruct(BAT(BatNum).CurrPulseNum) ] = ...
% %                                     Interfernce2DetectedPreys( CurrPulsePower , ...
% %                                     BAT(BatNum).Detected_Consps, BAT(BatNum).EchosFromConspStruct( BAT(BatNum).CurrPulseNum ), ...
% %                                     BAT(BatNum).InterferenceDirectVec, ...
% %                                     BAT(BatNum).InterferenceVec,  BAT(BatNum).InterferenceFullStruct, BAT(BatNum).CurrPulseNum, ...
% %                                     BAT, BatNum, AllParams, FilterBank );
% %                                 
% %                                 % update Consps_FindsStruct
% %                                  BAT(BatNum).Consps_FindsStruct(BAT(BatNum).CurrPulseNum) = update_Consps_FindsStruct(BAT(BatNum));
% %                             catch
% %                                 warning(['bug!!!1-  Interfernce2DetectedPreys - Consp , BAT: ', num2str(BatNum), 'Pulse', num2str(BAT(BatNum).CurrPulseNum)])
% %                             end % try
% %                         end % if BAT(BatNum).EchosFromConspStruct( BAT(BatNum).CurrPulseNum ).NumOfEchos > 0
% %                         
% %                         
% %                         
% %                     end % if strcmp(AllParams.SimParams.TestMode, 'swarm')
                                
                    %% Manuever Decision %%%
                    CurrPulseNum = BAT(BatNum).CurrPulseNum;
                    TempAllDetectedPreys =  BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).DetecectedPreyWithOutInterference;
                    UnMaskedDetections = BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).DetectedPreyNum;

                    
                    PrevManCmdSrtruct = BAT(BatNum).ManueverCmdStruct(CurrPulseNum);

                   try
                      
                        relObsFindsStruct =   BAT(BatNum).ObsFindsStruct(CurrPulseNum);
                       
                        BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1) = BatManueverDecision( ...
                            BAT(BatNum).PreyFindsStruct(CurrPulseNum) , relObsFindsStruct, ... % BAT(BatNum).ObsInBeamStruct(CurrentPulseNum), ...
                            BAT(BatNum).OtherBatsPolarCoordinates, BAT(BatNum).BatVelocity(nTime),...
                            PrevManCmdSrtruct, CurrPulseNum, BAT(BatNum), AllParams, Terrain, nTime, false); % last variable is degug_flag

                        BAT(BatNum).ManueverType = BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).ManueverType;
                        BAT(BatNum).ManueverPower = BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).ManueverPower;
                        BAT(BatNum).ManDirectionCommand = BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).ManDirectionCommand;
                        BAT(BatNum).ManAccelCommand = BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).ManAccelCommand;
                        
                        %%%%% Crushes NEW Jun22 
                        % consps - update telemetry
                        if BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).BatCrush 
                            BAT(BatNum).CrushesConspsNum    = BAT(BatNum).CrushesConspsNum + 1;
                            BAT(BatNum).CrushesConspsnTimes = [BAT(BatNum).CrushesConspsnTimes, nTime];
                        end % BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).BatCrush 
                        
                        % Obs - also update new postion and angle of the bat
                        if BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).ObsCrush
                            
                            %%%% update Crushes only if it is a new crush (previous check was negative)
                            if ~BAT(BatNum).ManueverCmdStruct(CurrPulseNum).ObsCrush
                                BAT(BatNum).CrushesObsNum    = BAT(BatNum).CrushesObsNum + 1;
                                BAT(BatNum).CrushesObsnTimes = [BAT(BatNum).CrushesObsnTimes, nTime];         
                            end % if BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).ObsCrush
                            %%%%% Move The bat to the recovery position onlt if Necessary
                            if ~isempty(BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).tetaRecover)
                                BAT(BatNum).xBati(nTime) = BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).xRecover;
                                BAT(BatNum).yBati(nTime) = BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).yRecover;
                                BAT(BatNum).Teta(nTime)  = BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).tetaRecover;
                            end % if  ~isempty(tetaTocover)

                        end % BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).BatCrush

                        
                    catch
                        pop = ['Drekk BatManueverDecision, PulseNum: ', num2str(CurrPulseNum), ' BatNum= ', num2str(BatNum)]
                    end % try
                    
                    %%% update PreyFindsStruct (hunted prey feilds)
                    % accorrding to the decision
                    if ~isempty(TempAllDetectedPreys)
                        BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).PreyNumToHunt = ...
                            BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).PreyNumToHunt;
                        BAT(BatNum).PreyFindsStruct(BAT(BatNum).NumOfTimesSonarTransmits).IsHuntedPreyMasked = ...
                            BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).HuntedPreyMaskedFlag;
                        % Conspeifics echoes (swarm)
                       BAT(BatNum).Counters.BatManueCounter =  BAT(BatNum).Counters.BatManueCounter+1;

                    end
                    try
                    BAT(BatNum).Consps_FindsStruct(CurrPulseNum).IsHuntedPreyMasked = ...
                            BAT(BatNum).ManueverCmdStruct(CurrPulseNum+1).Relevant_ConspEcho_Masked;
                    catch
                        warning(['line 1593:', 'Pusle= ', num2str(CurrPulseNum), ' BatNum= ', num2str(BatNum)]')
                    end % try
                end % if tTimeToReceiveSignal < PulseCurrMaxRecievedTime
                
            end %if WaitForRecievedPulseFlag
            %%%% END OF Receiving the Pulse %%%%
            
            %%
            %%%% Movement of the BAT%%%
            CurrPulseNum = BAT(BatNum).NumOfTimesSonarTransmits;
%             try % switch BAT(BatNum).ManueverType
                switch BAT(BatNum).ManueverType
                    case 'Hunting'
                        BAT(BatNum).HuntingFlag(nTime) = 1;
                        BAT(BatNum).HuntedPrey(nTime) = BAT(BatNum).ManueverCmdStruct(CurrPulseNum).PreyNumToHunt;
                        BAT(BatNum).PreyFindsStruct(CurrPulseNum).PreyNumToHunt = ...
                            BAT(BatNum).ManueverCmdStruct(CurrPulseNum).PreyNumToHunt;
                    case 'ObsMan'
                        BAT(BatNum).ObsManueverFlag(nTime) = 1;
                end % switch BAT(BatNum).ManueverType
%             catch
%                 pop = 'switch hunting'
%             end % try % switch BAT(BatNum).ManueverType
            try
               
                [BAT(BatNum).xBati(nTime+1), BAT(BatNum).yBati(nTime+1), BAT(BatNum).Teta(nTime+1),...
                    BAT(BatNum).BatVelocity(nTime+1), BAT(BatNum).BatDteta(nTime+1)] =  ...
                    BatMovemet...
                    (BAT(BatNum).ManueverCmdStruct(CurrPulseNum), ...
                    BAT(BatNum).xBati(nTime),BAT(BatNum).yBati(nTime), BAT(BatNum).Teta(nTime), BAT(BatNum).BatVelocity(nTime),...
                    BAT(BatNum).BatDteta(nTime), BAT(BatNum).CurrentTimeToSonar, BAT(BatNum).nTimeToSonar, AllParams, RoomLimits);
            catch
                pop = 'BatMovement probably ???'
            end % try of BatMovemnt
            %%
            %%% calculate Distances to Preys and CHECK for a CATCH
            % The Distances between the Bat and the preys, Assuming the
            % prey is slow so calculte only on pulses
            
            for nPrey = 1:NumberOfPreys
                Dist2Prey = BAT(BatNum).PreysPolarCoordinate.Distances(nPrey);
                Angle2Prey = BAT(BatNum).PreysPolarCoordinate.TargetAngle(nPrey);
                
                BAT(BatNum).Vector2Preys(nPrey).Dist2Prey(nTime) = Dist2Prey;
                BAT(BatNum).Vector2Preys(nPrey).Angle2Prey(nTime) = Angle2Prey;
                BAT(BatNum).Vector2Preys(nPrey).RelativeDirection(nTime) = ...
                    BAT(BatNum).PreysPolarCoordinate.Bat2TargetRelativeAngle(nPrey); 
                NumberOfCatchesOrOne = max(BAT(BatNum).NumberOfCatches, 1);
                if (Dist2Prey <= minCatchPreyDistanceXY) &&...
                      ((nTime - BAT(BatNum).CatchPreyTimes(NumberOfCatchesOrOne)) > BAT(BatNum).CurrentTimeToSonar ) 
                    BAT(BatNum).NumberOfCatches = BAT(BatNum).NumberOfCatches+1;
                    NumberOfCatches = BAT(BatNum).NumberOfCatches;
                    BAT(BatNum).CatchPreyTimes(NumberOfCatches) = nTime;
                    BAT(BatNum).CatchPreyPos(NumberOfCatches,:) = [PREY(nPrey).xPrey(nTime), PREY(nPrey).yPrey(nTime)];
                    BAT(BatNum).CatchPreyNum(NumberOfCatches) = nPrey;
                    BAT(BatNum).CatchPulseNum(NumberOfCatches) = BAT(BatNum).NumOfTimesSonarTransmits;
                    BAT(BatNum).ManueverCmdStruct(CurrPulseNum).IsHuntedCaughtFlag = 1;
                    
                    PREY(nPrey).IsCaught = 1;
                    PREY(nPrey).CaughtTime = nTime.*SampleTime;
                    
% % %                     "new" prey in random place
                    [ PREY(nPrey).xPrey(nTime+1), PREY(nPrey).yPrey(nTime+1), PREY(nPrey).PreyTeta(nTime+1), ~] = ...
                        InitPosition(RegTimeToSonar, Xmax, Ymax, xyResolution, Terrain, AllParams, 'Prey', nPrey);
                else % if PreyDistance, the prey is still alive and flying
                end % if PreyDistance <= CatchPreyDistance
            end % for nPrey = 1:NumberOfPreys
            %%
            %%% updating temporal indices
            BAT(BatNum).nTimeToMan = BAT(BatNum).nTimeToMan -1;
            BAT(BatNum).nTimeToSonar = BAT(BatNum).nTimeToSonar -1;
            %%
            % for Analyzing
            BAT(BatNum).ManueverTypeCell{nTime} = BAT(BatNum).ManueverType;
            BAT(BatNum).ManueverPowerCell{nTime} = BAT(BatNum).ManueverPower;
            BAT(BatNum).nTimeToSonarVec(nTime) = BAT(BatNum).nTimeToSonar;
            BAT(BatNum).CurrentTimeToSonarVec(nTime) = BAT(BatNum).CurrentTimeToSonar;
            BAT(BatNum).nTimeToManVec(nTime) = BAT(BatNum).nTimeToMan;
%             BAT(BatNum).nTimeToSonarPulseVec(nTime) = BAT(BatNum).nTimeToSonarPulse;
            BAT(BatNum).nTimeToReceiveSignalVec(nTime) = BAT(BatNum).nTimeToReceiveSignal;
            BAT(BatNum).PulseRecievedTimeToAnalyzeVec(nTime) = BAT(BatNum).PulseRecievedTimeToAnalyze;
            BAT(BatNum).CurrentPulseWidthVec(nTime) = BAT(BatNum).CurrentPulseWidth;
            BAT(BatNum).PulseDurationVec(nTime) = BAT(BatNum).CurrentPulseDuration;            
            BAT(BatNum).PulseFreqsCommandVec(nTime) =  BAT(BatNum).PulseFreqsCommand(1);
        end %if nTime > T0
    end % for BatNum = 1:NumberOfBats
    %%% % progress bar %%%%
%     if getappdata(h,'canceling')
%         break
%     end
%     
end  % for nTime - Time

%%%%%%%%%%%%%%%

delete(hWaitBar); % progress bar
%%
%%%%%%%%%
% Final DATA
%%%%%%%%%%

%%% PREY location in meter
for PreyNum = 1:NumberOfPreys
    PREY(PreyNum).xPrey = PREY(PreyNum).xPrey*xyResolution;
    PREY(PreyNum).yPrey = PREY(PreyNum).yPrey*xyResolution;
end % for PreyNum = 1:NumberOfPreys

OutputData.PREY = PREY;

%%% BATS
for BatNum = 1:NumberOfBats
    
    %% SONAR and Sounds DATA %%%
    try
        [BAT(BatNum).BatSonogram, BAT(BatNum).BatSonarEchosMat, BAT(BatNum).PreyEchosVec, BAT(BatNum).ObsEchosVec] = ...
            BuildSonogram(...
            BAT(BatNum).NumOfTimesSonarTransmits, BAT(BatNum).TransmittedPulsesStruct ,...
            BAT(BatNum).NumOfTimesObsFinds ,BAT(BatNum).EchosFromObsStruct ,...
            BAT(BatNum).NumOfTimesSonarTransmits, BAT(BatNum).EchosFromPreyStruct, BAT(BatNum).PulseWidthVec, BAT(BatNum).PulsePower, AllParams );
        if strcmp(AllParams.SimParams.TestMode, 'swarm') || AllParams.SimParams.DetectConsps
            [~, BAT(BatNum).Bat_Consp_SonarEchosMat, BAT(BatNum).Consps_EchosVec, ~] = ...
            BuildSonogram(...
            BAT(BatNum).NumOfTimesSonarTransmits, BAT(BatNum).TransmittedPulsesStruct ,...
            BAT(BatNum).NumOfTimesObsFinds ,BAT(BatNum).EchosFromObsStruct ,...
            BAT(BatNum).NumOfTimesSonarTransmits, BAT(BatNum).EchosFromConspStruct, BAT(BatNum).PulseWidthVec, BAT(BatNum).PulsePower, AllParams );
        end % if strcmp(AllParams.SimParams.TestMode, 'swarm')
    catch
        pop = 'BuildSonogram'
    end % try
    try
    BAT(BatNum).BatSonogramWithInterference = ...
          BuildInterferenceSonogramFromOnLine(BAT(BatNum) , AllParams, BAT(BatNum).BatSonogram);
     catch
        pop = 'BuildInterferenceSonogramFromOnLine'
    end % try

     %%% for MySonogram 
    BAT(BatNum).AllInterPulses = BAT(BatNum).InterferenceVec;
    BAT(BatNum). AllInterFromEchosPulses = BAT(BatNum).InterferenceVec  - BAT(BatNum).InterferenceDirectVec + NoiseLevel;
    
    
    %%% positions in meter coordinates
    % Bats Position
    BAT(BatNum).xBatPos = BAT(BatNum).xBati*xyResolution;
    BAT(BatNum).yBatPos = BAT(BatNum).yBati*xyResolution;
    BAT(BatNum).BatX0 = BAT(BatNum).BatX0*xyResolution;
    BAT(BatNum).BatY0 = BAT(BatNum).BatY0*xyResolution;
    % Finds Position
    if BAT(BatNum).NumOfTimesObsFinds >0
        [BAT(BatNum).xObsFinds, BAT(BatNum).yObsFinds, BAT(BatNum).nTimesObsFinds] = ...
            FindsStruct2Vec( BAT(BatNum).NumOfTimesObsFinds, BAT(BatNum).ObsFindsStruct, xyResolution,'Obs');
    else % if BAT(BatNum).NumOfTimesObsFinds >0
        BAT(BatNum).xObsFinds = [];
        BAT(BatNum).yObsFinds = [];
        BAT(BatNum).nTimesObsFinds = 0;
    end % if BAT(BatNum).NumOfTimesObsFinds >0
    
    if BAT(BatNum).NumOfTimesPreyFinds > 0
%         try
        [BAT(BatNum).xPreyFinds, BAT(BatNum).yPreyFinds, BAT(BatNum).nTimesPreyFinds] =...
            FindsStruct2Vec( BAT(BatNum).NumOfTimesPreyFinds, BAT(BatNum).PreyFindsStruct, xyResolution,'Prey');
%         catch
%             pop= [' FindsStruct2Vec : BatNum:' , BatNum]
%         end % try
    else % if BAT(BatNum).NumOfTimesPreyFinds
        BAT(BatNum).xPreyFinds = [];
        BAT(BatNum).yPreyFinds = [];
        BAT(BatNum).nTimesPreyFinds = [];
    end % if BAT(BatNum).NumOfTimesPreyFinds
    
%     NumberOfTimesDetectedPrey =  BAT(BatNum).NumOfTimesPreyFinds;
%     BAT(BatNum).tPreyFinds = zeros(1,NumberOfTimesDetectedPrey);
%     BAT(BatNum).PreyNumFound = zeros(1,NumberOfTimesDetectedPrey);
    
    %     %%% Catchings and Distances of the Prey
    for kPrey = 1:NumberOfPreys
        BAT(BatNum).Vector2Preys(kPrey).Dist2Prey = BAT(BatNum).Vector2Preys(kPrey).Dist2Prey .* xyResolution;
    end % for kPrey
    BAT(BatNum).CatchPreyTimes = BAT(BatNum).CatchPreyTimes(find(BAT(BatNum).CatchPreyTimes))*SampleTime;
    
    [row,col,val] = find(BAT(BatNum).CatchPreyPos);
    if BAT(BatNum).NumberOfCatches >0
        try
            CatchPreyPos = BAT(BatNum).CatchPreyPos(row(1:BAT(BatNum).NumberOfCatches),:)*xyResolution;
            BAT(BatNum).CatchPreyPos = CatchPreyPos;
        catch
            hops= ['BatFlightForGui: CatchPreyPos = BAT(BatNum).CatchPreyPos(row(1:BAT(BatNum).NumberOfCatches),:)*xyResolution;'];
        end % try
    end % if BAT(BatNum).NumberOfCatches >0
    
end % for BatNum



 
 %%
 %%% Analysis of Interfernce Level %%%
 
 for BatNum = 1:NumberOfBats
     %%% InterReportStrctOnLine should replace InterReportStrct in future
     %%% versions
     try
% %      [BAT(BatNum).InterReportStrct, BAT(BatNum).InterReportStrctOnLine] =  ...
% %          AnalyzeCrossInterfernceFromOnLine(BAT(BatNum),AllParams);
      [ BAT(BatNum).InterReportStrctOnLine] =  ...
         AnalyzeCrossInterfernceFromOnLine(BAT(BatNum),AllParams);
     catch
         pop = 'AnalyzeCrossInterfernceFromOnLine :  ppooops'
     end % try
 end %for BatNum = 1:NumberOfBats
 
 
     %%%% Summary of Interference

% 
 AnalyzeTypeFlag= 'OnLine';   % to AllParams
 try
    FlightInterferceSummary = SumReportOfInterference(BAT, NumberOfBats, NumberOfPreys, AllParams, AnalyzeTypeFlag);
 catch
      pop = 'SumReportOfInterference'
 end % try
 
 %%  SWARM Analysys
 if strcmp(AllParams.SimParams.TestMode, 'swarm')
     OutputData.SwarmSummary = swarm_anlysis(BAT, AllParams);
 end % if strcmp(AllParams.SimParams.TestMode, 'swarm')
 
 
 %%
% FilghtInterferceSummary.TotaInterferfenceRatio = FilghtInterferceSummary.TotaInterferfenceToDetections ./ FilghtInterferceSummary.TotalNumOfPreyDetections;

%%
%%% Saving the Parameters
OutputData.BAT = BAT;
OutputData.AllParams = AllParams;
OutputData.FlightInterferceSummary = FlightInterferceSummary;
OutputData.FilterBank = FilterBank;


warning ('on','all')

