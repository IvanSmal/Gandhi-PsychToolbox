classdef graphics < handle
    % GRAPHICS Object to handle visual rendering and screen control
    %   Manages screen setup, rendering, and coordinate transformations
    %   for experimental displays and monitoring interfaces
    
    properties (Access = public)
        %% Screen configuration
        screenparams                % Screen parameters and settings
        screens                     % Available screen indices
        window_main                 % Main stimulus presentation window
        window_monitor              % Secondary monitoring window
        windowRect                  % Rectangle defining the main window
        monitor_rect                % Rectangle defining the monitoring window
        screenXpixels               % Width of the screen in pixels
        screenYpixels               % Height of the screen in pixels
        width                       % Physical width of the screen
        height                      % Physical height of the screen
        xCenter                     % X-coordinate of screen center
        yCenter                     % Y-coordinate of screen center
        
        %% Monitor window parameters
        original_monitor_params     % Original panel fitter parameters
        winparams                   % Current window parameters
        newsize                     % Current size of window
        newsize_true                % Adjusted true size of window
        scalefactor = 1             % Scaling factor for monitor window
        left_right = 0              % Horizontal adjustment
        up_down = 0                 % Vertical adjustment
        
        %% Grid and coordinate system
        fontsize = 30               % Font size for text display
        circleadder = 10            % Spacing for circular guides
        gridArraysInitialized       % Flag for grid array initialization
        xlines                      % X-coordinate grid lines
        ylines                      % Y-coordinate grid lines
        toconvert                   % Coordinate conversion table
        pixelsforlines              % Pixel positions for grid lines
        gridlinesmatrix             % Matrix of grid line coordinates
        center_circle = [0 0 0 0]   % Center circle coordinates
        
        %% Experimental stimuli
        monitortexture              % Texture for monitor window
        monitormovieplaceholder     % Placeholder image for movies
        movie                       % Movie stimulus
        texture                     % Current texture
        diode_pos                   % Photodiode position
        diode_color = [0 0 0]       % Photodiode color
        
        %% Eye tracking
        eye                         % Eye tracking information
        eyehistory                  % History of eye positions
        
        %% Trial state management
        fliprequest = 0             % Request for screen flip
        flipped = 0                 % Flag indicating screen was flipped
        trialstarted = 0            % Flag indicating trial has started
        activestatename = 'null'    % Name of current trial state
        state_history = {'null'}    % History of trial states
        
        %% Command processing
        functionsbuffer = []        % Buffer for graphics commands
        lastarg                     % Last argument processed
        fliptimes                   % Timing of screen flips
        commandIDs                  % IDs of processed commands
        commid_udp                  % Current command ID from UDP
        movieplaying = 0            % Flag indicating movie is playing
        
        %% User interface components
        UIFigure                    matlab.ui.Figure
        TurnthisoffifthiswindowslowsdowngraphicsSwitch  matlab.ui.control.Switch
        TurnthisoffifthiswindowslowsdowngraphicsSwitchLabel  matlab.ui.control.Label
        photodiodesquarecolorLamp   matlab.ui.control.Lamp
        photodiodesquarecolorLampLabel  matlab.ui.control.Label
        StateEditField              matlab.ui.control.EditField
        StateEditFieldLabel         matlab.ui.control.Label
        ypositionEditField          matlab.ui.control.EditField
        ypositionEditFieldLabel     matlab.ui.control.Label
        xpositionEditField          matlab.ui.control.EditField
        xpositionEditFieldLabel     matlab.ui.control.Label
        
        %% Miscellaneous
        user_defined                % User-defined custom data
        target                      % Target information

        %% extra
        actualFlipCount
        actualCommandCount
    end
end