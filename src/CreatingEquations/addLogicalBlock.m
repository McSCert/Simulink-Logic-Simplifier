function block = addLogicalBlock(opType, sys, varargin)
% ADDLOGICALBLOCK Add a logical operator block of the specified optype.

    % Make sure added operator block has a unique name associated with it
    block = add_block('built-in/Logic', getGenBlockName(sys, opType), 'MAKENAMEUNIQUE','ON', varargin{:});

    % temp - eventually pass this with varargin, and potentially avoid the need
    % for it
    set_param(block, 'AllPortsSameDT', 'off');

    % Set operator
    set_param(block, 'Operator', opType);
end