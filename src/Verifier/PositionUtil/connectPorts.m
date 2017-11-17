function lineHandle = connectPorts(address, port1, port2, varargin)
% CONNECTPORTS Connect two unconnected ports.
%
%   Inputs:
%       address     System name.
%       port1       Source port that will be connected.
%       port2       Destination port that will be connected.
%       varargin    Options for add_line (e.g. 'autorouting', 'on).
%
%   Outputs:
%       lineHandles New line handle.

    % Input checks
    assert(strcmp(get_param(port1, 'Type'), 'port'), ...
        'Input port1 is expected to be a port handle.')
    assert(strcmp(get_param(port2, 'Type'), 'port'), ...
        'Input port2 is expected to be a port handle.')
    assert(get_param(port1, 'Line') == -1 || ...
        strcmp(get_param(port1, 'PortType'), 'outport'), ...
        'Input port1 already has a line connection.');
    assert(get_param(port2, 'Line') == -1 || ...
        strcmp(get_param(port2, 'PortType'), 'outport'), ...
        'Input port2 already has a line connection.');
    
    port1Type = get_param(port1, 'PortType');
    port2Type = get_param(port2, 'PortType');
    
    % Future: Support Trigger, Enable, State, LConn, RConn, Ifaction, Reset
    assert(xor(strcmp(port1Type, 'inport'), strcmp(port2Type, 'inport')), ...
        'At least one port must be an inport and one must be an outport');
    assert(xor(strcmp(port1Type, 'outport'), strcmp(port2Type, 'outport')), ...
        'At least one port must be an inport and one must be an outport');
    
    if strcmp(port1Type, 'outport')
        lineHandle = makeLine(port1, port2);
    else
        lineHandle = makeLine(port2, port1);
    end
    
    function lineH = makeLine(out, in)
        % Connect out to in even if a segmented line needs to be created
        lh = get_param(out, 'Line');
        if lh == -1
            lineH = add_line(address, out, in, varargin{:});
        else
            % Need to make a segmented/branched line
            points = get_param(lh, 'Points');
            lineH = add_line(address, [points(1,:); get_param(in, 'Position')], varargin{:});
        end
    end
end