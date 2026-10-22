classdef data
    properties
        eyepos
        cursor
        neural_data
        photodiode
        stimulus_events;      % one row per item appearing/disappearing and per state change: requested and displayed times (see buildStimulusTiming)
        stimulus_frames;      % per target / tag, and the photodiode: position and times on every flip it was shown
        clock_sync;           % Psychtoolbox <-> NIP (Trellis) clock pairs and fit, photodiode delay, NIP ticks of the first eye/photodiode sample and of the trial start
        timestamps;           % ms (getsecs clock) of each eye/photodiode sample; samples before clock_sync.trial_start_sample are from before the trial (ITI)
        stateCodes;           % state-name <-> digout code table (event markers)
    end

    methods
        function velocity=vel(obj,propName)
            velocity=diff(obj.(propName),1,1)*1000;
        end

        function [magnitude,theta]=vect(obj,propName)
            [theta,magnitude]=cart2pol(obj.(propName)(:,1),...
                obj.(propName)(:,2));
        end
    end
end
