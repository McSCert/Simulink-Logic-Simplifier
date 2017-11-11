function block = addRelationalBlock(opType, sys, varargin)
%adds a relational operator block of the specified optype

    %makes sure added operator block has a unique name associated with it
    block = add_block('built-in/RelationalOperator', getGenBlockName(sys, 'RelationalOp'), 'MAKENAMEUNIQUE','ON', varargin{:});

    %actually adds the block
    set_param(block, 'Operator', opType);

end

