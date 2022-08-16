function [ManueverCmdStruct] = ...
    BatManueverDecision(PreyFindsStruct , FoundObstacles, Struct2OtherBats, CurrentVelocity,...
    PrevManCmdSrtruct, AnalyzedPulseNum, BAT, AllParams, Terrain, nTime, debugObsFlag)


%
% function [ManueverType, ManueverPower] = BatManueverDecision(FoundPreys , FoundObsicles, PrevManType, PrevManPower)
% this fuction returns the bat's decision for the desired manuver to
% operate
%   INPUTS :
%           PreyFindsStruct - a sturct of the  preys the were detected 
%           FoundObstacles - a strcut of the obtacles tha were found
%           Struct2OtherBats - 
%           CurrentVelocity - of the bat
%           PrevManCmdSrtruct = the struct of the previous command 
%           SimParameters -
%   Outputs:
% ManueverCmdStruct = struct(...
%     'MaunuverStage', [] , ... % 'Search' / 'Approach' /'Buzz' / 'ObstacleManuver' / 'AvoidBatMan'
%     'ManueverType', [], ... % 'Hunting', Foraging', 'ObsMan', /'AvoidBatMan' / 'RegularBatAvoid'
%     'ManueverPower',[], ... % 'RegularForaging' / 'RegularHunt',  'Buzz'
%               / 'RegularManuever' or 'CrushAvoidance' / 'AvoidBatMan'
%     'PreyNumToHunt', 0, ...
%     'Dist2HuntedPrey', nan, ...
%     'Angle2HuntedPrey', nan, ...
%     'PreyRelativeDirection', nan, ...
%     'LastNDetections', zeors(1, NPulsesBack), ...
%     'IsHuntedCaughtFlag', 0, ... 
%     'HuntedPreyMaskedFlag', 0, ...
%     'ManDirectionCommand', 'None', ... % 'None' or 'Right' or 'Left' 
%     'ManAccelCommand','None', ... % 'None' 'SlowDown' or 'Accelerate'
%     'BatToAvoid', 0, ...
%     'Dist2Bat', nan, ...
%     'Angle2Bat', nan, ...
%     'BatRelativeDirection', 0 ... 
%     );

%%% Changed 21Jan21 - Swarm Bat Reaction 


%% Init and Consts
% Stage Parameteres
AngleToBuzz = AllParams.BatFlightParams.AngleToBuzz; % move to All Params
AngleToApproach = AllParams.BatFlightParams.AngleToApproach;

NPulsesBack = AllParams.BatFlightParams.HuntedMemorySize; % the momory for last N pulses 
KPrevNeeded = AllParams.BatFlightParams.NumOfSamePreyForAppraoach; % K - Number of huntng


%%% General parameters
xyResolution = AllParams.SimParams.xyResolution;
SampleTime = AllParams.SimParams.SampleTime;
MinDistanceAllowed = AllParams.BatFlightParams.MinDistanceAllowed /xyResolution;
NominalVelocity = AllParams.BatFlightParams.NominalVelocity * SampleTime/xyResolution;
% DitanceToBuzz = 0.4 / xyResolution; % the Distance from the prey that the bat is goin to Buzz
DistanceToBuzz = AllParams.BatFlightParams.DistanceToBuzz / xyResolution ;
DistanceToApproach = AllParams.BatFlightParams.DistanceFromPreyToApproach / xyResolution ;
MaxAngleToManuever = pi/2; % The maximum angle between the bat and the prey  that the bat will try to catch
MinDist2OtherBat = 0.2 / xyResolution; % the Distance from the other bat that initiate avoidance manuever
AngleFieldWidth = pi/3; % The Max angle to react to other bats
MaxAccel = AllParams.BatFlightParams.MaxAccelaration * SampleTime^2/xyResolution;
MinManueverRadius = CurrentVelocity.^2/MaxAccel;
BeamWidth = AllParams.BatSonarParams.BatBeamWidth;
MinDistanceAllowed_obs = MinDistanceAllowed*8; % XXX - Dorin
DistToReactObstacle = AllParams.BatFlightParams.DistToReactObstacle / xyResolution;
% False allarms from maskers
JamFalseAlarmFlag = 0;
FilterBankFlag = strcmp(AllParams.BatSonarParams.ReceiverType, 'FilterBank');
%%% InputParams
AllDetectedPreys = PreyFindsStruct.DetecectedPreyWithOutInterference;
%%% XXXXXX
UmMaskedDetectedPreys = nonzeros(PreyFindsStruct.DetectedPreyNum)';


%% NEW 25/07/22 Obstacle Memory for Cave Exit and Obstacle Avoidance
%%%% add memory of the evironment from previous pulses %%%%%%%%% 

ObsMemSize = AllParams.BatSonarParams.ObsMemorySize; % The previous number of pulses to remember                      

if ObsMemSize > 1 && AnalyzedPulseNum > 1
    calcTime = BAT.TransmittedPulsesStruct(AnalyzedPulseNum).StartPulseTime;
    minPulse = max(1,AnalyzedPulseNum-ObsMemSize);
    % the prev detections
    prev_DetectedPreyNum = [BAT.ObsFindsStruct(minPulse:AnalyzedPulseNum-1).DetectedPreyNum];
    prev_xFinds = [BAT.ObsFindsStruct(minPulse:AnalyzedPulseNum-1).xFinds];
    prev_yFinds = [BAT.ObsFindsStruct(minPulse:AnalyzedPulseNum-1).yFinds];
    dY = prev_yFinds- BAT.yBati(calcTime)  ;
    dX = prev_xFinds- BAT.xBati(calcTime) ;

    % calculate the polar coordinations relative to
    % the current position
    prevDist   = sqrt(dY.^2 +  dX.^2);
    prevAngles = atan2(dY, dX) - BAT.Teta(calcTime) ;

    % Add the memory to the current Sturct
    FoundObstacles.DetectedPreyNum = [prev_DetectedPreyNum, BAT.ObsFindsStruct(AnalyzedPulseNum).DetectedPreyNum];
    FoundObstacles.Distances       = [prevDist,    BAT.ObsFindsStruct(AnalyzedPulseNum).Distances];
    FoundObstacles.Angles          = [prevAngles,  BAT.ObsFindsStruct(AnalyzedPulseNum).Angles];

else % memSize == 1 | 0
    % Do Nothing
    prevDist    = [];
    prevAngles  = [];
    prev_xFinds = [];
    prev_yFinds = [];
end

%% NEW - 23/04/19 Bi-Stat Detection
% add detection from bistat to the findings vectors 
% in bi stats detection the bat doesnt estimate the distance from prey- we
% assume approach distnce
% We take the angle to the prey, with error 10 degree std 
Dist2DetectedPrey = PreyFindsStruct.Dist2DetectedPrey ;
Angle2DetectedPrey = PreyFindsStruct.Angle2DetectedPrey ;
PreyRelativeDirection = PreyFindsStruct.PreyRelativeDirection  ;
DetectionsRangeErr = PreyFindsStruct.DetectionsRangeErr;
DetectionsDFerror = PreyFindsStruct.DetectionsDFerror;
DetectionsRelativeDirectionErr = PreyFindsStruct.DetectionsRelativeDirectionErr; 

