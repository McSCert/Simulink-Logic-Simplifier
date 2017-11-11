function type = expressionType(h)
% EXPRESSIONTYPE Returns the type of expression that would be created for a
%   given handle. The types are: 'blk', 'in', 'out'
%
%   Input:
%       h       Simulink object handle. Must be for a blocks or a port.
%
%   Output:
%       type    Types of expression: 'blk', 'in', 'out'

hType = get_param(h,'Type');

switch hType
    case 'block'
        type = 'blk';
    case 'port'
        if strcmp('outport', get_param(h, 'PortType'))
            type = 'out';
        else % inport, ifaction, trigger, etc.
            type = 'in';
        end
    otherwise
        % Lines and annotations not valid
        error(['Error unexpected handle type.'])
end

end