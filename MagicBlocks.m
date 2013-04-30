classdef MagicBlocks < handle
    properties (Constant)
        PROP_YELLOW1 = 3;
        PROP_YELLOW2 = 4;
        PROP_BLUE = 5;
        PROP_PINK = 1;
        PROP_GREEN = 2;
        
        STATE_START = 0;
        STATE_1_YELLOW = 1;
        STATE_2_YELLOW = 2;
        STATE_GATE = 3;
        STATE_COOL_GATE = 4;
        
        ALERT_NOT_GOING_TO_WORK = 1;
        ALERT_NICE = 2;
        ALERT_TRY_AGAIN = 3;
        ALERT_WELCOME = 4;
        ALERT_CRASH = 5;
        ALERT_FINISH_TRIANGLE = 6;
        ALERT_TADA = 7;
    end

    properties
        iCurState = 0;  %the system's current state
        i = 0;          %current frame
        
        iOutInd = -1;
        mStateOut = -ones(5,1);
        mAlertOut = -ones(5,1);
        
        mNewlyGrabbed;  %logical vector of newly grabbed props
        props;          %props stuct array
        
        %the current depth image and metadata
        imDepth;
        metaData;
        
        %sound players
        hSnd;
    end
    
    methods
         
        %constructor - initialize sounds
        function obj = MagicBlocks
            
            [y, Fs]  = audioread('Wonderoom_loop.wav');
            obj.hSnd{1} = audioplayer(y,Fs);

            [y, Fs]  = audioread('NotGoingToWork.wav');
            obj.hSnd{2} = audioplayer(y,Fs);
            [y, Fs]  = audioread('Nice.wav');
            obj.hSnd{3} = audioplayer(y,Fs);
            [y, Fs]  = audioread('LetsTryAgain.wav');
            obj.hSnd{4} = audioplayer(y,Fs);    
            [y, Fs]  = audioread('Welcome.wav');
            obj.hSnd{5} = audioplayer(y,Fs);   
            [y, Fs]  = audioread('Crash.wav');
            obj.hSnd{6} = audioplayer(y,Fs);   
            [y, Fs]  = audioread('FinishTriangle.wav');
            obj.hSnd{7} = audioplayer(y,Fs);
            [y, Fs]  = audioread('TaDa.wav');
            obj.hSnd{8} = audioplayer(y,Fs);
            [y, Fs]  = audioread('Nice3.wav');
            obj.hSnd{9} = audioplayer(y,Fs);
            [y, Fs]  = audioread('LetsTryAgain2.wav');
            obj.hSnd{10} = audioplayer(y,Fs);
            [y, Fs]  = audioread('Nice3.wav');
            obj.hSnd{11} = audioplayer(y,Fs);
        end
        
        %start playing
        function Start(obj)
            set(obj.hSnd{1}, 'StopFcn', {@loopSnd, obj.hSnd{1}});
            play(obj.hSnd{1});
        end
        
        %stop playing
        function Stop(obj)
            set(obj.hSnd{1}, 'StopFcn', []);
            stop(obj.hSnd{1});
        end
        
        %this handles sound alerts
        function Alert(obj, iSnd)
            switch iSnd
                case obj.ALERT_WELCOME
                    play(obj.hSnd{5});
                    
                case obj.ALERT_NOT_GOING_TO_WORK
                    play(obj.hSnd{2});
                    
                case obj.ALERT_NICE
                    if (randi(2) == 1)
                        play(obj.hSnd{3});
                    else
                        play(obj.hSnd{9});
                    end
                    
                case obj.ALERT_TRY_AGAIN
                    if (randi(2) == 1)
                        play(obj.hSnd{4});
                    else
                        play(obj.hSnd{10});
                    end
                    
                case obj.ALERT_CRASH
                    play(obj.hSnd{6});
                    
                case obj.ALERT_FINISH_TRIANGLE
                    play(obj.hSnd{7});
                    
                case obj.ALERT_TADA
                    play(obj.hSnd{8});
            end
        end
        
        
         %% Transition Tests 
    
        %check whether 1 or 2 yellows are upright
        function nUpRightYellows = TestYellowUpRight(obj, nYellows)
            nUpRightYellows = 0;
            
            %a test of width to height
            
            %the test of the extreme blob points (DOESNT WORK)
            mNNZRows = any(obj.props(obj.PROP_YELLOW1).mBlob,2);
            iTopRow = find(mNNZRows, 1, 'first') + 10;
                          
