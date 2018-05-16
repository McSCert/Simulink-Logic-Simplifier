function connectSrcs = createRhs(lhs, equs, startSys, createIn, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule)
    % CREATERHS Generate blocks to represent the rhs of an equation (if
    %   it's not blackbox, then the rhs is an expression, otherwise rhs is
    %   a list of lhs identifiers). While the primary role here is to
    %   handle the rhs of an equation, the lhs will be relevant for
    %   blackbox equations.
    %
    %   Inputs:
    %       lhs             LHS of an equation in equs.
    %       equs           Cell array of expressions.
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
    [lefts, ~] = getAllLhsRhs(equs);
    idx = find(strcmp(lhs, lefts));
    assert(length(idx) == 1, 'Error: Expected LHS to match 1 expression.')
    equ = equs{idx};
    s_h = s_lhsTable.lookdown(lhs);
    s_blk = getBlock(s_h);
    
    [~, rhs] = getEquationLhsRhs(equ);
    
    %% Create the rhs
    % If blackbox: essentially create the block corresponding to the lhs
    %   and connect the inputs indicated in rhs to it (call this function
    %   recursively to get the inputs)
    % Else: create a logical expression
    if isBlackBoxEquation(equ)
        
        %% Create lhs block then inputs indicated in rhs
        if ~e_lhs2handle.isKey(lhs)
            
            %% Create lhs block or find it in the new system
            % Set e_bh and e_blk (block handle and name in the new system)
            s_bh = get_param(s_blk, 'Handle');
            if ~s2e_blockHandles.isKey(s_bh)
                if strcmp(get_param(s_blk, 'BlockType'), 'Inport') && ~strcmp(createIn, bdroot(createIn))
                    % Block was created with the subsystem so just get e_bh
                    % and e_blk
                    inports = find_system(createIn, 'SearchDepth', '1', 'BlockType', 'Inport');
                    pNums = cellfun(@(x) get_param(x, 'Port'), inports);
                    s_pNum = get_param(s_blk, 'Port');
                    index = find(arrayfun(@(x) strcmp(x, s_pNum), pNums));
                    
                    e_blk = inports{index};
                    e_bh = get_param(e_blk, 'Handle');
                else
                    assert(~strcmp(get_param(s_blk, 'BlockType'), 'Outport') && ~strcmp(createIn, bdroot(createIn)), 'Outport blocks should have been handled in the same iteration as their parent subsystem.')
                    [e_bh, e_blk] = createBlockCopy(s_blk, startSys, createIn, s2e_blockHandles);
                end
                
                if strcmp(get_param(e_blk,'BlockType'), 'SubSystem') && strcmp(get_param(e_blk,'Mask'), 'off') && ...
                        ~strcmp(subsystem_rule, 'blackbox') && ~strcmp(subsystem_rule, 'full-simplify')
                    % For blackbox subsystems we can't just copy because
                    % we'll be generating the contents still
                    
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
            
            %% Update e_lhs2handle
            % Record that lhs has been added to the new system (by adding
            % it to e_lhs2handle)
            switch equationType(s_h)
                case 'out'
                    oPorts = getPorts(e_blk, 'Outport');
                    pNum = getEquPortNumber(equ, s_lhsTable);
                    e_h = oPorts(pNum);
                    e_lhs2handle(lhs) = e_h;
                case 'blk'
                    e_h = e_bh;
                    e_lhs2handle(lhs) = e_h;
                case 'in'
                    error('Error: Something went wrong, equation type should not be ''in'' when equation is blackbox.')
                otherwise
                    error('Error: Unexpected eType')
            end
            
            %% 
            if strcmp(get_param(e_blk,'BlockType'), 'SubSystem') && strcmp(get_param(e_blk,'Mask'), 'off') ...
                    && ~strcmp(subsystem_rule, 'blackbox') && ~strcmp(subsystem_rule, 'full-simplify')
                % For blackbox subsystems with expressions to simplify within,
                % create the expressions for the corresponding outport at this
                % point
                
                % Get the immediate source of the output port (i.e. the
                % outport block within the subsystem)
                s_outBlock = subport2inoutblock(s_h);
                srcHandle = get_param(s_outBlock, 'Handle');
                
                if s_lhsTable.lookup.isKey(srcHandle)
                    outLhs = s_lhsTable.lookup(srcHandle);
                    outSrc = createRhs(outLhs, equs, startSys, e_blk, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
                    assert(length(outSrc) == 1, 'Error: Current equation should have only 1 outgoing connection.')
                    
                    % Don't need to create the outport since we did not
                    % delete them from the original model
                    
                    % Find the handle to connect to
                    e_outBlock = subport2inoutblock(e_h);
                    e_outInport = getPorts(e_outBlock, 'Inport');
                    connectDst = get_param(e_outInport, 'Handle');
                    
                    connectPorts(e_blk, outSrc, connectDst);
                end
            end
            
            %%
            % For each inport indicated in rhs, create the corresponding
            % equation, then connect to the inport.
            rhsTokens = regexp(rhs, '([^,]*),|([^,]*)', 'tokens');
            inPorts = getPorts(e_blk, 'In');
            assert(length(rhsTokens) == length(inPorts), 'Error: Blackbox expression expected to have the same # of terms as the corresponding block has inports.')
            for j = 1:length(rhsTokens) % Note: j is also the port number of the input to s_blk
                % Find the handle to connect to
                connectDst = inPorts(j);
                
                exprIdx = find(strcmp(rhsTokens{j}{1}, lefts));
                assert(length(exprIdx) == 1, 'Error: Expected subexpression to match the LHS of 1 expression.')
                
                if ~e_lhs2handle.isKey(rhsTokens{j}{1})
                    bbSrcs = createRhs(rhsTokens{j}{1}, equs, startSys, createIn, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
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
            
            switch equationType(s_h)
                case 'out'
                    connectSrcs = e_lhs2handle(lhs);
                    assert(~isempty(connectSrcs))
                case 'blk'
                    % connectSrcs should be a matrix of the outputs of the blackbox
                    connectSrcs = getPorts(e_blk, 'Outport');
                case 'in'
                    error('Error: Expression type should not be ''in'' as well as blackbox.')
                otherwise
                    error('Error: Unexpected eType')
            end
            
        else
            e_blk = getBlock(e_lhs2handle(lhs));
            
            switch equationType(s_h)
                case 'out'
                    connectSrcs = e_lhs2handle(lhs);
                    assert(~isempty(connectSrcs))
                case 'blk'
                    % connectSrcs should be a matrix of the outputs of the blackbox
                    connectSrcs = getPorts(e_blk, 'Outport');
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
        connectSrcs = createExpression(rhs, equs, startSys, createIn, 1, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
        
        assert(length(connectSrcs) > 0, 'Error: Logic expression had 0 outputs.')
        assert(length(connectSrcs) == 1, 'Error: Logic expression had more than 1 output.')
        e_lhs2handle(lhs) = connectSrcs;
    end
end