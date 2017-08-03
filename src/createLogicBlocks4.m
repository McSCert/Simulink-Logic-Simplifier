function [subExprOut, outIndex] = createLogicBlocks4(expression, atomicExpr, memo, predicates, startSys, endSys)
% CREATELOGICBLOCKS Places blocks with appropriate connections into an
%   empty model to represent a logical expression.
%
%   Input:
%       expression  Logical expression (given as char array) to use to
%                   create the model. Assumes expression is given with
%                   brackets so that precedence can be ignored.
%       startIndex
%       index
%       atomicExpr
%       memo
%       sys
%
%   Output:
%       subExprOut
%       outIndex

% Get expression LHS and RHS
[outBlockID, expressionRHS] = getExpressionLhsRhs(expression);

% Get info about LHS
handle = getKeyFromVal(predicates, outBlockID);
handleType = get_param(handle,'Type');
% Get the block
if strcmp(handleType, 'block')
    block = getfullname(handle);
elseif strcmp(handleType, 'port')
    block = get_param(handle, 'Parent');
end
blockType = get_param(block, 'BlockType');

if strcmp(blockType, 'SubSystem')
    assert(~isempty(find_system(block)))
    createSys = regexprep(block, ['^' startSys], endSys, 'ONCE'); % Create blocks for this expression in this system
elseif strcmp(blockType, 'Inport')
    assert(~isempty(find_system(block)))
    temp = regexprep(get_param(block, 'Parent'), ['^' startSys], endSys, 'ONCE');
    createSys = get_param(temp, 'Parent'); % Create blocks for this expression in the system above where the LHS is
else
    assert(~isempty(find_system(block)))
    createSys = regexprep(get_param(block, 'Parent'), ['^' startSys], endSys, 'ONCE'); % Create blocks for this expression in this system
end
    
%% TODO look into the need for this
% Make expression well formed
expressionRHS = makeWellFormed(expressionRHS);

% Create blocks for RHS of expression
[outExpression, ~] = createExpression(expressionRHS, 1, 1, atomicExpr, memo, createSys);

% Connect LHS to RHS
if strcmp(blockType, 'SubSystem')
    % Note: SubSystem already created
    
    assert(strcmp(handleType, 'port'))
    
    % Get the outport corresponding to the indicated port of the new 
    % SubSystem.
    subPort = atomicExpr(predicates(handle));
    inoutBlock = subport2inoutblock(subPort);
    assert(length(inoutBlock) == 1)
    outportSubBlockHandle = get_param(inoutBlock{1}, 'Handle');
    
    % Connect outport to expression
    logicOut = memo(outExpression);
    if strcmp(get_param(logicOut, 'Type'), 'block')
        logicOutport = get_param(logicOut, 'PortHandles');
        logicOutport = logicOutport.Outport;
    else
        logicOutport = logicOut;
    end
    outBlockInport = get_param(outportSubBlockHandle, 'PortHandles');
    outBlockInport = outBlockInport.Inport;
    
    add_line(createSys, logicOutport, outBlockInport);
    
%     % Get port number of that outport
%     pNum = str2double(get_param(outportSubBlockHandle, 'Port'));
%     
%     % Get SubSystem outport with the same port number and set logicOutport
%     %   to that.
%     logicOutport = subPort;
%     clear logicOutport
%     subOutports = get_param(outBlock, 'PortHandles');
%     subOutports = subOutports.Outport;
%     for i = 1:length(subOutports)
%         if get_param(subOutports(i), 'PortNumber') == pNum
%             logicOutport = subOutports(i);
%             break
%         end
%     end
%     assert(exist('logicOutport','var'));
else
    % Create block for LHS of expression
    outBlock = regexprep(block,['^' startSys], endSys, 'ONCE');
    try
        outBlockHandle = add_block(block, outBlock);
    catch ME
        if (strcmp(ME.identifier,'Simulink:Commands:AddBlockCantAdd'))
            outBlockHandle = get_param(outBlock, 'Handle');
        else
            rethrow(ME)
        end
    end
    % origOutBlockHandle = getKeyFromVal(predicates, outBlockID);
    % origOutBlock = getfullname(origOutBlockHandle);
    % % origOutName = get_param(origOutBlockHandle, 'Name');
    % outBlock = regexprep(origOutBlock,['^' startSys], endSys, 'ONCE');
    % outBlockHandle = add_block(origOutBlock, outBlock);
    
    logicOut = memo(outExpression);
    
    handleType = get_param(logicOut,'Type');
    if strcmp(handleType, 'block')
        logicOutport = get_param(logicOut, 'PortHandles');
        logicOutport = logicOutport.Outport;
    elseif strcmp(handleType, 'port')
        logicOutport = logicOut;
    else
        error('Something went wrong')
    end
    
    if strcmp(blockType, 'Inport')
        outBlockInport = inoutblock2subport(outBlockHandle);
    else
        outBlockInport = get_param(outBlockHandle, 'PortHandles');
        outBlockInport = outBlockInport.Inport;
    end
    
    add_line(createSys, logicOutport, outBlockInport);
end
end

function [subExprOut, outIndex] = createExpression(expression, startIndex, index, atomicExpr, memo, sys)
%list of characters recognzied as valid connective characters.
connectives = {'&', '~', '=', '<', '>', '|'};