%             iBottomRow = find(mNNZRows, 1, 'last') - 10;
%               abs(obj.imDepth(iTopRow, int32(mean(find(obj.props( ...
%                     obj.PROP_YELLOW1).mBlob(iTopRow,:))))) - ...
%                 obj.imDepth(iBottomRow, int32(mean(find(obj.props( ...
%                     obj.PROP_YELLOW1).mBlob(iBottomRow,:)))))) < 30
            
%             mBlobDep = obj.imDepth(obj.props(obj.PROP_YELLOW1).mBlob);
%             iVarDep = var(double(mBlobDep(:)));
            if (obj.props(obj.PROP_YELLOW1).mPos(1) > 0)
                iTopRow = obj.imDepth(iTopRow,(obj.props(obj.PROP_YELLOW1).mPos(1) - 30): ...
                        (obj.props(obj.PROP_YELLOW1).mPos(1) + 30));
                iTopRow(iTopRow < 200) = [];
            end

            if (obj.props(obj.PROP_YELLOW1).mPos(1) > 0 && ...
                (1.0 * obj.props(obj.PROP_YELLOW1).mBB(3)) < ...
                    obj.props(obj.PROP_YELLOW1).mBB(4) && ... (iVarDep > 200 || iVarDep < 80) && ...
                ~isempty(iTopRow) && max(abs(diff(double(iTopRow)))) > 30)
                
%                 abs(max(diff(double(obj.imDepth(iTopRow, ...
%                     (obj.props(obj.PROP_YELLOW1).mPos(1) - 30): ...
%                     obj.props(obj.PROP_YELLOW1).mPos(1)))))) > 90 && ...
%                 abs(max(diff(double(obj.imDepth(iTopRow, ...
%                     (obj.props(obj.PROP_YELLOW1).mPos(1)): ...
%                     obj.props(obj.PROP_YELLOW1).mPos(1) + 30))))) > 90)

%                 abs(max(diff(double(obj.imDepth(iTopRow, ...
%                     (obj.props(obj.PROP_YELLOW1).mPos(1) - 30): ...
%                     (obj.props(obj.PROP_YELLOW1).mPos(1) + 30)))))) > 70)
                
                nUpRightYellows = 1;
            end
            if (nYellows == nUpRightYellows)
                return;
            elseif (obj.props(obj.PROP_YELLOW2).mPos(1) > 0)
                mNNZRows = any(obj.props(obj.PROP_YELLOW2).mBlob,2);
                iTopRow = find(mNNZRows, 1, 'first') + 10;

                iTopRow = obj.imDepth(iTopRow,(obj.props(obj.PROP_YELLOW2).mPos(1) - 30): ...
                    (obj.props(obj.PROP_YELLOW2).mPos(1) + 30));
                iTopRow(iTopRow < 200) = [];

                %test for the other yellow also
%                 mBlobDep = obj.imDepth(obj.props(obj.PROP_YELLOW2).mBlob);
%                 iVarDep = var(double(mBlobDep(:)));
                
                if (obj.props(obj.PROP_YELLOW2).mPos(1) > 0 && ...
                    (1.0 * obj.props(obj.PROP_YELLOW2).mBB(3)) < ...
                    obj.props(obj.PROP_YELLOW2).mBB(4) && ... (iVarDep > 200 || iVarDep < 80) && ...
                    ~isempty(iTopRow) && max(abs(diff(double(iTopRow)))) > 30)
                
%                     abs(max(diff(double(obj.imDepth(iTopRow, ...
%                         (obj.props(obj.PROP_YELLOW2).mPos(1) - 30): ...
%                         obj.props(obj.PROP_YELLOW2).mPos(1)))))) > 90 && ...
%                     abs(max(diff(double(obj.imDepth(iTopRow, ...
%                         (obj.props(obj.PROP_YELLOW2).mPos(1)): ...
%                         obj.props(obj.PROP_YELLOW2).mPos(1) + 30))))) > 90)

%                     abs(max(diff(double(obj.imDepth(iTopRow, ...
%                         (obj.props(obj.PROP_YELLOW2).mPos(1) - 30): ...
%                         (obj.props(obj.PROP_YELLOW2).mPos(1) + 30)))))) > 70)

                    nUpRightYellows = nUpRightYellows + 1;
                end
            end
        end
               
        %check whether green on top of yellows
        function b = TestGreen(obj)
            %test closeness of Z values
            if (abs(obj.props(obj.PROP_GREEN).mPos(3) - ...
                    (obj.props(obj.PROP_YELLOW1).mPos(3) + ...
                    obj.props(obj.PROP_YELLOW2).mPos(3)) / 2) < 25)
                
                %figure out which is left