if AllParams.BatSonarParams.BiStatMode ...
        && PreyFindsStruct.BiSonarDetection ~=0
    AllDetectedPreys = [AllDetectedPreys, PreyFindsStruct.BiSonarPreyToHunt];
    UmMaskedDetectedPreys = [UmMaskedDetectedPreys, PreyFindsStruct.BiSonarPreyToHunt];
    Dist2DetectedPrey = [Dist2DetectedPrey,  ...
        AllParams.BatFlightParams.DistanceFromPreyToApproach / xyResolution]; % 
    AngleErr = 10/180*pi *randn(1);
    Angle2DetectedPrey = [Angle2DetectedPrey, PreyFindsStruct.BiSonarAngle2Prey + AngleErr];
    PreyRelativeDirection = [PreyRelativeDirection, 0];
    DetectionsRangeErr = [DetectionsRangeErr, 0];
    DetectionsDFerror = [DetectionsDFerror, 0];
    DetectionsRelativeDirectionErr = [DetectionsRelativeDirectionErr, 0]; 
    
end % if AllParams.BatSonarParams.BiStatMode


%% New 23/8/19 - FilterBank Decision
if FilterBankFlag
    % update the detection list with flase-alarms from masking
    if ~isempty(PreyFindsStruct.FB_detected_masking_delays)
        V0 = AllParams.SimParams.SoundV0;  % sound velocity
        ts_us = 1./AllParams.BatSonarParams.FilterBank_Fs;
        unkwn_marker = -10*AllParams.SimParams.TotalBatsNumber; % uniqe marker for unknown maskers
        detected_masker = PreyFindsStruct.FB_estimated_masker; %
        % estimated distance is v*t/2
        Dist2Masker = 0.5 * PreyFindsStruct.FB_detected_masking_delays*ts_us *V0 / xyResolution;
        
        % estimated angles- according to the position of the masker
        % if the masker is unkown - random between -pi and pi
        id_est_masker = find(detected_masker);
        Angle2Masker = (rand(size(detected_masker))-0.5)*2*pi;
        RelativeDirection2Masker = rand(size(detected_masker))*pi;
        
        if ~isempty(id_est_masker)
            [masker_in_sturct_id, d] = dsearchn(Struct2OtherBats.TargetsID', detected_masker(id_est_masker)');
            id_true = masker_in_sturct_id(d== 0);
            Angle2Masker(id_est_masker(d==0)) = ...       % 
                Struct2OtherBats.TargetAngle(id_true);
            RelativeDirection2Masker(id_est_masker((d==0))) = ...
                Struct2OtherBats.Bat2TargetRelativeAngle(id_true);
        end %if ~isempty(id_est_masker)
        detected_masker = -detected_masker;  % masker are negative :-)
        
        
        zero_errs = zeros(size(detected_masker));
        detected_masker(detected_masker==0) = unkwn_marker; % -1 for un recognized masker
        AllDetectedPreys = [AllDetectedPreys, detected_masker];
        UmMaskedDetectedPreys = [UmMaskedDetectedPreys, detected_masker];
        Dist2DetectedPrey = [Dist2DetectedPrey, Dist2Masker]; %
        Angle2DetectedPrey = [Angle2DetectedPrey, Angle2Masker];
        PreyRelativeDirection = [PreyRelativeDirection, RelativeDirection2Masker];
        DetectionsRangeErr = [DetectionsRangeErr, zero_errs];
        DetectionsDFerror = [DetectionsDFerror, zero_errs];
        DetectionsRelativeDirectionErr = [DetectionsRelativeDirectionErr, zero_errs];
    end % if ~isemapty(PreyFindsStruct.FB_detected_masking_delays)
    
end % if FilterBangFlag

%% New 27/6/19  - Phantom  Echoes
if AllParams.BatSonarParams.PhantomEchoesFromConsFlag && ...
       (~isempty(PreyFindsStruct.PhantomIsDetected) && (PreyFindsStruct.PhantomIsDetected ==1))
    
    AllDetectedPreys                = [AllDetectedPreys, PreyFindsStruct.PhantomPreyNum];
    UmMaskedDetectedPreys           = [UmMaskedDetectedPreys, PreyFindsStruct.PhantomPreyNum];
    Dist2DetectedPrey               = [Dist2DetectedPrey,  PreyFindsStruct.PhantomEstimatedDistance] ; 
    Angle2DetectedPrey              = [Angle2DetectedPrey, PreyFindsStruct.PhantomEstimatedAngle];
    PreyRelativeDirection           = [PreyRelativeDirection, 0];
    DetectionsRangeErr              = [DetectionsRangeErr, 0];
    DetectionsDFerror               = [DetectionsDFerror, 0];
    DetectionsRelativeDirectionErr  = [DetectionsRelativeDirectionErr, 0];
    
    
end % if Allparams



%% Build OutPut with default Decision- Foraging

followObsFlag =false;

FN = fieldnames(PrevManCmdSrtruct);
ManueverCmdStruct = cell2struct(repmat({0},numel(FN),1),FN);
% which of them defines the swarm mode? on which mode should we initialize
% the simulator?
ManueverCmdStruct.PulseNumToAnalyze = AnalyzedPulseNum;
ManueverCmdStruct.ManueverStage = 'Search';  % 'Search' / 'Approach' /'Buzz' / 'ObstacleManuver'/ 'AvoidBatMan'
ManueverCmdStruct.ManueverType = 'Foraging';  % 'Hunting', 'Foraging', 'ObsMan', /'AvoidBatMan' / 'RegularBatAvoid'
ManueverCmdStruct.ManueverPower  = 'RegularForaging';
ManueverCmdStruct.PreyNumToHunt = 0;
ManueverCmdStruct.Dist2HuntedPrey = nan;
ManueverCmdStruct.Angle2HuntedPrey = nan;
ManueverCmdStruct.PreyRelativeDirection = nan;
ManueverCmdStruct.IsHuntedCaughtFlag = 0;
ManueverCmdStruct.HuntedPreyMaskedFlag = 0;
ManueverCmdStruct.ManDirectionCommand = 'None';
ManueverCmdStruct.ManAccelCommand = 'None';
ManueverCmdStruct.BatToAvoid                = 0;
ManueverCmdStruct.Dist2Bat                  = nan;
ManueverCmdStruct.Angle2Bat                 = nan;
ManueverCmdStruct.BatRelativeDirection      = nan;
ManueverCmdStruct.ReactToBat                = 0;
ManueverCmdStruct.Dist2ReactBat             = nan;
ManueverCmdStruct.BatToReact                = nan;
ManueverCmdStruct.JamFalseAlarmFlag         = JamFalseAlarmFlag;
ManueverCmdStruct.Relevant_ConspEcho_Masked = 0;
ManueverCmdStruct.BatCrush                  = 0;
ManueverCmdStruct.ObsCrush                  = 0;
ManueverCmdStruct.xRecover                  = []; % the stating pot of thr Call
ManueverCmdStruct.yRecover                  = [];
ManueverCmdStruct.tetaRecover               = [];

tempManAccelCommand = 'None';

% ManueverType = 'Foraging';
% ManueverPower = 'RegularForaging';
% SpecManCommandStrct.PreyNumToHunt = 0;
% SpecManCommandStrct.HuntedPreyMaskedFlag = 0;
% ManDirectionCommand = 'None';
% ManAccelCommand = 'None';

%%%% React to other  Bats Decision %%%%
%%% Override hunting
%%
NumberOfOtherBats = Struct2OtherBats.NumOfTargets;
BatCrushDist = 0.1; % distanceof other bats crush

if NumberOfOtherBats > 0
    MinDist_all = inf;
    BatsDistances =  Struct2OtherBats.Distances;
    BatsVecAngles = Struct2OtherBats.TargetAngle;
    BatsRelativeDirection = Struct2OtherBats.Bat2TargetRelativeAngle;
    TargetsID = Struct2OtherBats.TargetsID; % NEW
