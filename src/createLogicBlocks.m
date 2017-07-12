function [subExprOut, outIndex] = createLogicBlocks(expression, startIndex, index, atomicExpr, memo, sys)
%CREATELOGICBLOCKS Takes the logical expression converts it into blocks
%with connections, using a string expression and a map of atomic
%proposition names to signals.

%list of characters recognzied as valid connective characters.
connectives = {'&', '~', '=', '<', '>', '|'};

%this main loop functions as the parser of the expression. Loops until the entire string is parsed.
while (index <= length(expression))
    character = expression(index);
    switch character
        case '('
            %recursively call the function to create blocks for the inside of expression
            [subExpr, index] = createLogicBlocks(expression, index, index + 1, atomicExpr, memo, sys);
            index = index + 1;
        case connectives
            %get full connective, which may be more than one character. =>, etc
            connective = regexp(expression(index:end), '^[&\|~=<>]+', 'match');
            connective = connective{1};
            
            %get the connective block operator type, and whether it's relational or logical
            [opType, type] = getConnectiveBlock(connective); %gets the "operator" parameter for use in making the connective's block, as well as its type (logic/relationl)
            
            if strcmp(opType, 'NOT')
                %create the NOT logical block
                [subExprToNegate, newIndex] = createLogicBlocks(expression, index + 1, index + 1, atomicExpr, memo, sys);
                
                %get the full expression of the logical operation
                try
                    exp = expression(startIndex:newIndex);
                catch E
                    if newIndex > length(expression)
                        exp = expression(startIndex:end);
                    else
                        error(E);
                    end
                end
                
                if ~isKey(memo, exp)
                    %add the NOT block and get its inport
                    addedBlock = addLogicalBlock('NOT', sys);
                    ports = get_param(addedBlock, 'PortHandles');
                    inPort = ports.Inport;
                    
                    %get the block for the operand and get its outport
                    block1 = memo(subExprToNegate);
                    ports = get_param(block1, 'PortHandles');
                    outPort = ports.Outport;
                    
                    %connect the NOT block and its operand
                    add_line(sys, outPort, inPort);
                    
                    %increment the index, make the logical
                    %expression the new current subexpression,
                    %and add it to the memo
                    subExpr = exp;
                    memo(subExpr) = addedBlock;
                    index = newIndex + 1;
                else
                    index = newIndex + 1;
                    subExpr = exp;
                end
            else
                if (type==0) %if operator is logical
                    try
                        opBlock = memo(subExpr);
                        operator = get_param(opBlock, 'Operator');
                    catch
                        operator = '';
                    end
                    if strcmp(opType, operator)
                        %if the operator is the same operator that preceded it, simply added another
                        %port to the existing operator and connect it with the next subexpr,
                        %instead of creating another one.
                        
                        nextIndex = index+length(connective)+1;
                        
                        %get the sub expression of the second operand
                        [operand, newIndex] = createLogicBlocks(expression, nextIndex - 1, nextIndex, atomicExpr, memo, sys);
                        
                        %get the full expression of the logical
                        %operation
                        try
                            exp = expression(startIndex:newIndex);
                        catch E
                            if newIndex > length(expression)
                                exp = expression(startIndex:end);
                            else
                                error(E);
                            end
                        end
                        
                        if ~isKey(memo, exp)
                            %increment the number of inputs for the
                            %operation
                            block1 = memo(subExpr);
                            numInputs = get_param(block1, 'Inputs');
                            numInputs = num2str(str2num(numInputs) + 1);
                            set_param(block1, 'Inputs', numInputs);
                            
                            %get the inports of the logical operation
                            %block to add an input too
                            ports = get_param(block1, 'PortHandles');
                            inPort = ports.Inport;
                            inPort = inPort(end);
                            
                            %get the outport of the second operand
                            block2 = memo(operand);
                            ports = get_param(block2, 'PortHandles');
                            outPort = ports.Outport;
                            
                            %connect the second operand to the logical
                            %operation block
                            add_line(sys, outPort, inPort);
                            
                            %increment the index, make the logical
                            %expression the new current subexpression,
                            %and add it to the memo
                            index = newIndex + 1;
                            subExpr = exp;
                            memo(subExpr) = block1;
                        else
                            index = newIndex + 1;
                            subExpr = exp;
                        end
                    else
                        %otherwise, we're going to have to create a new block for the operator. Similar process
                        %to the first block of this if statement. Recursively find the subexpr for the operand,
                        %and connect its output to the new logical operator block.
                        
                        %Find the subexpression for the secnod operand
                        nextIndex = index+length(connective);
                        [operand, newIndex] = createLogicBlocks(expression, nextIndex, nextIndex, atomicExpr, memo, sys);
                        
                        %Get the full expression of the operation
                        try
                            exp = expression(startIndex:newIndex);
                        catch E
                            if newIndex > length(expression)
                                exp = expression(startIndex:end);
                            else
                                error(E);
                            end
                        end
                        
                        %If a block for that expression doesn't exist,
                        %make one
                        if ~isKey(memo, exp)
                            
                            %add new logical block and get its ports
                            addedBlock = addLogicalBlock(opType, sys);
                            ports = get_param(addedBlock, 'PortHandles');
                            inPort = ports.Inport;
                            
                            %get outport of the first operand and
                            %connect it
                            block1 = memo(subExpr);
                            ports = get_param(block1, 'PortHandles');
                            outPort = ports.Outport;
                            add_line(sys, outPort, inPort(1));
                            
                            %get outport of second operand and
                            %connect it
                            block2 = memo(operand);
                            ports = get_param(block2, 'PortHandles');
                            outPort = ports.Outport;
                            add_line(sys, outPort, inPort(2));
                            
                            %increase index, make the current
                            %subexpression the full expression from the
                            %connective, and add the new logical
                            %block to the memo
                            index = newIndex + 1;
                            subExpr = exp;
                            memo(subExpr) = addedBlock;
                        else
                            index = newIndex + 1;
                            subExpr = exp;
                        end
                    end
                else %if operator is relational
                    %since relational operators only have two operands, create a new relational operator
                    %block similarly to the else case above for logical operators.
                    nextIndex = index+length(connective);
                    
                    %get the logical expression of the second operand
                    [operand, newIndex] = createLogicBlocks(expression, nextIndex, nextIndex, atomicExpr, memo, sys);
                    
                    %get the full expression of the relational
                    %operation
                    try
                        exp = expression(startIndex:newIndex);
                    catch E
                        if newIndex > length(expression)
                            exp = expression(startIndex:end);
                        else
                            error(E);
                        end
                    end
                    
                    if~isKey(memo, exp)
                        %add block for the operation and get its
                        %inports
                        addedBlock = addRelationalBlock(opType, sys);
                        ports = get_param(addedBlock, 'PortHandles');
                        inPort = ports.Inport;
                        
                        %get outport of first operand and connect it
                        block1 = memo(subExpr);
                        ports = get_param(block1, 'PortHandles');
                        outPort = ports.Outport;
                        add_line(sys, outPort, inPort(1));
                        
                        %get output of second operand and connect it
                        block2 = memo(operand);
                        ports = get_param(block2, 'PortHandles');
                        outPort = ports.Outport;
                        add_line(sys, outPort, inPort(2));
                        
                        %increase index, make the current
                        %subexpression the full expression from the
                        %connective, and add the new relational
                        %block to the memo
                        index = newIndex + 1;
                        subExpr = exp;
                        memo(subExpr) = addedBlock;
                    else
                        index = newIndex + 1;
                        subExpr = exp;
                    end
                end
            end
        case ')'
            subExprOut = subExpr;
            outIndex = index;
            return
        otherwise
            %the case where the index is an atomic proposition (a variable), the base case
            atomic = regexp(expression(index:end), '^[\w]+', 'match');
            
            % Check if atomic is a constant, if it is, get its value
            if strcmp(atomic{1},'TRUE') || strcmp(atomic{1},'FALSE')
                atomic{1} = lower(atomic{1});
                val = atomic{1};
                isConstant = true;
            elseif ~isempty(regexp(atomic{1}, '^[0-9]+\.?[0-9]*$', 'once'))
                val = regexp(atomic{1}, '^[0-9]+\.?[0-9]*$', 'match', 'once');
                isConstant = true;
            else
                isConstant = false;
            end
            
            if isConstant && ~isKey(atomicExpr, val)
                atomicBlock = add_block('built-in/Constant', [sys '/generated_constant_' val], 'Value', val);
                atomicExpr(val) = atomicBlock;
            else
                atomicBlock = atomicExpr(atomic{1});
            end
            index = index + length(atomic{1});
            subExpr = expression(startIndex:index);
            memo(subExpr) = atomicBlock;
    end
end
subExprOut = subExpr;
outIndex = index;
end

