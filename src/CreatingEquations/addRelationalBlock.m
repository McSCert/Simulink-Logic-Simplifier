function block = addRelationalBlock(opType, sys, varargin)
%adds a relational operator block of the specified optype

    %make sure added operator block has a unique name associated with it
    block = add_block('built-in/RelationalOperator', getGenBlockName(sys, 'RelationalOp'), 'MAKENAMEUNIQUE','ON', varargin{:});

    % temp - eventually pass this with varargin, and potentially avoid the need
    % for it
    set_param(block, 'InputSameDT', 'off')
    
    %set operator
    set_param(block, 'Operator', opType);

end