end % end % if NumberOfOtherBats > 0

switch AllParams.SimParams.TestMode
    case 'foraging'
        %% FORAGING: Hunting Decision - when there are preys in front of the beam %%%
        %Init Logic Parameters
        % KeepHuntingAfterPrevFlag = 0;
        KeepHuntWithoutDetection = 0;
        ManueverByPrevStageFlag = 0; %

        BatPrevManStage = PrevManCmdSrtruct.ManueverStage;

        %%% Add error estimation to targets' localization %%%
        errFlag = AllParams.BatSonarParams.LocalizationErrFlag; % '1' if ti is require to add error, '0' otherwise

        % corection of possible bugs:
        if numel(Dist2DetectedPrey) ~= numel(DetectionsRangeErr)
            DetectionsRangeErr = [DetectionsRangeErr, zeros(size(Dist2DetectedPrey))];
            DetectionsRangeErr = DetectionsRangeErr(1:numel(Dist2DetectedPrey));
            DetectionsDFerror = [DetectionsDFerror, zeros(size(Dist2DetectedPrey))];
            DetectionsDFerror = DetectionsDFerror(1:numel(Dist2DetectedPrey));
            DetectionsRelativeDirectionErr = [DetectionsRelativeDirectionErr, zeros(size(Dist2DetectedPrey))];
            DetectionsRelativeDirectionErr = DetectionsRelativeDirectionErr(1:numel(Dist2DetectedPrey));
        end % if numel(Dist2DetectedPrey) ~= numel(DetectionsRangeErr);

        Dist2DetectedPrey = Dist2DetectedPrey + ...
            errFlag*DetectionsRangeErr;
        Angle2DetectedPrey = Angle2DetectedPrey + ...
            errFlag*DetectionsDFerror;
        PreyRelativeDirection = PreyRelativeDirection + ...
            errFlag*DetectionsRelativeDirectionErr;
        % % Dist2DetectedPrey = PreyFindsStruct.Dist2DetectedPrey + ...
        % %     errFlag*PreyFindsStruct.DetectionsRangeErr;
        % % Angle2DetectedPrey = PreyFindsStruct.Angle2DetectedPrey + ...
        % %     errFlag*PreyFindsStruct.DetectionsDFerror;
        % % PreyRelativeDirection = PreyFindsStruct.PreyRelativeDirection + ...
        % %     errFlag*PreyFindsStruct.DetectionsRelativeDirectionErr;
        %%%
        %%
        %%% Start

        PreyToHunt = 0;
        FilterBangFlag = strcmp(AllParams.BatSonarParams.ReceiverType, 'FilterBank');

        %% If Previous stage was approach or buzz try to keep on same prey
        switch BatPrevManStage
            case {'Approach' , 'Buzz' }% switch BatPrevManStage
                % ManueverPower to be changed later
                if strcmp(BatPrevManStage, 'Buzz')
                    tempManPower = 'Buzz';
                else % if strcmp(BatPrevManStage, 'Buzz')
                    tempManPower = 'RegularHunt';
                end % if strcmp(BatPrevManStage, 'Buzz')

                % if the hunted prey is detected again- continue with the manuver

                if ismember(PrevManCmdSrtruct.PreyNumToHunt, UmMaskedDetectedPreys)

                    KeepHuntWithoutDetection = 0; %flag
                    tempPreyNumToHunt = PrevManCmdSrtruct.PreyNumToHunt;
                    tempIndex = (UmMaskedDetectedPreys == tempPreyNumToHunt);
                    AngleTotempHunted = Angle2DetectedPrey(tempIndex);
                    if abs(AngleTotempHunted) <= MaxAngleToManuever
                        PreyToHunt = tempPreyNumToHunt;
                        KeepHuntingAfterPrevFlag = 1; %flag
                        ManueverByPrevStageFlag = 1;

                        %%% Build the Output Struct
                        ManueverCmdStruct.ManueverStage = BatPrevManStage;
                        ManueverCmdStruct.ManueverType = 'Hunting';
                        ManueverCmdStruct.ManueverPower = tempManPower;
                        ManueverCmdStruct.PreyNumToHunt = tempPreyNumToHunt;
                        %%% XXXXXXX
                        [ManueverCmdStruct.Dist2HuntedPrey, Ind_min] = min(Dist2DetectedPrey(tempIndex));
                        ManueverCmdStruct.Angle2HuntedPrey = AngleTotempHunted(Ind_min);
                        ManueverCmdStruct.PreyRelativeDirection = PreyRelativeDirection(tempIndex(Ind_min));
                        ManueverCmdStruct.LastNDetections = ...
                            [ PrevManCmdSrtruct.LastNDetections(min(2,end):end), ManueverCmdStruct.PreyNumToHunt];
                        ManueverCmdStruct.HuntedPreyMaskedFlag = 0;
                        ManueverCmdStruct.ManueverByPrevStageFlag = ManueverByPrevStageFlag;
                        ManueverCmdStruct.JamFalseAlarmFlag = JamFalseAlarmFlag;
                        % if the prev is not in the right angle - keep searchin
                    else  % if abs(AngleTotempHunted) <= MaxAngleToManuever
                        KeepHuntingAfterPrevFlag = 0;

                    end % if abs(AngleTotempHunted) <= MaxAngleToManuever

                    % if prey isnt detected this pulse check prev_K_Of_N
                else % if ismember(PrevManCmdSrtruct.PreyNumToHunt, UmMaskedDetectedPreys)

                    KeepHuntingAfterPrevFlag = 0; %flag
                    tempLastNDetections = ...
                        [ PrevManCmdSrtruct.LastNDetections(min(2,end):end), 0];
                    UniqPrevPreys = nonzeros( unique(tempLastNDetections) )';

                    % Check the K_Of_N rule
                    if (~ManueverCmdStruct.IsHuntedCaughtFlag || ~PrevManCmdSrtruct.IsHuntedCaughtFlag) && ...
                            PrevManCmdSrtruct.PreyNumToHunt > 0

                        for uPrey = UniqPrevPreys
                            count = sum( tempLastNDetections == uPrey);
                            if count >= KPrevNeeded
                                KeepHuntWithoutDetection = 1; %flag
                                break

                            else % count > KPrevNeeded
                                KeepHuntWithoutDetection = 0; %flag
                            end % if count > KPrevNeeded
                        end % for uPrey = UniqPrevPreys

                        if KeepHuntWithoutDetection

                            ManueverByPrevStageFlag = 1;
                            %%% Build the Output Struct
                            ManueverCmdStruct.ManueverStage = BatPrevManStage;
                            ManueverCmdStruct.ManueverType = 'Hunting';
                            ManueverCmdStruct.ManueverPower = tempManPower;
                            ManueverCmdStruct.PreyNumToHunt = PrevManCmdSrtruct.PreyNumToHunt;
                            ManueverCmdStruct.Dist2HuntedPrey = PrevManCmdSrtruct.Dist2HuntedPrey; % LastDistance
                            ManueverCmdStruct.Angle2HuntedPrey = 0; % keep in current direction
                            ManueverCmdStruct.PreyRelativeDirection = PrevManCmdSrtruct.PreyRelativeDirection;
                            ManueverCmdStruct.LastNDetections = tempLastNDetections;
                            ManueverCmdStruct.HuntedPreyMaskedFlag = ...
                                ismember(ManueverCmdStruct.PreyNumToHunt , PreyFindsStruct.MaskedPreys) ;
                            % filling zeros where []
                            if isempty(ManueverCmdStruct.HuntedPreyMaskedFlag)
                                ManueverCmdStruct.HuntedPreyMaskedFlag = 0;
                            end %if isempty
                            ManueverCmdStruct.ManueverByPrevStageFlag = ManueverByPrevStageFlag;
                            ManueverCmdStruct.JamFalseAlarmFlag = JamFalseAlarmFlag;
                        else % if KeepHuntWithoutDetection
                            ManueverByPrevStageFlag = 0;
                        end % if KeepHuntWithoutDetection
                    else % if ~ManueverCmdStruct.IsHuntedCaughtFlag
                        ManueverByPrevStageFlag = 0;
                    end % if ~ManueverCmdStruct.IsHuntedCaughtFlag

                end %if ismember(PrevManCmdSrtruct.PreyNumToHunt, UmMaskedDetectedPreys)
                %        ManueverCmdStruct.PreyNumToHunt = PrevManCmdSrtruct.PreyNumToHunt;


            otherwise   % switch BatPrevManStage

        end % switch BatPrevManStage
        %% End Switch BatPrevManStage

        %% Try to search and hunt for prey items only if not in keeping in prev
        %%% manuever
        if ~ManueverByPrevStageFlag
            NumOfPreyDetected = length(AllDetectedPreys);


            %%% check if 'hunting'
            if NumOfPreyDetected > 0
                % Relative diatnce and angles form prey
                PreyDistances = Dist2DetectedPrey;
                PreyVecAngles = Angle2DetectedPrey;
                PreyRelativeDirection = PreyRelativeDirection;
                %         PreyRelativeDirection = 0; % Consider add to struct an logic later

                % default init: not to hunt, hunted prey not masked
                HuntFlag = 0;
                HuntedPreyMaskedFlag = 0;

                [SortPreyDistances, SortIndex] = sort(PreyDistances);
                [~, idx_unmasked] = setdiff(PreyFindsStruct.DetecectedPreyWithOutInterference, PreyFindsStruct.MaskedPreys);
                det_in_azimuth_flg = any(abs(PreyFindsStruct.Angle2DetectedPrey(idx_unmasked)) <= MaxAngleToManuever);


                for k = 1:NumOfPreyDetected
                    CurrPrey = AllDetectedPreys(SortIndex(k));

                    if abs(PreyVecAngles(SortIndex(k))) <= MaxAngleToManuever
                        IsCurrPreyMaskedFlag = ismember(CurrPrey, PreyFindsStruct.MaskedPreys);

                        % if current Prey is  from Bi-Stat detection than it is not
                        % Masked
                        if AllParams.BatSonarParams.BiStatMode && ~isempty(PreyFindsStruct.BiSonarPreyToHunt)

                            if CurrPrey == PreyFindsStruct.BiSonarPreyToHunt
                                IsCurrPreyMaskedFlag = 0;
                            end % if CurrPrey == PreyFindsStruct.BiSonarPreyToHunt
                        end % if AllParams.BatSonarParams.BiStatMode && ...

                        % if current Prey is a phantom than it is not
                        % Masked
                        if AllParams.BatSonarParams.PhantomEchoesFromConsFlag && ~isempty(PreyFindsStruct.PhantomIsDetected)

                            if CurrPrey == PreyFindsStruct.PhantomPreyNum
                                IsCurrPreyMaskedFlag = 0;
                            end % if CurrPrey == PreyFindsStruct.BiSonarPreyToHunt
                        end % if AllParams.BatSonarParams.BiStatMode && ...


                        if IsCurrPreyMaskedFlag
                            HuntedPreyMaskedFlag = 1;
                        else % if IsPreyMaskedFlag - else: the currrent prey in unmasked and should be hunted
                            HuntFlag = 1;
                            PreyToHunt = CurrPrey;
                            PreyToHuntIndex = SortIndex(k);


                            break  % there is a prey to hunt : exit for k loop
                        end %if IsPreyMaskedFlag

                    else %if PreyVecAngles(SortIndex(k)) <= MaxAngleToManuever

                        % proceed to next prey
                    end %if PreyVecAngles(SortIndex(k)) <= MaxAngleToManuever

                end % for k = 1:NumOfPreyDetected

                %% False allarms from maskers
                if PreyToHunt < 0 && det_in_azimuth_flg
                    JamFalseAlarmFlag = 1;
                end % if CurrPrey < 0

                %%
                %%% Build the Output Struct
                ManueverCmdStruct.HuntedPreyMaskedFlag = HuntedPreyMaskedFlag;
                ManueverCmdStruct.LastNDetections = ...
                    [ PrevManCmdSrtruct.LastNDetections(min(2,end):end), PreyToHunt ];
                if HuntFlag
                    ManueverCmdStruct.ManueverType = 'Hunting';
                    ManueverCmdStruct.PreyNumToHunt = PreyToHunt;
                    %%% XXXXX
                    [ManueverCmdStruct.Dist2HuntedPrey, Ind_min] = min(PreyDistances(PreyToHuntIndex));
                    ManueverCmdStruct.Angle2HuntedPrey = PreyVecAngles(PreyToHuntIndex(Ind_min));
                    ManueverCmdStruct.PreyRelativeDirection = PreyRelativeDirection(PreyToHuntIndex(Ind_min));
                    ManueverCmdStruct.JamFalseAlarmFlag = JamFalseAlarmFlag;
                end % if HuntFlag

            else %if NumOfPreyDetected > 0
                SortPreyDistances = [];
                ManueverCmdStruct.HuntedPreyMaskedFlag = [];
                ManueverCmdStruct.LastNDetections = ...
                    [ PrevManCmdSrtruct.LastNDetections(min(2,end):end), 0 ];
                %         ManueverCmdStruct.ManueverType = [];
                ManueverCmdStruct.PreyNumToHunt = 0;
                ManueverCmdStruct.Dist2HuntedPrey = nan;
                ManueverCmdStruct.Angle2HuntedPrey = nan;
                ManueverCmdStruct.PreyRelativeDirection = nan; %(PreyToHuntIndex);
                ManueverCmdStruct.JamFalseAlarmFlag = JamFalseAlarmFlag;

            end % if NumOfPreyDetected > 0

        end % if ~ManueverByPrevStageFlag

        % %%% Add error estimation to targets' localization %%%
        %
        % errFlag = AllParams.BatSonarParams.LocalizationErrFlag; % '1' if ti is require to add error, '0' otherwise
        %
        % HuntedInd = ( PreyFindsStruct.DetectedPreyNum == ManueverCmdStruct.PreyNumToHunt );
        %
        % ManueverCmdStruct.Dist2HuntedPrey = ManueverCmdStruct.Dist2HuntedPrey + ...
        %     errFlag*PreyFindsStruct.DetectionsRangeErr(HuntedInd);
        %
        % ManueverCmdStruct.Angle2HuntedPrey = ManueverCmdStruct.Angle2HuntedPrey + ...
        %     errFlag*PreyFindsStruct.DetectionsDFerror(HuntedInd);
        %
        % ManueverCmdStruct.PreyRelativeDirection = ManueverCmdStruct.PreyRelativeDirection + ...
        %     errFlag*PreyFindsStruct.DetectionsRelativeDirectionErr(HuntedInd);

        %%% ManueverStage and ManueverPower Decision
        if strcmp(ManueverCmdStruct.ManueverType, 'Hunting')
            if (ManueverCmdStruct.Dist2HuntedPrey <= DistanceToBuzz)...
                    && (abs(ManueverCmdStruct.Angle2HuntedPrey) <= AngleToBuzz)
                ManueverCmdStruct.ManueverStage = 'Buzz';
                ManueverCmdStruct.ManueverPower = 'Buzz';
            elseif (ManueverCmdStruct.Dist2HuntedPrey <= DistanceToApproach)
                ManueverCmdStruct.ManueverStage = 'Approach';
                ManueverCmdStruct.ManueverPower = 'RegularHunt';
            else % if (min(PreyDistances) <= DitanceToBuzz) && (MinPreyAngle <= AngleToBuzz)
                ManueverCmdStruct.ManueverStage = 'Search';
                ManueverCmdStruct.ManueverPower = 'RegularHunt';
            end % if (min(PreyDistances) <= DitanceToBuzz) && (MinPreyAngle <= AngleToBuzz)
        end % if strcmp(ManueverCmdStruct.ManueverType, 'Hunting')
        %%

    %%%%%%%%%% END FORAGING %%%%%%%%
    case 'swarm'
       %% NEW - swarm
        if NumberOfOtherBats > 0
            
            Is_RelevantBat_Masked =  0 ;
            %         MinDist2OtherBat = 0.5/ xyResolution; % reaction distance to avoid collision
            MinDist2OtherBat = DistanceToApproach; % reaction distance to avoid collision %% CHANGED 21 Feb 2021 %%
            ref_distance = MinDist2OtherBat;
            if AllParams.BatFlightParams.ReactToBatsFlag
                ref_distance = DistanceToApproach;
            end % if AllParams.BatFlightParams.ReactToBatsFlag

            if BAT.Consps_FindsStruct(AnalyzedPulseNum).IsAnyPreyDetected
                if ~isempty(BAT.Consps_FindsStruct(AnalyzedPulseNum).MaskedPreys)
                    %%% there is masking
                    % Check if the relevan bat is masked
                    [~, masked_ix] = ismember(BAT.Consps_FindsStruct(AnalyzedPulseNum).MaskedPreys, ...
                        BAT.Consps_FindsStruct(AnalyzedPulseNum).DetecectedPreyWithOutInterference);
                    [MinDist_all, MinIndex] = min(BAT.Consps_FindsStruct(AnalyzedPulseNum).Dist2DetectedPrey);
                    if MinDist_all<=ref_distance && ismember(MinIndex, masked_ix)
                        Is_RelevantBat_Masked = 1; % The Closest conspecific is Masked and not detected by the bat
                        %                     ManueverCmdStruct.ReactTo_Masked_Bat = 1;
                        end %

                        % react only to  un-masked conspecifics
                        [~, un_masked_ix] = ismember(BAT.Consps_FindsStruct(AnalyzedPulseNum).DetectedPreyNum, ...
                            BAT.Consps_FindsStruct(AnalyzedPulseNum).DetecectedPreyWithOutInterference);

                else %if ~isempty(BAT.Consps_FindsStruct(AnalyzedPulseNum).MaskedPreys)
                    %%%% no masking
                    un_masked_ix = 1:numel(BAT.Consps_FindsStruct(AnalyzedPulseNum).DetectedPreyNum);

                end % if ~isempty(BAT.Consps_FindsStruct(AnalyzedPulseNum).MaskedPreys)

                BatsDistances = BAT.Consps_FindsStruct(AnalyzedPulseNum).Dist2DetectedPrey(un_masked_ix) + ...
                    BAT.Consps_FindsStruct(AnalyzedPulseNum).DetectionsRangeErr(un_masked_ix);
                BatsVecAngles = BAT.Consps_FindsStruct(AnalyzedPulseNum).Angle2DetectedPrey(un_masked_ix) + ...
                    BAT.Consps_FindsStruct(AnalyzedPulseNum).DetectionsDFerror(un_masked_ix);
                TargetsID =  BAT.Consps_FindsStruct(AnalyzedPulseNum).DetecectedPreyWithOutInterference(un_masked_ix);
                [~, other_ix] = ismember(TargetsID, Struct2OtherBats.TargetsID);
                BatsRelativeDirection = Struct2OtherBats.Bat2TargetRelativeAngle(other_ix) + ...
                    BAT.Consps_FindsStruct(AnalyzedPulseNum).DetectionsDFerror(un_masked_ix);
                % update output
                ManueverCmdStruct.Relevant_ConspEcho_Masked = Is_RelevantBat_Masked;

            else %if BAT.Consps_FindsStruct(AnalyzedPulseNum).IsAnyPreyDetected
                % No Conspecifics detected
                % no other bats nearby - no change in command
                BatsDistances = inf;
                BatsVecAngles = pi;
            end % if BAT.Consps_FindsStruct(AnalyzedPulseNum).IsAnyPreyDetected
        end % if NumberOfOtherBats > 0
        %%%%%%% END SWARM %%%%%%%%%%%%%%%%
    
    case 'caveExit'          
         %% NEW Jun22- Cave Exit
         %%%%%% General:
         % the Exit is identified by a free echoes zone between two obstacles
         % The Search rules:
         % 0) if an 'exit' is identified, fly toward it, avoid obstacles
         % 1) if no obstacle is detected- continue random flight, Sinar:
         % Serach, Velocity = nominal velocity
         % 2) if an Obstacle is detecetd: Fly towards it, Keep a Distance of 
         % 0.7 meters infront of the obstacle (Dists * sinus(angle) = 0.7),
         % filght veolcity is minimal, Sonar Activity is like Aproach
         % 3) keep following the obstacle util finding an exit or no
         % obstacle is found

         %%% cave Exit Params %%%%
         exitClearAngles    = 15 / 180 *pi; % the 'Finger print of the exit is 15 degress area without obstacles
         diffSortedDistTH   = 0.8 / xyResolution; % the TH sDistance to check for exit if two objects are angularry closed 
         distToKeepFromWall = 0.8 / xyResolution; % keep flying parallel to the obstacle
         minObsPoints       = 2; % min number of ponts to be detected between Gaps 

         % update the threshold for Obstacle Mnuver
         DistToReactObstacle = 1.2/xyResolution; 
            
        % Check if any abostacle founds
         if ~isempty(FoundObstacles.DetectedPreyNum)
                anyObsFound = true;
         else %  if ~isempty(FoundObstacles)
             anyObsFound = false;
         end % if ~isempty(FoundObstacles)
        
         % if no obstacle is found, continue flying in random mode
         if ~anyObsFound
             ManueverCmdStruct.ManueverStage       = 'Search';
             ManueverCmdStruct.ManueverType        = 'Foraging'; % keep old definitions for minimize chnges in pther functions
             ManueverCmdStruct.ManueverPower       = 'RegularForaging';
             ManueverCmdStruct.ManDirectionCommand = 'None';
             ManueverCmdStruct.ManAccelCommand     = 'None';
         
         else % if ~anyObsFound
            

            [sortedAngles, sortIx]  = sort(wrapToPi(FoundObstacles.Angles),'ascend');
            diffAngles              = diff(sortedAngles);
            sortedDistancesByAngles = FoundObstacles.Distances(sortIx);
            
            % Serch the exit - Angles GAP
            exitPotentialsIx = find(abs(diffAngles) >= exitClearAngles);
            exitPotentialsIx = checkMinPoints(exitPotentialsIx, sortedAngles, minObsPoints);

            % exitByDistDff 
            exitByDistDffIx = find(abs(diff(sortedDistancesByAngles))./cos(sortedAngles(1:end-1)) > diffSortedDistTH);
            exitByDistDffIx = checkMinPoints(exitByDistDffIx, sortedDistancesByAngles, minObsPoints);

            if any(exitPotentialsIx)
                %%%% Maybe there is an exit - go to the direction with the maximal open space
                [maxGap, bestIx] = max(diffAngles);
                requiredDirection = sortedAngles(bestIx) + maxGap/2;
                    
                ManueverCmdStruct.ManueverStage    = 'CaveExit'; % NEW
                ManueverCmdStruct.ManueverType     = 'ExitMan'; % keep old definitions for minimize chnges in pther functions
