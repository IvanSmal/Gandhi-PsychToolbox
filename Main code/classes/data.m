classdef data
    properties
        eyepos
        cursor
        neural_data
        photodiode
        graphics_fliptimes;
        DiodeFlipStates;
        timestamps;
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
