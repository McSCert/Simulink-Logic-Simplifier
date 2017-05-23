function block = addLogicalBlock(opType, sys)
%adds a logical operator block of the specified optype

    flag = 1;
    num = 0;
    %makes sure added operator block has a unique name associated with it
    while flag
        try
            block = add_block('built-in/Logic', [sys '/Generated' opType num2str(num)]);
            flag = 0;
        catch
            flag = 1;
            num = num + 1;
        end
    end
    %actually adds the block
    set_param(block, 'Operator', opType);

end

