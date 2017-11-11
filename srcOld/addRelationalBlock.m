function block = addRelationalBlock(opType, sys)
%adds a relational operator block of the specified optype

    flag = 1;
    num = 0;
    %makes sure added block has a unique name
    while flag
        try
            block = add_block('built-in/RelationalOperator', [sys '/GeneratedRelator' num2str(num)]);
            flag = 0;
        catch
            flag = 1;
            num = num + 1;
        end
    end
    %actually adds the block
    set_param(block, 'Operator', opType);

end

