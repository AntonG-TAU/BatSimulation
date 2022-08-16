function[xBNext, yBNext, TetaBNext, BVelocityNext, DtetaNext] = ...
        BatMovemet( ManCommandStrct, ...
        xB,yB, TetaB, CurrentVelocity, CurrentDteta,...
        TimeToManuever, RemainTimeToNextMan, AllParams, RoomLimits)

        
% %     (ManueverType, ManueverPower, ManDirectionCommand, ManAccelCommand, SpecialManCommandStrct, ...
%         xB,yB, TetaB, CurrentVelocity, CurrentDteta,...
%         TimeToManuever, SimParameters, RoomLimits)

% [xBNext,yBNext,TetaBNext,ObsAvoidManFlag,PreyManFlag] = ...
%         BatMovemet(xB,yB, TetaB, CurrentVelocity,...
%         Obsticle, Prey, SimParameters)

% This funtion will calculate tne new position(x,y,teta) of the  bat
% output arguments: 
    % xBNext -the x coordinate ,  yBNext -the y coordinate , 
    % TetaBNext- the angle of the bat
    % ObsAvoidManFlag - wether The bat is manuvering to avoid Obs
    % PreyManFlag - wether The bat is manuvering to hunt prey
    % nTimeToMan - the period time needed to this manuver to 
    % MovementCommand = 'Right' or 'Left' or "SlowDown'
% Inptus: 
    % ManueverType = 'Hunting' or 'ObsMan' or 'Foraging'
    % ManueverPower = 
    %       {if Hunting}: 'RegularHunt' or 'Buzz'
    %       {if ObsdMan}: 'RegularObs' or 'CrushAvoidance'
    %       {if Foraging}: 'RegularForaging'
    % xB,yB, TetaB- current position
    % CurrentVelocity = the velocity of the bat
    % DTetaBat =- the differntial angle of the bat ' from its accelartion
    % Obsticle - a Sturct with the vectors of the detected obsticles (which were founded by the bat):
    %       Obsticle.Distance, Obsticle.Alpha - are the distance and angle  vectors between the
    %       bat and the obsicles
    %       Obsticle.IsObs - wether there is an Obsticle;         
    % Prey - a Sturct with te vectors of the detected preys:
    %       Prey.Range, Prey.Angle - are the distance and angle  vectors between the
    %       bat and the obsicles
    %       Prey.IsPrey - wether a prey found
    %       Prey.Direction - the direcion of the prey flight
    % TimeToMakeDecisionFlag - is it Time to make the next manuver decision ...
    %       -if nTimeToNextDec == 1 than make decision
    % nTimeLeftTOMaunver - Time Left for the manuver from the Previous decision 
    % AccelFlag - '1' if the bat shouls accelerate to spped up, '0' if none
    % SimParameters - a Struct with the following tstrcut:
    %       SimParameters.SimParams - xyResolution and SampleTime
    %       SimParameters.BatFlightParameters - MaxAccel, FlightType
    % modified by omer 9/10/17
    
    %%% Set Paramters for movement from Input
    
    FlightType = AllParams.BatFlightParams.FlightTypeFlag;
    xyResolution = AllParams.SimParams.xyResolution;
    SampleTime = AllParams.SimParams.SampleTime;
    MaxAccel = AllParams.BatFlightParams.MaxAccelaration * SampleTime^2/xyResolution;
    MaxVelocity = AllParams.BatFlightParams.MaxVelocity * SampleTime/xyResolution;
    NominalAccel = AllParams.BatFlightParams.NominalAccel * SampleTime^2/xyResolution;
