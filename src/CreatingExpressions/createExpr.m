function connectSrcs = createExpr(lhs, exprs, startSys, createIn, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule)
% CREATEEXPR Create an expression and all of the subexpressions that go
%   into it.
%
%   Inputs:
%       lhs             LHS of an expression in exprs.
%       exprs           Cell array of expressions.
%       startSys        System from which the original blocks come from.
%       createIn        System to work in when creating the blocks.
%       s_lhsTable      Map from block/port handle in the original system
%                       to lhs in exprs and vice versa. (2-way map)
%       e_lhs2handle    Map from lhs in exprs to block/port handle in the 
%                       final system. (1-way map)
%       s2e_blockHandles    Map of block handles from the start system to the
%                           end system.
%
%   Output:
%       connectSrcs     If blackbox: A list of the outports of the expression's
%                       LHS. Else: Single outport from the generated expression.

%% Set up
% just getting some values that will be useful
[lefts, ~] = getAllLhsRhs(exprs);
idx = find(strcmp(lhs, lefts));
assert(length(idx) == 1, 'Error: Expected LHS to match 1 expression.')
expr = exprs{idx};
s_h = s_lhsTable.lookdown(lhs);
s_blk = getBlock(s_h);

[~, rhs] = getExpressionLhsRhs(expr);