%                 ManueverCmdStruct.ManueverPower    = 'RegularForaging';
                % the estimated direction and distance of the exit
                maxDist = min(FoundObstacles.Distances(sortIx(bestIx:bestIx+1)) );
                
                % check if too close to the clutter, and add safe angle
                checkDistances = [sortedDistancesByAngles(bestIx), sortedDistancesByAngles(bestIx+1)];
                checkAngles    = [sortedAngles(bestIx),            sortedAngles(bestIx+1)];
                requiredDirection = keepGapFromTooCloseWall(requiredDirection, checkAngles, checkDistances, distToKeepFromWall);
                ManueverCmdStruct.Dist2HuntedPrey  = maxDist;
                ManueverCmdStruct.Angle2HuntedPrey = requiredDirection;
                 followObsFlag = true; % Flag of Manuevering insige the cave

                % Check if need to Buzz
                if (ManueverCmdStruct.Dist2HuntedPrey <= DistanceToBuzz)
                    ManueverCmdStruct.ManueverStage = 'Buzz';
                end
                
                % while exit take risks
                MinDistanceAllowed = 0.5*MinDistanceAllowed;

                % Distance Gap
            elseif any(exitByDistDffIx)
                % go to the clsest gap with TH difference
                [~, gapIx] = min(sortedDistancesByAngles(exitByDistDffIx));
                bestIx = exitByDistDffIx(gapIx);
                requiredDist = min(sortedDistancesByAngles(bestIx), sortedDistancesByAngles(bestIx+1)) ; 
                % go to the angle betqeen then
                requiredDirection = (sortedAngles(bestIx) + sortedAngles(bestIx+1)) ./ 2; 
                
                % check if too close to the clutter, and add safe angle
                checkDistances = [sortedDistancesByAngles(bestIx), sortedDistancesByAngles(bestIx+1)];
                checkAngles    = [sortedAngles(bestIx),            sortedAngles(bestIx+1)];
                requiredDirection = keepGapFromTooCloseWall(requiredDirection, checkAngles, checkDistances, distToKeepFromWall);

                ManueverCmdStruct.ManueverStage    = 'CaveExit'; % NEW
                ManueverCmdStruct.ManueverType     = 'ExitMan'; % keep old definitions for minimize chnges in other functions
                followObsFlag = true; % Flag of Manuevering insige the cave

                ManueverCmdStruct.Dist2HuntedPrey  = requiredDist;
                ManueverCmdStruct.Angle2HuntedPrey = requiredDirection;
                % Check if need to Buzz
                if (ManueverCmdStruct.Dist2HuntedPrey <= DistanceToBuzz)
                    ManueverCmdStruct.ManueverStage = 'Buzz';
                end
                maxDist = min(FoundObstacles.Distances);
                
                % while exit take risks
                MinDistanceAllowed = 0.5*MinDistanceAllowed;
            else % if any(exitPotentialsIx)
                %%% React to the obstale - Fly along the obstacle and Searh for exit
                %%%% Turn to the direction with the further direction and keep
                %%%% distance constant from wall
                
