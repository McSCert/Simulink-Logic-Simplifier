function [subExprOut, outIndex] = createLogicBlocks(expression, atomicExpr, memo, predicates, inExprs, startSys, endSys)
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
%       predicates
%       inExprs
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
newBlock = regexprep(block,['^' startSys], endSys, 'ONCE');

% Figure out in which (sub)system to generate the expression
assert(~isempty(find_system(block)))
isIfActionExpr = false; % Will update in the following if it should be true
if strcmp(blockType, 'SubSystem')
    % Determine if it's an if action SubSystem
    ifPat = ['(^|[^0-9A-z_])(', 'If_port_', '(Sub_|)', '[1-9]([0-9]*|)', ')([^0-9A-z_]|$)']; % Starts and ends with non-alphanumeric chars, may contain 'Sub_', must have a number at the end
    isIfActionExpr = ~isempty(regexp(expressionRHS, ifPat, 'once'));

    if ~isIfActionExpr
        createSys = newBlock; % Create blocks for this expression in this system
    else
        createSys = get_param(newBlock, 'Parent'); % Create blocks for this expression in this system
    end
elseif strcmp(blockType, 'Inport')
    createSys = get_param(get_param(newBlock, 'Parent'), 'Parent'); % Create blocks for this expression in the system above where the LHS is
else
    createSys = regexprep(get_param(block, 'Parent'),['^' startSys], endSys, 'ONCE'); % Create blocks for this expression in this system
end

% Make expression well formed
expressionRHS = makeWellFormed(expressionRHS);

% If LHS is a key to inExprs, then we need to connect the RHS to the port
% indicated in inExprs rather than to the LHS
isInExpr = inExprs.isKey(outBlockID);
if isInExpr
    if strcmp(blockType, 'Inport')
        % Connect Inport to the port indicated by inExprs and continue as
        % though LHS was not a key to inExprs
        
        % outBlockInport is the port indicated by inExprs
        ifInID = inExprs(outBlockID);
        tokens = regexp(ifInID, ['(^.*)' '(_u)' '([1-9][0-9]*$)'], 'tokens');
        ifID = tokens{1}{1};
        inNum = str2double(tokens{1}{3});
        ifHandle = getKeyFromVal(predicates, ifID);
        
        % Get the if block
        if strcmp(get_param(ifHandle,'Type'), 'block')
            ifBlock = getfullname(ifHandle);
        else
            ifBlock = get_param(ifHandle, 'Parent');
        end
        ifBlock = regexprep(ifBlock,['^' startSys], endSys, 'ONCE');
        ifLineSys = get_param(ifBlock, 'Parent');
        
        % Get the inport for the LHS of the expression
        outBlockInport = get_param(ifBlock, 'PortHandles');
        outBlockInport = outBlockInport.Inport;
        outBlockInport = outBlockInport(inNum);
        
        logicOut = regexprep(block,['^' startSys], endSys, 'ONCE');
        logicOutport = get_param(logicOut, 'PortHandles');
        logicOutport = logicOutport.Outport;
            
        add_line(ifLineSys, logicOutport, outBlockInport);
        
        isInExpr = false;
    else
        blockType = 'foobar'; % The type we determined was irrelevant since the LHS will not be the output anymore
    end
end
    
