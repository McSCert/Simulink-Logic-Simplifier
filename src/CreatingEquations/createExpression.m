function [connectSrc, idx] = createExpression(expr, exprs, startSys, sys, idx, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule)
    % CREATEEXPRESSION Places blocks with appropriate connections into an
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
    
    subexprs = findNextSubexpressions(expr);
    if isempty(subexprs)
        % The case where the index is an atomic proposition (a variable or
        % constant), the base case.
        
        atomic = regexp(expr, '^[\w]+', 'match', 'once');
        assert(strcmp(expr,atomic), 'Something went wrong, expression in unexpected form.')
        
        % Check if atomic is a constant, if it is, get its value
        if any(strcmp(atomic, {'true', 'false', 'TRUE', 'FALSE'}))
            atomic = lower(atomic);
            val = atomic;
            isConstant = true;
        elseif ~isempty(regexp(atomic, '^[0-9]+\.?[0-9]*$', 'once'))
            val = regexp(atomic, '^[0-9]+\.?[0-9]*$', 'match', 'once');
            isConstant = true;
        else
            isConstant = false;
        end
        
        % 
        if isConstant
            const_blk = 'built-in/Constant';
            atomicBlock = add_block(const_blk, ...
                getGenBlockName(sys, [val '_' get_param(const_blk, 'BlockType')]), ...
                'MakeNameUnique', 'on', 'Value', val);
            % Get the outport of the added block
            ports = get_param(atomicBlock, 'PortHandles');
            assert(length(ports.Outport) == 1, 'Error: Constant expected to have 1 output.')
            connectSrc = ports.Outport(1);
        else
            connectSrc = createRhs(atomic, exprs, startSys, sys, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
        end
    else
        [opIdx1, opIdx2] = findLastOp(expr, 'alt');
        if opIdx1 ~= 0
            op = expr(opIdx1:opIdx2);
            if any(strcmp(op, {'&','|'}))
                subexprs = expand2nAry(subexprs, op);
            end
        end
        
        output_ports = cell(1,length(subexprs));
        for i = 1:length(subexprs)
            % Create logic for the subexpressions
            
            % TODO: If expression has already been made in the current
            %   system, then use that. Currently makes a new representation.
            
            output_ports{i} = createExpression(subexprs{i}, exprs, startSys, sys, idx, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
        end

        if opIdx1 == 0
            % There is no operator for the subexprs
            assert(length(subexprs) == 1)
            
            % Set connectSrc to the output from the created subexpression
            connectSrc = output_ports{1};
        else
            if strcmp(op,'~')
                % Unary operator, '~'
                
                assert(length(subexprs) == 1)
                
                % Create a logical NOT block
                if strcmp(op, '~')
                    opType = 'NOT';
                    addedBlock = addLogicalBlock(opType, sys);
                elseif strcmp(op, '-')
                    opType = 'UnaryMinus';
                    addedBlock = add_block(['built-in/' opType], getGenBlockName(sys, opType), 'MAKENAMEUNIQUE','ON');
                else
                    error('Error: Unsupported operator detected.')
                end
                
                % Connect the output from the created subexpression to the
                % NOT block.
                
                % Get the inport of the added block
                ports = get_param(addedBlock, 'PortHandles');
                assert(length(ports.Inport) == 1, 'Error: Unary block expected to have 1 input.')
                connectDst = ports.Inport(1);
                
                % Connect the operand to the added block
                connectPorts(sys, output_ports{1}, connectDst);
                
                % Set connectSrc to the output of the NOT block.
                assert(length(ports.Outport) == 1, 'Error: Logical block expected to have 1 output.')
                connectSrc = ports.Outport(1);

            else
                % Create the appropriate block to merge the subexpressions
                % based on the original expression.
                
                if any(strcmp(op, {'<','<=','>','>=','==','~='}))
                    % Binary relational operator
                    % Relational operators only have two operands, we don't
                    % need to worry about the number of inputs.
                    assert(length(subexprs) == 2)
                    
                    % Create a relational operator block
                    addedBlock = addRelationalBlock(op, sys);
                else
                    % Binary logical operator 
                    % Simulink can use these operators with n > 1 inputs
                    assert(length(output_ports) > 1)
                    
                    % Create a logic block
                    if strcmp(op,'&')
                        opType = 'AND';
                    elseif strcmp(op,'|')
                        opType = 'OR';
                    else
                        error('Unexpected binary logical operator detected. Expected ''&'' or ''|''')
                    end
                    addedBlock = addLogicalBlock(opType, sys, 'Inputs', num2str(length(output_ports)));
                end
                
                % Connect the outputs from the created subexpressions to
                % the new block.
                % Furture work: Order the connections alphabetically by
                % name of the source block - this is partially arbitrary,
                % but may improve the ordering of connections in some
                % cases. Also consider using some other heuristic.

                ports = get_param(addedBlock, 'PortHandles');
                connectDsts = ports.Inport;
                
                assert(length(output_ports) == length(connectDsts))
                for j = 1:length(connectDsts)
                    connectPorts(sys, output_ports{j}, connectDsts(j));
                end

                % Set connectSrc to the output of the new block.
                assert(length(ports.Outport) == 1, 'Error: Block expected to have 1 output.')
                connectSrc = ports.Outport(1);
            end
        end
    end
end

function newsubexprs = expand2nAry(subexprs, op)
    % If either subexpr has the same last op then op can be used with an
    % extra input.
    
    newsubexprs = {};
    for i = 1:length(subexprs)
        subexprs{i} = removeOuterBrackets(subexprs{i});
        [opIdx1, opIdx2] = findLastOp(subexprs{i}, 'alt');
        if opIdx1 ~= 0 ...
                && strcmp(op,subexprs{i}(opIdx1:opIdx2)) % strcmp(op, subop)
            newexprs = findNextSubexpressions(subexprs{i});
            assert(length(newexprs) == 2)
            newsubexprs = [newsubexprs, newexprs];
        else
            newsubexprs = [newsubexprs, subexprs(i)];
        end
    end
end

function newExpr = removeOuterBrackets(expr)
    
    newExpr = expr;
    
    %% Remove brackets surrounding the whole expression
    flag = true;
    while flag
        flag = false;
        if strcmp(newExpr(1), '(') && findMatchingParen(newExpr,1) == length(newExpr)
            % Remove brackets surrounding the whole expression
            newExpr = newExpr(2:end-1);
            
            % Set flag to true; continue looping until brackets no longer
            % surround the whole expression.
            flag = true;
        end
    end
end