%                 [maxDist, maxIx] = max(FoundObstacles.Distances);
%                 maxAngle = FoundObstacles.Angles(maxIx);
                ixToCheck = [1, numel(sortedAngles)]; % the first is the most right angle
                anglesToCheck = sortedAngles(ixToCheck); 
                [~, minIx] = min(abs(anglesToCheck));
               
                maxAngle = anglesToCheck(minIx);
                maxDist = FoundObstacles.Distances(sortIx(ixToCheck(minIx))); % sorry for the indices ... 
                if minIx == 1
                    signDistFromWall = -1;
                elseif minIx == 2 
                    signDistFromWall = +1;
                end % if minIx == 1

                % if you are too close - turn 90 degrees -, else try to
                % stay in constant distance
                if maxDist > distToKeepFromWall
                    requiredDirection = maxAngle + signDistFromWall * asin(distToKeepFromWall ./ maxDist);
                else 
                    requiredDirection = signDistFromWall* pi/2;
% %                 elseif maxAngle > 0 % left
% %                     requiredDirection = +pi/2;
% %                 elseif maxAngle <= 0 % right
% %                      requiredDirection = -pi/2;
                end % if maxDist > distToKeepFromWall
                
                % check for minimal Distance - Crush
                if min(FoundObstacles.Distances) < 3*MinDistanceAllowed    
                    followObsFlag = false;
                else
                    followObsFlag = true;
                end

                % check for minimal Distance - SlowDOwn
                if min(FoundObstacles.Distances) < 2*distToKeepFromWall   
                    ManueverCmdStruct.ManAccelCommand = 'SlowDown';
                end
                %% the output
                if followObsFlag
                    ManueverCmdStruct.ManueverStage   = 'Approach'; % 
                    ManueverCmdStruct.ManueverType    = 'FollowWall'; % NEW
                    ManueverCmdStruct.Dist2HuntedPrey = maxDist;
                    ManueverCmdStruct.Angle2HuntedPrey = requiredDirection;
                    % Check if need to Buzz
                    if (ManueverCmdStruct.Dist2HuntedPrey <= DistanceToBuzz)
                        ManueverCmdStruct.ManueverStage = 'Buzz';
                    end
                end %if followObsFlag

            end % if any(exitPotentialsIx)
         end % if ~anyObsFound
            