% Create blocks for RHS of expression
if ~isIfActionExpr
    if strcmp(blockType, 'If') || isBlackBoxExpression(expression)
        return % The expression is encapsulated in the block itself
    else
        [outExpression, ~] = createExpression(expressionRHS, 1, 1, atomicExpr, memo, createSys, startSys);
    end
    
    % Connect LHS to RHS
    if strcmp(blockType, 'SubSystem')
        % Note: SubSystem already created
        
        assert(strcmp(handleType, 'port'))
        
        % Get the outport corresponding to the indicated port of the new
        % SubSystem.
        subPort = atomicExpr(predicates(handle));
        inoutBlock = subport2inoutblock(subPort);
        outportSubBlockHandle = get_param(inoutBlock, 'Handle');
        
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

    else
        % Create block for LHS of expression
        if ~isInExpr
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
        end % else the block is already created
        
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
            if ~isInExpr
                outBlockInport = get_param(outBlockHandle, 'PortHandles');
                outBlockInport = outBlockInport.Inport;
            else
                % outBlockInport is the port indicated by inExprs
                ifInID = inExprs(outBlockID);
                tokens = regexp(ifInID, ['(^.*)' '(_u)' '([1-9][0-9]*$)'], 'tokens');
                ifID = tokens{1}{1};
                inNum = str2double(tokens{1}{3});
                ifHandle = getKeyFromVal(predicates, ifID);
                
                % Get the if block
                if strcmp(get_param(ifHandle,'Type'), 'block')
                    ifBlock = getfullname(ifHandle);
                else
                    ifBlock = get_param(ifHandle, 'Parent');
                end
                ifBlock = regexprep(ifBlock,['^' startSys], endSys, 'ONCE');
                
                % Get the inport for the LHS of the expression
                outBlockInport = get_param(ifBlock, 'PortHandles');
                outBlockInport = outBlockInport.Inport;
                outBlockInport = outBlockInport(inNum);
            end
        end
        
        add_line(createSys, logicOutport, outBlockInport);
    end
else % is an if action subsystem expression
    % Create the ActionPort
    origActionPortBlock = find_system(block, 'SearchDepth', 1, 'BlockType', 'ActionPort'); % Find the original ActionPort
    origActionPortBlock = origActionPortBlock{1};
    newActionPortBlock = regexprep(origActionPortBlock, ['^' startSys], endSys, 'ONCE');

    try
        add_block(origActionPortBlock, newActionPortBlock);
    catch ME
        if (strcmp(ME.identifier,'Simulink:Commands:AddBlockCantAdd'))
            % Do nothing
        else
            rethrow(ME)
        end
    end
    
    % Connect the If port to the SubSystem's action port
    
    % Get the action port
    subPort = atomicExpr(predicates(handle));
    ifActionBlock = get_param(subPort, 'Parent');
    subPorts = get_param(ifActionBlock, 'PortHandles');
    ifActionPort = subPorts.Ifaction;
            
    % Get the relevant if port
    
    % Recall: ifPat = ['(^|[^0-9A-z_])(', 'If_port_', '(Sub_|)', '[1-9]([0-9]*|)', ')([^0-9A-z_]|$)']; % Starts and ends with non-alphanumeric chars, may contain 'Sub_', must have a number at the end
    ifID = regexp(expressionRHS, ifPat, 'tokens');
    ifID = ifID{1}{2};
    ifPortHandle = atomicExpr(ifID);
    
    add_line(createSys, ifPortHandle, ifActionPort);
end
end

function [subExprOut, outIndex] = createExpression(expression, startIndex, index, atomicExpr, memo, sys, startSys)
%list of characters recognzied as valid connective characters.
connectives = {'&', '~', '=', '<', '>', '|'};

%this main loop functions as the parser of the expression. Loops until the entire string is parsed.
while (index <= length(expression))
    character = expression(index);
    switch character
        case '('
            %recursively call the function to create blocks for the inside of expression
            [subExpr, index] = createExpression(expression, index, index + 1, atomicExpr, memo, sys, startSys);
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
                [subExprToNegate, newIndex] = createExpression(expression, index + 1, index + 1, atomicExpr, memo, sys, startSys);
                
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
                    [operand, newIndex] = createExpression(expression, nextIndex - 1, nextIndex, atomicExpr, memo, sys, startSys);
                    
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
                    
                    %Find the subexpression for the second operand
                    nextIndex = index+length(connective);
                    [operand, newIndex] = createExpression(expression, nextIndex, nextIndex, atomicExpr, memo, sys, startSys);
                    
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
                [operand, newIndex] = createExpression(expression, nextIndex, nextIndex, atomicExpr, memo, sys, startSys);
                
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
            
            if isConstant && ~isKey(atomicExpr, val) && ~strcmp(startSys, sys)
                atomicBlock = add_block('built-in/Constant', [sys '/generated_' val '_constant'], 'MakeNameUnique', 'on', 'Value', val);
                % Don't save in atomicExpr because that's used at top level
                % specifically.
                %% TODO extend atomicExpr to work beyond top-level
            elseif isConstant && ~isKey(atomicExpr, val)
                atomicBlock = add_block('built-in/Constant', [sys '/generated_' val '_constant'], 'Value', val);
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