%                 if (obj.props(obj.PROP_YELLOW1).mPos(1) > ...
%                     obj.props(obj.PROP_YELLOW2).mPos(1))
% 
%                     iLeftYellowX = obj.props(obj.PROP_YELLOW1).mPos(1);
%                     iRightYellowX = obj.props(obj.PROP_YELLOW2).mPos(1);
%                 else
%                     iLeftYellowX = obj.props(obj.PROP_YELLOW1).mPos(1);
%                     iRightYellowX = obj.props(obj.PROP_YELLOW2).mPos(1);
%                 end
                
                
%                 b = (abs(iLeftYellowX - obj.props(obj.PROP_GREEN).mBB(1)) < 50 && ...
%                     abs(iRightYellowX - obj.props(obj.PROP_GREEN).mBB(1) - ...
%                         obj.props(obj.PROP_GREEN).mBB(3)) < 50 && ...
%                     abs(obj.props(obj.PROP_GREEN).mPos(2) - ...
%                         (obj.props(obj.PROP_YELLOW1).mBB(2) + ...
%                         obj.props(obj.PROP_YELLOW2).mBB(2)) / 2) < 50);

                b = (abs((obj.props(obj.PROP_YELLOW1).mPos(1) + ...
                        obj.props(obj.PROP_YELLOW2).mPos(1)) / 2 - ...
                        obj.props(obj.PROP_GREEN).mPos(1)) < 30 && ...
                    abs(obj.props(obj.PROP_GREEN).mPos(2) - ...
                        (obj.props(obj.PROP_YELLOW1).mBB(2) + ...
                        obj.props(obj.PROP_YELLOW2).mBB(2)) / 2) < 80);
            else
                b = false;
            end
        end
        
        %check whether trinagle on top
        function b = TestTriangle(obj)
            b = abs(obj.props(obj.PROP_GREEN).mPos(1) - ...
                        obj.props(obj.PROP_BLUE).mPos(1)) < 15 && ...
                    obj.props(obj.PROP_BLUE).mPos(2) < ...
                        obj.props(obj.PROP_GREEN).mPos(2) && ...
                    abs(obj.props(obj.PROP_GREEN).mPos(2) - ...
                        obj.props(obj.PROP_BLUE).mPos(2) - 30) < 15;
        end
        
        