end % switch AllParams.SimParams.TestMode


%% React to Other BATS
if NumberOfOtherBats > 0
    %%%% Change 18Aug21- Omer %%%%%
    % Bats react only if the conspeficks is infront of it
    % Old:
    % [MinDist, MinIndex] = min(BatsDistances);
    %     if MinDist <= MinDist2OtherBat
    % New 21Aug21

    ix_dist_react = BatsDistances <= MinDist2OtherBat;
    ix_angle_react = abs(BatsVecAngles) <= pi/2;
    ix_react = find(ix_dist_react & ix_angle_react);

    if any(ix_react)
        ManueverCmdStruct.ReactToBat =1;
        ManueverCmdStruct.ManueverStage = 'AvoidBatMan';
        ManueverCmdStruct.ManueverType = 'AvoidBatMan';
        ManueverCmdStruct.ManueverPower = 'RegularBatAvoid';
        % New- choose the to react to
        [~, MinIndex] = min(abs(BatsDistances(ix_react) .* sin(BatsVecAngles(ix_react)) ) );
        MinIndex = ix_react(MinIndex);
        MinDist = BatsDistances(MinIndex);
        %%%%
        ManueverCmdStruct.BatToAvoid = TargetsID(MinIndex); % Struct2OtherBats.TargetsID(MinIndex); %- Old
        ManueverCmdStruct.Dist2Bat = MinDist;
        ManueverCmdStruct.Angle2Bat = BatsVecAngles(MinIndex); % Struct2OtherBats.TargetAngle(MinIndex);
        ManueverCmdStruct.BatRelativeDirection = BatsRelativeDirection(MinIndex); %  Struct2OtherBats.Bat2TargetRelativeAngle(MinIndex);

    else % if any(ix_dist_react) % if min(BatsDistances) <= MinDist2OtherBat
        %%% check if distance to bat is closer than prey
        [MinDist, MinIndex] = min(BatsDistances); %18Aug21
        if AllParams.BatFlightParams.ReactToBatsFlag
            MinDist2React =  min(BatsDistances(abs(BatsVecAngles) <= AngleFieldWidth));
            %             RefDistance = min([SortPreyDistances(1), DistanceToApproach]);
            if ~isempty(MinDist2React) && MinDist2React < DistanceToApproach
                if ~isempty(Dist2DetectedPrey)
                    if MinDist2React < min(Dist2DetectedPrey)
                        ManueverCmdStruct.ReactToBat = 1;
                    end % if MinDist2React < SortPreyDistances(1)
                else %  if ~isempty(SortPreyDistances)
                    ManueverCmdStruct.ReactToBat = 1;
                end % iif ~isempty(MinDist2React) && MinDist2React < DistanceToApproach
            end % if AllParams.BatSonarParams.ReactToBatsFlag
        end % if any(ix_dist_react) %if min(BatsDistances) <= MinDist2OtherBat

        if ManueverCmdStruct.ReactToBat
            ManueverCmdStruct.Dist2ReactBat = MinDist ; % MinDist2React;
            ManueverCmdStruct.BatToReact = Struct2OtherBats.TargetsID(BatsDistances == MinDist ) ;% MinDist2React);
        end % if ManueverCmdStruct.ReactToBat
    end % if MinDist <= MinDist2OtherBat

    %%% Check if bats crush- mark only new crushes
    if min([MinDist_all, MinDist]) <= BatCrushDist
        if AnalyzedPulseNum == 1
            ManueverCmdStruct.BatCrush = 1;
            % new crush
        elseif BAT.ManueverCmdStruct(AnalyzedPulseNum-1).BatCrush == 0 % if AnalyzedPulseNum = 1
            ManueverCmdStruct.BatCrush = 1;

            % new bat
        elseif (BAT.ManueverCmdStruct(AnalyzedPulseNum-1).BatCrush == 1) && ...
                (BAT.ManueverCmdStruct(AnalyzedPulseNum-1).BatToAvoid ~= ManueverCmdStruct.BatToAvoid)
            ManueverCmdStruct.BatCrush = 1;
        end %if AnalyzedPulseNum = 1
    end  % if min([MinDist_all, MinDist]) <= BatCrushDist