%this main loop functions as the parser of the expression. Loops until the entire string is parsed.
while (index <= length(expression))
    character = expression(index);
    switch character
        case '('
            %recursively call the function to create blocks for the inside of expression
            [subExpr, index] = createExpression(expression, index, index + 1, atomicExpr, memo, sys);
            index = index + 1;
        case ')'
            subExprOut = subExpr;
            outIndex = index;
            return
        case connectives
            % Get full connective, which may be more than one character. >=, etc
            conPat = '[><]=?|[~=]=|~|\-|&|\|';
            connective = regexp(expression(index:end), ['^' conPat], 'match', 'once');
            
            % Get the connective block operator type, and whether it's
            % binary relational, binary logical, or unary
            [opType, type] = getConnectiveBlock(connective); %gets the "operator" parameter for use in making the connective's block, as well as its type (logic/relationl)
            
            if type == 2 % Unary operator
                % Create the NOT logical block
                [subExprToNegate, newIndex] = createExpression(expression, index + 1, index + 1, atomicExpr, memo, sys);
                
                % Get the full expression of the logical operation
                if newIndex > length(expression)
                    exp = expression(startIndex:end);
                else
                    exp = expression(startIndex:newIndex);
                end
                
                if ~isKey(memo, exp)
                    % Add the appropriate block for the operator
                    if strcmp(opType, 'NOT')
                        addedBlock = addLogicalBlock('NOT', sys);
                    elseif strcmp(opType, 'NEGATIVE')
                        addedBlock = add_block(['built-in/' opType], [sys '/generated_' opType], 'MAKENAMEUNIQUE','ON');
                    else
                        error('Unexpected operator.')
                    end
                    
                    % Get the inport of the added block
                    ports = get_param(addedBlock, 'PortHandles');
                    inPort = ports.Inport;
                    
                    % Get the block for the operand and get its outport
                    block1 = memo(subExprToNegate);
                    if strcmp(get_param(block1, 'Type'), 'port')
                        block1 = get_param(block1, 'Parent');
                    end
                    ports = get_param(block1, 'PortHandles');
                    outPort = ports.Outport;
                    
                    % Connect the added block and its operand
                    add_line(sys, outPort, inPort);
                    
                    %increment the index, make the logical
                    %expression the new current subexpression,
                    %and add it to the memo
                    subExpr = exp;
                    memo(subExpr) = getBlockOutport(addedBlock);
                    index = newIndex + 1;
                else
                    index = newIndex + 1;
                    subExpr = exp;
                end
            elseif type == 0 % Logical operator
                try
                    opBlock = memo(subExpr);
                    if strcmp(get_param(opBlock, 'Type'), 'port')
                        opBlock = get_param(opBlock, 'Parent');
                    end
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
                    [operand, newIndex] = createExpression(expression, nextIndex - 1, nextIndex, atomicExpr, memo, sys);
                    
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
                        if strcmp(get_param(block1, 'Type'), 'port')
                            block1 = get_param(block1, 'Parent');
                        end
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
                        if strcmp(get_param(block2, 'Type'), 'port')
                            block2 = get_param(block2, 'Parent');
                        end
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
                        memo(subExpr) = getBlockOutport(block1);
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
                    [operand, newIndex] = createExpression(expression, nextIndex, nextIndex, atomicExpr, memo, sys);
                    
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
                        if strcmp(get_param(block1, 'Type'), 'port')
                            block1 = get_param(block1, 'Parent');
                        end
                        ports = get_param(block1, 'PortHandles');
                        outPort = ports.Outport;
                        add_line(sys, outPort, inPort(1));
                        
                        %get outport of second operand and
                        %connect it
                        block2 = memo(operand);
                        if strcmp(get_param(block2, 'Type'), 'port')
                            block2 = get_param(block2, 'Parent');
                        end
                        ports = get_param(block2, 'PortHandles');
                        outPort = ports.Outport;
                        add_line(sys, outPort, inPort(2));
                        
                        %increase index, make the current
                        %subexpression the full expression from the
                        %connective, and add the new logical
                        %block to the memo
                        index = newIndex + 1;
                        subExpr = exp;
                        memo(subExpr) = getBlockOutport(addedBlock);
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
                [operand, newIndex] = createExpression(expression, nextIndex, nextIndex, atomicExpr, memo, sys);
                
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
                    if strcmp(get_param(block1, 'Type'), 'port')
                        block1 = get_param(block1, 'Parent');
                    end
                    ports = get_param(block1, 'PortHandles');
                    outPort = ports.Outport;
                    add_line(sys, outPort, inPort(1));
                    
                    %get output of second operand and connect it
                    block2 = memo(operand);
                    if strcmp(get_param(block2, 'Type'), 'port')
                        block2 = get_param(block2, 'Parent');
                    end
                    ports = get_param(block2, 'PortHandles');
                    outPort = ports.Outport;
                    add_line(sys, outPort, inPort(2));
                    
                    %increase index, make the current
                    %subexpression the full expression from the
                    %connective, and add the new relational
                    %block to the memo
                    index = newIndex + 1;
                    subExpr = exp;
                    memo(subExpr) = getBlockOutport(addedBlock);
                else
                    index = newIndex + 1;
                    subExpr = exp;
                end
            end
        otherwise
            %the case where the index is an atomic proposition (a variable or constant), the base case
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
    subExprOut = subExpr;
    outIndex = index;
end
end

function outport = getBlockOutport(block)
% Gets the outport handle of a given block.
% Errors if there is less or more than one outport handle.

ports = get_param(block, 'PortHandles');
outport = ports.Outport;
assert(length(outport) == 1)
end