%     BuzzVelocity = SimParameters.BatFlightParams.BuzzVelocity * SampleTime/xyResolution; %%%% Move to All Params
    BuzzVelocity = MaxVelocity;
    NominalVelocity = AllParams.BatFlightParams.NominalVelocity * SampleTime/xyResolution;
    MinVelocity = AllParams.BatFlightParams.MinVelocity * SampleTime/xyResolution;
    StdRand = AllParams.BatFlightParams.StdRandom ; % the STD of the random Flight 
    KdTeta = 1;  % Parameter for circleflight
    
    
    %%% Derived Parmaeters
    MaxDTetaBat = MaxAccel/CurrentVelocity; % the maximum change in time-frame
    NominalDTetaBat = NominalAccel/CurrentVelocity;
       
    %%% ACTION %%%
    %INIT
    AccelCommand = 0;
    DtetaNext = 0;
    xBNext = xB;
    yBNext = yB;
    TetaBNext = TetaB;
    BVelocityNext = CurrentVelocity;
    
    switch ManCommandStrct.ManAccelCommand
        case 'Accelerate'
            AccelFlag = 1;
            AccelCommand = MaxAccel;
        case 'SlowDown'
            AccelFlag = 1;
            AccelCommand = -MaxAccel;
        case 'None'
            AccelFlag = 0;
            AccelCommand = 0;
    end % switch ManCommandStrct.ManAccelCommand
    
    switch ManCommandStrct.ManueverType
        %%% Hunting Manuever %%%
        case {'Hunting', 'ExitMan' , 'FollowWall'}  % execute direction and velocity chane according to prey
            Angle2HuntedPrey      = ManCommandStrct.Angle2HuntedPrey ;
            Dist2HuntedPrey       = ManCommandStrct.Dist2HuntedPrey;
            PreyRelativeDirection = ManCommandStrct.PreyRelativeDirection; 
            
            % anuglar change
%             dTetaChase =  sin(PreyRelativeDirection)/Dist2HuntedPrey; % Pure Chase - need to know the prey angle
            dTetaChase = 0;
            dTetaNeeded =  (Angle2HuntedPrey + dTetaChase) /TimeToManuever ;% Static error+ prey velocity error
            DtetaNext = sign(dTetaNeeded)*min(abs(dTetaNeeded), MaxDTetaBat); % Final Acceleartion cannot be above bat's limit
            
            %Velocity change
%             MinVelocity = 0.12; % move to AllParams

%             ReqVelocity = max( MaxVelocity * cos(Angle2HuntedPrey + dTetaChase), MinVelocity);
            if strcmp( ManCommandStrct.ManueverStage, 'Buzz')
                ReqVelocity = max( BuzzVelocity * cos(Angle2HuntedPrey + dTetaChase), 0.25*MinVelocity);
            else % if strcmp( ManCommandStrct.ManueverStage, 'Buzz')
                ReqVelocity = max( MaxVelocity * cos(Angle2HuntedPrey + dTetaChase), MinVelocity);
            end % if strcmp( ManCommandStrct.ManueverStage, 'Buzz')

            ReqAccelaration = (ReqVelocity- CurrentVelocity)/TimeToManuever;
            if ReqAccelaration > 0 
                AccelCommand = sign(ReqAccelaration)*min(abs(ReqAccelaration), MaxAccel); 
            else % if ReqAccelaration > 0 
                 AccelCommand = sign(ReqAccelaration)*min(abs(ReqAccelaration), 2*MaxAccel);
            end %  if ReqAccelaration > 0 
            
        %%% Avoid Obsticle Manuever %%%
        case {'ObsMan','FollowWallCarefully'}
            switch ManCommandStrct.ManueverPower
                case 'RegularManuever'
                    % DTetaObs = NominalDTetaBat;
                    DTetaObs = MaxDTetaBat;
                case 'CrushAvoidance'
                    DTetaObs = MaxDTetaBat;
            end % switch ManueverPower
            
            switch ManCommandStrct.ManDirectionCommand
                case 'Right'
                    DtetaNext = -DTetaObs;
                case 'Left'
                    DtetaNext = +DTetaObs;
            end %switch ManDirectionCommand
        
        %%% Avoid Other Bat Manuever %%%
        case 'AvoidBatMan'
            Angle2Bat = ManCommandStrct.Angle2Bat ;
            Dist2Bat = ManCommandStrct.Dist2Bat;
            RelativeDirection = ManCommandStrct.BatRelativeDirection; 
            dTetaToCtrush =  sin(RelativeDirection)/Dist2Bat; % choose the opposite angle of the chase
            dTetaNeeded =  -(Angle2Bat + dTetaToCtrush) /TimeToManuever ;% choose the opposite angle of the chase
            DtetaNext = sign(dTetaNeeded)*min(abs(dTetaNeeded), MaxDTetaBat); % Final Acceleartion cannot be above bat's limit
         
        %%% Foraging %%%
        %case 'Foraging'
        %    randFactor = 5;
        %    if strcmp(AllParams.SimParams.TestMode, 'caveExit')
        %         randFactor = 2.5;    
        
        %%% Foraging %%%
        case 'Foraging'
            randFactor = 5;
            if strcmp(AllParams.SimParams.TestMode, 'caveExit')
                 randFactor = 2.5;
            end
            switch FlightType
                case 'linear'
                    DtetaNext = 0;
                case 'circle'
                    DtetaNext =  MaxDTetaBat*KdTeta;
                case 'random'
                    if RemainTimeToNextMan == TimeToManuever
                        DtetaNext = randFactor * sqrt(2)*MaxDTetaBat*StdRand*randn; %%% add 3* 28/8/18
                    else % if RemainTimeToNextMa
                        DtetaNext = CurrentDteta;
                    end % if RemainTimeToNextMan
                otherwise
                    disp('wrong Flight Type Input')
            end % switch FlightType
    end %switch ManCommandStrct.ManueverType
    