end % if NumberOfOtherBats > 0

%% XXXXXX XXX

%% ObsMan Decision New 13June06%%% 
ObsManSuggestionFlag = 0;
% AVoid the obsacle detected by the bat with the localizion errors allready
% included
FoundObstacles.TargetAngle = FoundObstacles.Angles; 
FoundObstacles.IsObs       = ~isempty(FoundObstacles.DetectedPreyNum);

if AllParams.BatFlightParams.AvoidObsFlag  % && ~followObsFlag % Obs manuever only if flag is TRUE
    if ~isempty(FoundObstacles)
       
        if FoundObstacles.IsObs
            % React only  to obstacles in front and close enought
            % DistToReactObstacle = 200;
            reactToObsIx = FoundObstacles.Distances <= DistToReactObstacle & abs(FoundObstacles.TargetAngle) < pi/3;  
            if any(reactToObsIx)
               
                % Test minium Distance of the obstacles from the current Direction 
                ObsDistanceFromCurrent = abs(FoundObstacles.Distances(reactToObsIx) .* sin(FoundObstacles.TargetAngle(reactToObsIx)) );
                minObsDistance = min(abs(FoundObstacles.Distances)); 
                
                % Test if there is need to change direction
                obsToAvoidIx = ObsDistanceFromCurrent <= 2*MinDistanceAllowed;
                leftObsIx  = FoundObstacles.TargetAngle >= 0 ; % Obstacles from right or left
                leftDist   = FoundObstacles.Distances(leftObsIx);
                rightDist  = FoundObstacles.Distances(~leftObsIx);
                diffLR     = abs(max(leftDist) - max(rightDist));
                
                if any(obsToAvoidIx) || minObsDistance <= 3*MinDistanceAllowed
                    
                    ObsManSuggestionFlag = 1;
                    tempManueverType  = 'ObsMan';
                    tempManueverStage = 'ObstacleManuver';
                    tempManueverPower = 'RegularManuever';
                    sideClearFlag = false;
                
                    %                     ObsDistanceFromBat  = FoundObstacles.Distances(reactToObsIx);
                    ObsAnlgeFromCurrent = FoundObstacles.TargetAngle(reactToObsIx);
                    %%% Test direction of manuever
                    % if ther are no obstacles in the left Side - Turn left
                    if ~any(leftDist)
                        tempManDirectionCommand = 'Left';
                        sideClearFlag = true;
                    elseif ~any(rightDist) % Check Obstacle on right
                        tempManDirectionCommand = 'Right';
                        sideClearFlag = true;
                    else % There are obstacle in both side - turn to the side with furthe obstacles
                        
                        tempManAccelCommand = 'SlowDown';
                        if diffLR < 2*MinDistanceAllowed && strcmp(PrevManCmdSrtruct.ManueverStage, 'ObstacleManuver') && ~strcmp(PrevManCmdSrtruct.ManDirectionCommand,'None')
                                tempManDirectionCommand = PrevManCmdSrtruct.ManDirectionCommand;
                        elseif max(leftDist) >= max(rightDist)
                            tempManDirectionCommand = 'Left';
                        else
                            tempManDirectionCommand = 'Right';
                        end % if min(lefDist) <= min(rightDist)
                    end % if ~any(leftObsIx)
                    
                    %%%% CRUSH AVOIDANCE I - Too Close to Wall
                    if min(FoundObstacles.Distances) <= MinDistanceAllowed * 2.5 * (CurrentVelocity*xyResolution/SampleTime)
                        tempManueverPower = 'CrushAvoidance';
                        tempManAccelCommand = 'SlowDown';
                    end
                    
                    %%%% CRUSH AVOIDANCE II - 'Corner' - the Distance from
                    % both sides are alike, take the previous Turn
                    if ~sideClearFlag
                        if min(FoundObstacles.Distances) <= MinDistanceAllowed*4 && diffLR < 2*MinDistanceAllowed
                            tempManueverPower = 'CrushAvoidance';
                            tempManAccelCommand = 'SlowDown';
                            if  strcmp(PrevManCmdSrtruct.ManueverStage, 'ObstacleManuver') && ~strcmp(PrevManCmdSrtruct.ManDirectionCommand,'None')
                                tempManDirectionCommand = PrevManCmdSrtruct.ManDirectionCommand;
                            else % if  strcmp
%                                 tempManDirectionCommand = 'Left';
                            end % if  strcmp
                        end % if min(FoundObstacles.Distances) <= MinDistanceAllowed * 5 && abs(max(leftDist) - max(rightDist)) < 4*MinDistanceAllowed
                    end % if ~sideClearFlag
                end % if  any(obsToAvoidIx)
            end % if any(reactToObsIx)
        end % if FoundObstacles.IsObs
    end % if ~isempty(FoundObstacles)
end % if AllParams.BatFlightParams.AvoidObsFlag 

