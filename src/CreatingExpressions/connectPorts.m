function connectPorts(sys, srcPort, dstPort)
% CONNECTPORTS Connects ports together by adding a signal line between them.
%
%   Input:
%       sys         System where the ports are.
%       srcPort     Handle of a source port (i.e. outport).
%       dstPort     Handle of some destination port (e.g. inport, ifaction, ...)

% TODO check logic of this function
%   check if line already created
%   check for need to branch and such

add_line(sys, srcPort, dstPort)
end