%% Create the expressions
% If blackbox: essentially make the block and connect the inputs (call this
%   function recursively to get the inputs)
% Else: create a logical expression and then connect the inputs (call this
%   function recursively to get the inputs)
if isBlackBoxExpression(expr)
    
    %% Create block if needed
    if ~e_lhs2handle.isKey(lhs)
        s_bh = get_param(s_blk, 'Handle');
        if ~s2e_blockHandles.isKey(s_bh)
            if strcmp(get_param(s_blk, 'BlockType'), 'Inport') && ~strcmp(createIn, bdroot(createIn))
                inports = find_system(createIn, 'SearchDepth', '1', 'BlockType', 'Inport');
                pNums = cellfun(@(x) get_param(x, 'Port'), inports);
                s_pNum = get_param(s_blk, 'Port');
                index = find(arrayfun(@(x) strcmp(x, s_pNum), pNums));
                
                e_blk = inports{index};
                e_bh = get_param(e_blk, 'Handle');
            else
                [e_bh, e_blk] = createBlockCopy(s_blk, startSys, createIn, s2e_blockHandles);
            end
            
            if strcmp(get_param(e_blk,'BlockType'), 'SubSystem') && strcmp(get_param(e_blk,'Mask'), 'off') && ...
                    ~strcmp(subsystem_rule, 'blackbox') && ~strcmp(subsystem_rule, 'full-simplify')
                % For blackbox subsystems we can't just copy because we'll be
                % generating the contents
                
                s_outBlock = subport2inoutblock(s_h);
                srcHandle = get_param(s_outBlock, 'Handle');
                
                if s_lhsTable.lookup.isKey(srcHandle)
                    % Delete contents of SubSystem excluding inports and outports
                    copiedSubBlocks = find_system(e_blk, 'SearchDepth', '1');
                    copiedSubBlocks = copiedSubBlocks(2:end);
                    
                    for i = length(copiedSubBlocks):-1:1
                        if any(strcmp(get_param(copiedSubBlocks(i), 'BlockType'), {'Outport', 'Inport'}))
                            copiedSubBlocks(i) = []; % Remove in/outport from list
                        end
                    end
                    
                    delete_block(copiedSubBlocks)
                    copiedSubLines = find_system(e_blk, 'SearchDepth', '1', 'FindAll', 'On', 'Type', 'line');
                    delete_line(copiedSubLines)
                end
            end
        else
           % block already created
           e_bh = s2e_blockHandles(s_bh);
           e_blk = getfullname(e_bh);
        end
        
        % Record that lhs has been added
        switch expressionType(s_h)
            case 'out'
                oPorts = getPorts(e_blk, 'Outport');
                pNum = getExprPortNumber(expr, s_lhsTable);
                e_h = oPorts(pNum);
                e_lhs2handle(lhs) = e_h;
            case 'blk'
                e_h = e_bh;
                e_lhs2handle(lhs) = e_h;
            case 'in'
                error('Error: Something went wrong, expression type should not be ''in'' as well as blackbox.')
            otherwise
                error('Error: Unexpected eType')
        end
        
        if strcmp(get_param(e_blk,'BlockType'), 'SubSystem') && strcmp(get_param(e_blk,'Mask'), 'off') ...
                && ~strcmp(subsystem_rule, 'blackbox') && ~strcmp(subsystem_rule, 'full-simplify')
            % For blackbox subsystems woth expressions to simplify within, 
            % create the expressions for the corresponding outports at this 
            % point
            
            % Get the immediate source of the output port (i.e. the outport block within the subsystem)
            s_outBlock = subport2inoutblock(s_h);
            srcHandle = get_param(s_outBlock, 'Handle');
            
            if s_lhsTable.lookup.isKey(srcHandle)
                outLhs = s_lhsTable.lookup(srcHandle);
                connectSrcs = createExpr(outLhs, exprs, startSys, e_blk, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
                assert(length(connectSrcs) == 1, 'Error: Current expression should have only 1 outgoing connection.')

                % Don't need to create the outport since we did not to delete
                % them from the original model

                % Find the handle to connect to
                e_outBlock = subport2inoutblock(e_h);
                e_outInport = getPorts(e_outBlock, 'Inport');
                connectDst = get_param(e_outInport, 'Handle');
                
                connectPorts(e_blk, connectSrcs, connectDst);
            end
        end
        %     else
        %         e_blk = getBlock(e_lhs2handle(lhs));
        %     end
        
        %%
        % For each inport, create the corresponding expression, then connect to the
        % inport.
        rhsTokens = regexp(rhs, '([^,]*),|([^,]*)', 'tokens');
        inPorts = getPorts(e_blk, 'In');
        assert(length(rhsTokens) == length(inPorts), 'Error: Blackbox expression expected to have the same # of terms as the corresponding block has inports.')
        for j = 1:length(rhsTokens) % Note: j is also the port number of the input to s_blk
            % Find the handle to connect to
            connectDst  = inPorts(j);
            
            exprIdx = find(strcmp(rhsTokens{j}{1}, lefts));
            assert(length(exprIdx) == 1, 'Error: Expected subexpression to match the LHS of 1 expression.')
            
            if ~e_lhs2handle.isKey(rhsTokens{j}{1})
                bbSrcs = createExpr(rhsTokens{j}{1}, exprs, startSys, createIn, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
                assert(length(bbSrcs) == 1, 'Error: Current expression should have only 1 outgoing connection.')
                connectPorts(createIn, bbSrcs, connectDst);
                %         else
                %             bbSrcs = e_lhs2handle(rhsTokens{j}{1});
                %             % TODO: Probably need to create a branch
                %             error('Error: Something went wrong.')
            end % else do nothing, connections already made
            
            %         assert(length(bbSrcs) == 1, 'Error: Current expression should have only 1 outgoing connection.')
            %         connectPorts(createIn, bbSrcs, connectDst);
        end
                
        switch expressionType(s_h)
            case 'out'
                connectSrcs = e_lhs2handle(lhs);
                assert(~isempty(connectSrcs))
            case 'blk'
                % connectSrcs should be a matrix of the outputs of the blackbox
                connectSrcs = getPorts(e_blk, 'Outport');
                assert(~isempty(connectSrcs))
            case 'in'
                error('Error: Expression type should not be ''in'' as well as blackbox.')
            otherwise
                error('Error: Unexpected eType')
        end
        
    else
        e_blk = getBlock(e_lhs2handle(lhs));
        
        switch expressionType(s_h)
            case 'out'
                connectSrcs = e_lhs2handle(lhs);
                assert(~isempty(connectSrcs))
            case 'blk'
                % connectSrcs should be a matrix of the outputs of the blackbox
                connectSrcs = getPorts(e_blk, 'Outport');
                assert(~isempty(connectSrcs))
            case 'in'
                error('Error: Expression type should not be ''in'' as well as blackbox.')
            otherwise
                error('Error: Unexpected eType')
        end
    end
else
    % Expression is a logical one that we can create
    % Create blocks based on the RHS to later connect to the LHS (outside
    % of this function)
    rhs = makeWellFormed(rhs);
    connectSrcs = createLogic(rhs, exprs, startSys, createIn, 1, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
    
    assert(length(connectSrcs) > 0, 'Error: Logic expression had 0 outputs.')
    assert(length(connectSrcs) == 1, 'Error: Logic expression had more than 1 output.')
    e_lhs2handle(lhs) = connectSrcs;
end
end