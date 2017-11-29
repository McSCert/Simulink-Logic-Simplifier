function [connectSrc, idx] = createLogic(rhs, exprs, startSys, sys, idx, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule)
% CREATELOGIC Places blocks with appropriate connections into an
%   empty model to represent a logical expression.
%
%   Input:
%       rhs         Right-hand side of an expression. rhs should be a valid
%                   logical expression.
%       exprs       Cell array of expressions.
%       startSys    System from which the original blocks come from.
%       sys         System in which to create blocks/signals to represent rhs
%       idx         Index of the 'current position' in rhs.
%       s_lhsTable      Map from block/port handle in the original system
%                       to lhs in exprs and vice versa. (2-way map)
%       e_lhs2handle    Map from lhs in exprs to block/port handle in the 
%                       final system. (1-way map)
%       s2e_blockHandles    Map of block handles from the start system to the
%                           end system.
%
%   Output:
%       connectSrc  The final output port which will will have a signal
%                   equivalent to rhs.
%       idx         An update to the index based on what occurred in the
%                   current iteration.

% List of characters recognzied as valid connective characters.
connectives = getConnectiveChars();

% This main loop functions as the parser of the expression. 
% The loop continues until the entire rhs is parsed.
while (idx <= length(rhs))
    character = rhs(idx);
    switch character
        case '('
            % Recurse to create blocks for the subformula between brackets
            [connectSrc, idx] = createLogic(rhs, exprs, startSys, sys, idx+1, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
            idx = idx + 1;
        case ')'
            % connectSrc and idx already set
            assert(logical(exist('connectSrc', 'var')) && logical(exist('idx', 'var')), ...
                'Error: Something went wrong, end bracket reached before setting outputs.')
            return % End of subformula
        case connectives
            connective = getFullConnective(rhs,idx);
            
            % Get the connective block operator type, and whether it's
            % binary relational, binary logical, or unary
            [opType, type] = getConnectiveBlock(connective); % Gets the "operator" parameter for use in making the connective's block, as well as its type (logic/relation/unary)
            
            switch type
                case 0 % Binary logical operator - Simulink can use these operators with n > 1 inputs
                    opBlock = get_param(connectSrc, 'Parent');
                    if strcmp(get_param(opBlock, 'BlockType'), 'Logic')
                        operator = get_param(opBlock, 'Operator');
                    else
                        operator = '';
                    end
                    
                    % Set the source for the next operand
                    nextIdx = idx + length(connective);
                    [operandRight, newIdx] = createLogic(rhs, exprs, startSys, sys, nextIdx, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
                    
                    if ~strcmp(opType, operator)
                        % If connectSrc does not belong to the same operator as 
                        % the current operator, we need to create a new block 
                        % for the operator.
                        
                        % Set the source for the first operand
                        operandLeft = connectSrc;
                    
                        % Add new logical block and get its ports
                        addedBlock = addLogicalBlock(opType, sys, 'Inputs', '2');
                        ports = get_param(addedBlock, 'PortHandles');
                        connectDsts = ports.Inport;
                        
                        % Add line from first operand to Logic block
                        connectPorts(sys, operandLeft, connectDsts(1));
                        % Add line from second operand to Logic block
                        connectPorts(sys, operandRight, connectDsts(2));
                        
                        % Set outputs for the recursion.
                        assert(length(ports.Outport) == 1, 'Error: Logical block expected to have 1 output.')
                        connectSrc = ports.Outport(1);
                        idx = newIdx + 1;
                    else
                        % If connectSrc belongs to the same operator as the 
                        % current operator, simply add another port to the
                        % existing operator block and connect the next
                        % operand.
                        
                        % Add a port to the Logic block
                        numInputs = get_param(opBlock, 'Inputs');
                        numInputs = num2str(str2num(numInputs) + 1);
                        set_param(opBlock, 'Inputs', numInputs);
                        ports = get_param(opBlock, 'PortHandles');
                        connectDsts = ports.Inport;
                        
                        % Add line from second operand to Logic block
                        connectPorts(sys, operandRight, connectDsts(end));
                        
                        % Set outputs for the recursion.
                        %   connectSrc is left as the outport of the 'Logic'
                        %   block.
                        idx = newIdx + 1;
                    end
                        
%                     if ~logical(exist('oldConnective', 'var')) || ~strcmp(oldConnective, connective)
%                         % Create new connective block
%                         
%                         oldConnective = connective;
%                         
%                         tempIdx = idx;
% 
%                         connectSrcs = [];
%                         assert(logical(exist('connectSrc', 'var')), 'Error: Something went wrong, connectSrc not set.') % Should have been set in an earlier iteration of the loop.
%                         connectSrcs(end+1) = connectSrc;
%                         while strcmp(connective, getFullConnective(rhs, tempIdx)) % While the operator is the same as the preceding one
% 
%                             % Get the start of next operand
%                             % idx is the start of the connective and we want the 
%                             % point after the connective
%                             nextIdx = tempIdx+length(connective);
% 
%                             % Get the sub expression of the second operand
%                             % TODO: why did the old version pass nextIdx + 1
%                             % for the idx? did it work because it
%                             % coincidentally cropped whitespace?
%                             [connectSrcs(end+1), newIdx] = createLogic(rhs, exprs, startSys, sys, nextIdx, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
% 
%                             tempIdx = newIdx + 1;
%                         end
%                         numInputs = length(connectSrcs);
% 
%                         % Add new logical block and get its ports
%                         addedBlock = addLogicalBlock(opType, sys, 'Inputs', num2str(numInputs));
%                         ports = get_param(addedBlock, 'PortHandles');
%                         connectDsts = ports.Inport;
% 
%                         for i = 1:numInputs
%                             connectPorts(sys, connectSrcs(i), connectDsts(i));
%                         end
% 
%                         % Set outputs for the recursion.
%                         assert(length(ports.Outport) == 1, 'Error: Logical block expected to have 1 output.')
%                         connectSrc = ports.Outport(1);
%                         idx = newIdx + 1;
%                         
%                     else
%                         
%                     end
                case 1 % Binary relational operator
                    % Relational operators only have two operands, we don't
                    % need to worry about the number of inputs unlike for
                    % the type == 0 case.
                    
                    nextIdx = idx + length(connective);
                    
                    % Get the outport of the second operand connectSrc is
                    % the 1st operand.
                    [operand2, newIdx] = createLogic(rhs, exprs, startSys, sys, nextIdx, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
                    
                    % Add new relational block and get its ports
                    addedBlock = addRelationalBlock(opType, sys);
                    ports = get_param(addedBlock, 'PortHandles');
                    connectDsts = ports.Inport;
                    
                    connectPorts(sys, connectSrc, connectDsts(1));
                    connectPorts(sys, operand2, connectDsts(2));
                    
                    % Set outputs for the recursion.
                    assert(length(ports.Outport) == 1, 'Error: Relational block expected to have 1 output.')
                    connectSrc = ports.Outport(1); % Outport of the full expression from the connective
                    idx = newIdx + 1;
                case 2 % Unary operator, '~'
                    [notSrc, newIdx] = createLogic(rhs, exprs, startSys, sys, idx+1, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
                    
                    % TODO: If expression has already been made in the current
                    %   system, then use that. Currently makes a new one
                    %   regardless.
                    % Add the block for the operator
                    if strcmp(opType, 'NOT')
                        addedBlock = addLogicalBlock('NOT', sys);
                    elseif strcmp(opType, 'NEGATIVE')
                        addedBlock = add_block(['built-in/' opType], getGenBlockName(sys, opType), 'MAKENAMEUNIQUE','ON');
                    else
                        error('Error: Unsupported operator detected.')
                    end
                    
                    % Get the inport of the added block
                    ports = get_param(addedBlock, 'PortHandles');
                    assert(length(ports.Inport) == 1, 'Error: Unary block expected to have 1 input.')
                    connectDst = ports.Inport(1);
                    
                    % Connect the operand to the added block
                    connectPorts(sys, notSrc, connectDst);
                    
                    % Set outputs for the recursion.
                    assert(length(ports.Outport) == 1, 'Error: Logical block expected to have 1 output.')
                    connectSrc = ports.Outport(1);
                    idx = newIdx + 1;
                otherwise
                    error('Error: Unexpected type of operation for a connective.')
            end
            
        otherwise
            % The case where the index is an atomic proposition (a variable or
            % constant), the base case.
            
            atomic = regexp(rhs(idx:end), '^[\w]+', 'match', 'once');
            
            % Check if atomic is a constant, if it is, get its value
            if any(strcmp(atomic, {'TRUE', 'FALSE'}))
                atomic = lower(atomic);
                val = atomic;
                isConstant = true;
            elseif ~isempty(regexp(atomic, '^[0-9]+\.?[0-9]*$', 'once'))
                val = regexp(atomic, '^[0-9]+\.?[0-9]*$', 'match', 'once');
                isConstant = true;
            else
                isConstant = false;
            end
            
            if isConstant
                atomicBlock = add_block('built-in/Constant', getGenBlockName(sys, [val '_Constant']), 'MakeNameUnique', 'on', 'Value', val);
                % Get the outport of the added block
                ports = get_param(atomicBlock, 'PortHandles');
                assert(length(ports.Outport) == 1, 'Error: Constant expected to have 1 output.')
                connectSrc = ports.Outport(1);
            else
                connectSrc = createExpr(atomic, exprs, startSys, sys, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
            end

            idx = idx + length(atomic);
    end
end
assert(logical(exist('connectSrc', 'var')) && logical(exist('idx', 'var')), ...
    'Error: End of expression reached before setting outputs.')
end