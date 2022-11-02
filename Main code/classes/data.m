classdef data
    properties
        eyepos
        cursor
        neural_data
        eyesync
    end

    methods
        function ev=vel(in,property)
            ev=diff(in.(property),1,1)*1000;
        end

        function [m,t]=vect(in,property)
            [t,m]=cart2pol(in.(property)(:,1),...
                in.(property)(:,2));
        end
    end
end