% % %     %%%% Check the Room Limits for a Crush %%%% 
             % Deleted Jun 2022: Removed to BatManuverDecision
% % %     if SimParameters.BatFlightParams.AvoidObsFlag  % to manuver away from absticles
% % %         if xB <=  RoomLimits(1)
% % %             IsObs= 1;
% % %             DtetaNext = 0-TetaB;
% % %         end % xP
% % %         if xB >=   RoomLimits(3)
% % %             IsObs= 1;
% % %             DtetaNext = pi-TetaB;
% % %         end % xP
% % %         if yB <=  RoomLimits(2)
% % %             IsObs= 1;
% % %             DtetaNext = pi/2-TetaB;
% % %         end % xP
% % %         if yB >=   RoomLimits(4)
% % %             IsObs= 1;
% % %             DtetaNext = -pi/2-TetaB;
% % %         end % xP
% % %     end % if AllParams.SimParams.AvoidObsticleFlag
% % %     
            %%% Final DATA %%%
    TetaBNext = TetaB + DtetaNext;
    % TetaB should be in range [-pi,pi]
%     TetaBNext = pi*sawtooth(TetaBNext-pi);
    TetaBNext = TetaBNext -(2*pi)*floor((TetaBNext+pi)/(2*pi));
    
    
    BVelocityNext = CurrentVelocity + AccelCommand;
    
   if strcmp(ManCommandStrct.ManAccelCommand, 'Accelerate')
    switch ManCommandStrct.ManueverType
        %%% Hunting Manuever %%%
        case 'Hunting' % execute direction and velocity chane according to prey
%             BVelocityNext = min(BVelocityNext, MaxVelocity);
              BVelocityNext = BVelocityNext;
        otherwise
%             if strcmp(ManCommandStrct.ManAccelCommand, 'Accelerate')
                BVelocityNext = min(BVelocityNext, NominalVelocity);
%             end % if strcmp
    end %switch ManCommandStrct.ManueverType
    end % if strcmp
%     BVelocityNext = min(BVelocityNext, NominalVelocity);
    BVelocityNext = max(BVelocityNext,0.01);
        
    xBNext = xB + BVelocityNext.*cos(TetaBNext) ;
    yBNext = yB + BVelocityNext.*sin(TetaBNext) ;
    
% % %     % DEBUGGING
% % %     if max(size(xBNext), size(yBNext), size(BVelocityNext), size(TetaBNext), size(DtetaNext)) >1
% % %         xBNext= 1;
% % %     end
end% BatMovement Function



