function block = addLogicalBlock(opType, sys, varargin)
%adds a logical operator block of the specified optype

    %makes sure added operator block has a unique name associated with it
    block = add_block('built-in/Logic', getGenBlockName(sys, opType), 'MAKENAMEUNIQUE','ON', varargin{:});
    
    %actually adds the block
    set_param(block, 'Operator', opType);

end

