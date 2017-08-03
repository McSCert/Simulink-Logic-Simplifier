function block = addLogicalBlock(opType, sys)
%adds a logical operator block of the specified optype

    %makes sure added operator block has a unique name associated with it
    block = add_block('built-in/Logic', [sys '/Generated' opType], 'MAKENAMEUNIQUE','ON');
    
    %actually adds the block
    set_param(block, 'Operator', opType);

end