%% Flow Engine 
        
        %main entry point, called every frame after setting properties
        function iGrabbedProp = StoryFlow(obj)
            obj.mAlertOut(2:end) = obj.mAlertOut(1:end-1);
            obj.mStateOut(2:end) = obj.mStateOut(1:end-1);
            obj.mStateOut(1) = -1;
            obj.mAlertOut(1) = -1;
            iGrabbedProp = [];
                        
            switch (obj.iCurState)
           
            %starting state - need to grab yellow and make it upright
            case MagicBlocks.STATE_START
                %check if he grabbed a yellow
                if (any(obj.mNewlyGrabbed) && ...
                    ~obj.mNewlyGrabbed(obj.PROP_YELLOW1) && ...
                    ~obj.mNewlyGrabbed(obj.PROP_YELLOW2))
                    
                    obj.mAlertOut(1) = obj.ALERT_NOT_GOING_TO_WORK;
                end

                if (obj.TestYellowUpRight(1) == 1)
                    obj.mAlertOut(1) = obj.ALERT_NICE;
                    obj.mStateOut(1) = obj.STATE_1_YELLOW;
                end

            case MagicBlocks.STATE_1_YELLOW
                %check if he grabbed a yellow
                if (any(obj.mNewlyGrabbed) && ...
                    ~obj.mNewlyGrabbed(obj.PROP_YELLOW1) && ...
                    ~obj.mNewlyGrabbed(obj.PROP_YELLOW2))

                    obj.mAlertOut(1) = obj.ALERT_NOT_GOING_TO_WORK;
                end

                iYellowUpRight = obj.TestYellowUpRight(2);
                if (iYellowUpRight == 2)
                    obj.mAlertOut(1) = obj.ALERT_NICE;
                    obj.mStateOut(1) = obj.STATE_2_YELLOW;

                elseif (iYellowUpRight == 0)
                    obj.mAlertOut(1) = obj.ALERT_TRY_AGAIN;
                    obj.mStateOut(1) = obj.STATE_START;
                end

            case MagicBlocks.STATE_2_YELLOW
                %check if he grabbed a green
                if (any(obj.mNewlyGrabbed) && ...
                    ~obj.mNewlyGrabbed(obj.PROP_GREEN))

                    obj.mAlertOut(1) = obj.ALERT_NOT_GOING_TO_WORK;
                end

                iYellowUpRight = obj.TestYellowUpRight(2);
                if (iYellowUpRight == 1)
                    obj.mAlertOut(1) = obj.ALERT_TRY_AGAIN;
                    obj.mStateOut(1) = obj.STATE_1_YELLOW;

                elseif (iYellowUpRight == 0)
                    obj.mAlertOut(1) = obj.ALERT_TRY_AGAIN;
                    obj.mStateOut(1) = obj.STATE_START;

                elseif (obj.TestGreen)
                    obj.mAlertOut(1) = obj.ALERT_FINISH_TRIANGLE;
                    obj.mStateOut(1) = obj.STATE_GATE;
                end

            case MagicBlocks.STATE_GATE
                %check if he grabbed a blue
                if (any(obj.mNewlyGrabbed) && ...
                   ~obj.mNewlyGrabbed(obj.PROP_BLUE))

                    obj.mAlertOut(1) = obj.ALERT_NOT_GOING_TO_WORK;
                end
                
                %degredation back
                if (~obj.TestGreen)
                    iYellowUpRight = obj.TestYellowUpRight(2);
                    if (iYellowUpRight == 1)
                        obj.mAlertOut(1) = obj.ALERT_CRASH;
                        obj.mStateOut(1) = obj.STATE_1_YELLOW;

                    elseif (iYellowUpRight == 0)
                        obj.mAlertOut(1) = obj.ALERT_CRASH;
                        obj.mStateOut(1) = obj.STATE_START;
                        
                    else
                        obj.mAlertOut(1) = obj.ALERT_TRY_AGAIN;
                        obj.mStateOut(1) = obj.STATE_2_YELLOW;
                    end
                else
                    %check triangle on top
                    if (obj.TestTriangle)    
                        obj.mAlertOut(1) = obj.ALERT_TADA;
                        obj.mStateOut(1) = obj.STATE_COOL_GATE;
                    end
                end
                
            case MagicBlocks.STATE_COOL_GATE
                %degredation back
                if (~obj.TestTriangle)
                    if (~obj.TestGreen)
                        iYellowUpRight = obj.TestYellowUpRight(2);
                        if (iYellowUpRight == 1)
                            obj.mAlertOut(1) = obj.ALERT_CRASH;
                            obj.mStateOut(1) = obj.STATE_1_YELLOW;

                        elseif (iYellowUpRight == 0)
                            obj.mAlertOut(1) = obj.ALERT_CRASH;
                            obj.mStateOut(1) = obj.STATE_START;

                        else
                            obj.mAlertOut(1) = obj.ALERT_CRASH;
                            obj.mStateOut(1) = obj.STATE_2_YELLOW;
                        end
                    else
                        obj.mAlertOut(1) = obj.ALERT_TRY_AGAIN;
                        obj.mStateOut(1) = obj.STATE_GATE;
                    end
                end
            end
            
            if (all(obj.mStateOut >= 0) && ...
                    nnz(obj.mStateOut(1) == obj.mStateOut) == length(obj.mStateOut))
                obj.iCurState = obj.mStateOut(1);
                obj.mStateOut(:) = -1;
            end
            if (all(obj.mAlertOut >= 0) && ...
                    nnz(obj.mAlertOut(1) == obj.mAlertOut) == length(obj.mAlertOut))
                obj.Alert(obj.mAlertOut(1));
                                
                %if decided an objec is indeed grabbed, flag it
                if (obj.mAlertOut(1) == obj.ALERT_NOT_GOING_TO_WORK)
                    iGrabbedProp = find(obj.mNewlyGrabbed,1,'first');
                end
                
                obj.mAlertOut(:) = -1;
            end
        end
        
        function OnEnterPerson(obj)
            if (obj.iCurState == obj.STATE_START)
                obj.Alert(obj.ALERT_WELCOME);
            end
        end
              
    end
end