%%%% cHeck if crushed into Obstacles
nTime = BAT(1).TransmittedPulsesStruct(AnalyzedPulseNum).StartPulseTime;
[isCrushed, xRecover, yRecover, tetaRecover] = CheckObsCrushes(BAT, Terrain, MinDistanceAllowed, AnalyzedPulseNum, nTime);
if isCrushed 

    %%% update the Command
    tempManueverPower       = 'CrushAvoidance';
    tempManueverType        = 'ObsMan';
    tempManueverStage       = 'ObstacleManuver';
    
    if ~isempty(xRecover)
        tempManDirectionCommand = 'None';
        tempManAccelCommand     = 'SlowDown';

        ManueverCmdStruct.ObsCrush    = 1;
        ManueverCmdStruct.xRecover    = xRecover;
        ManueverCmdStruct.yRecover    = yRecover;
        ManueverCmdStruct.tetaRecover = tetaRecover;
    end
end



%%%%% Apply the obstacle suggetion only if it is urgent or not in Hunting
%%%%% mode (to keep suucces rate high)

%% XXXXXXX XXXXX 

switch ManueverCmdStruct.ManueverStage
    
    case {'Approach' 'Buzz' 'AvoidBatMan'}
        if ObsManSuggestionFlag && strcmp(tempManueverPower,'CrushAvoidance')
            ManueverCmdStruct.ManueverStage       = tempManueverStage;
            ManueverCmdStruct.ManueverType        = tempManueverType;
            ManueverCmdStruct.ManueverPower       = tempManueverPower;
            ManueverCmdStruct.ManDirectionCommand = tempManDirectionCommand;
            ManueverCmdStruct.ManAccelCommand     = tempManAccelCommand;
        end %  if ObsManSuggestionFlag && strcmp(tempManueverPower,'CrushAvoidance')
    case 'CaveExit'
        if ObsManSuggestionFlag && strcmp(tempManueverPower,'CrushAvoidance')
            ManueverCmdStruct.ManueverStage       = tempManueverStage;
            ManueverCmdStruct.ManueverType        = tempManueverType;
            ManueverCmdStruct.ManueverPower       = tempManueverPower;
            ManueverCmdStruct.ManDirectionCommand = tempManDirectionCommand;
            ManueverCmdStruct.ManAccelCommand     = tempManAccelCommand;
        
        elseif followObsFlag % if during mnuvering just follow acceleration suggestion
            ManueverCmdStruct.ManAccelCommand     = tempManAccelCommand;
        
        else 
            ManueverCmdStruct.ManueverStage       = tempManueverStage;
            ManueverCmdStruct.ManueverType        = tempManueverType;
            ManueverCmdStruct.ManueverPower       = tempManueverPower;
            ManueverCmdStruct.ManDirectionCommand = tempManDirectionCommand;
            ManueverCmdStruct.ManAccelCommand     = tempManAccelCommand;

        end %  if ObsManSuggestionFlag && strcmp(tempManueverPower,'CrushAvoidance') 
    otherwise
        if ObsManSuggestionFlag
            ManueverCmdStruct.ManueverStage       = tempManueverStage;
            ManueverCmdStruct.ManueverType        = tempManueverType;
            ManueverCmdStruct.ManueverPower       = tempManueverPower;
            ManueverCmdStruct.ManDirectionCommand = tempManDirectionCommand;
            ManueverCmdStruct.ManAccelCommand     = tempManAccelCommand;
        end % if ObsManSuggestionFlag
end % switch ManueverCmdStruct.ManueverStage


%%% CHECK Velocity, keep within 0 and Nominal Velocity
% In Hunting manuever- no need to accelrated the ' hunting manuever' decides the
% velocity
MinVelocity  = 0.05; % 0.01
if ( CurrentVelocity < MinVelocity ) && ...
        ( strcmp(ManueverCmdStruct.ManAccelCommand, 'SlowDown') )
    ManueverCmdStruct.ManAccelCommand = 'None';
end % if ( CurrentVelocity < NominalVelocity )

switch ManueverCmdStruct.ManueverType
    case   'Hunting' % switch ManueverCmdStruct.ManueverType
        est= ' do nothing';

    otherwise % not 'Hunting'
        if ( CurrentVelocity < NominalVelocity ) && ( ~strcmp(ManueverCmdStruct.ManAccelCommand, 'SlowDown') )
            ManueverCmdStruct.ManAccelCommand = 'Accelerate';

        elseif ( CurrentVelocity > NominalVelocity )
            ManueverCmdStruct.ManAccelCommand = 'SlowDown';

        else
            est= ' do nothing';

        end % if ( CurrentVelocity < NominalVelocity )

end % switch ManueverCmdStruct.ManueverType

%%%%% DEBUG
if FoundObstacles.IsObs  % && ~strcmp(ManueverCmdStruct.ManueverStage, 'Buzz')
%     debugObsFlag = 0;
    if debugObsFlag
        fig = figure; ax = gca; hold on
%         if strcmp(AllParams.SimParams.TestMode, 'caveExit')
            fig = myObsacleManuverOnLineTest(BAT(1).TransmittedPulsesStruct(AnalyzedPulseNum).StartPulseTime, ...
                BAT, 1, AnalyzedPulseNum, FoundObstacles, Terrain, ax, requiredDirection, maxDist, prev_xFinds, prev_yFinds);
%         else
%             fig = myObsacleManuverOnLineTest(BAT(1).TransmittedPulsesStruct(AnalyzedPulseNum).StartPulseTime, ...
%                 BAT, 1, AnalyzedPulseNum, FoundObstacles, Terrain, fig );
%         end
        switch ManueverCmdStruct.ManueverStage
            case 'CaveExit'
                dirCmd = num2str(rad2deg(ManueverCmdStruct.Angle2HuntedPrey),3);
            case 'Approach'
                 dirCmd = num2str(rad2deg(ManueverCmdStruct.Angle2HuntedPrey),3);
            case 'ObstacleManuver'
                dirCmd = ManueverCmdStruct.ManDirectionCommand;
        end % switch
        title([ManueverCmdStruct.ManueverStage, ' ', ManueverCmdStruct.ManueverType, ' ', ...
            ManueverCmdStruct.ManueverPower, ', Direction:' ,dirCmd])
    end % debugObsFlag
end % FoundObstacles.IsObs

end % Function
%%

%%% CheckDirectionManuver FUNCTION %%% 
%% CheckDirectionManuver
function [IsDirectionPossibleFlag, Distances] = CheckDirectionManuver(Direction, FoundDistances, FoundAngles, CurrentVelocity, SimParameters)
    xyResolution = SimParameters.SimParams.xyResolution;
    SampleTime = SimParameters.SimParams.SampleTime;
    MaxAccel = SimParameters.BatFlightParams.MaxAccelaration * SampleTime^2/xyResolution;
    MinManueverRadius = CurrentVelocity.^2/MaxAccel;
    % Find if there are obsitcles at the side that cannot be
    % passed
    switch Direction
        case 'Right'
            Index = find(FoundAngles >= 0);
        case 'Left'
            Index = find(FoundAngles < 0);
    end % switch Direction
    
    RelevantAngles = FoundAngles(Index);
    Distances = FoundDistances(Index);
    MinDistancesNeededForTurn = 2*abs(MinManueverRadius*sin(RelevantAngles));
    IsDirectionPossibleFlag = isempty( find(Distances <= MinDistancesNeededForTurn, 1) );
end % fuction
%% checkMinPoints(exitPotentialsIx, minObsPoints)

function [ix] = checkMinPoints(preIx, vecIn, th)

    nIx = [0, preIx, numel(vecIn)];
    dIx = diff(nIx) >= th ;
    goodGap = dIx(1:end-1) & ~diff(dIx); % Between two 'good obstacles
    ix = preIx(goodGap);

end

