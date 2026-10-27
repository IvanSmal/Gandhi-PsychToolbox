classdef data
    properties
        eyepos
        cursor                % per enabled cursor: id, pos (deg), time_ms of each sample
        neural_data
        photodiode
        stimulus_events;      % one row per item appearing/disappearing and per state change: requested_ms, displayed_ms, photon_ms (see buildStimulusTiming)
        stimulus_frames;      % per target / tag, and the photodiode: position and times on every frame it was shown
        clock_sync;           % how the times were made: Psychtoolbox <-> NIP clock pairs and fit, photodiode delay, raw clock values
        time_ms;              % ms since the trial start of each eye/photodiode sample; negative = before the trial (ITI)
        stateCodes;           % state-name <-> digout code table (event markers)
        loop_ms;              % how long each pass of MHost2's trial loop took (ms), in order
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
