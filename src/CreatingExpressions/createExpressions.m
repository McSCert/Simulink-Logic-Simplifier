function createExpressions(exprs, s_lhsTable, startSys, endSys, subsystem_rule)
% CREATEEXPRESSIONS Generate blocks to represent a set of expressions.
%
%   Inputs:
%       exprs       Cell array of expressions (strings) to generate.
%       s_lhsTable  A BiMap (2-way containers.Map()) linking identifiers in
%                   expr to blocks in startSys.
%                   lhsTable.lookup(blockHandle) -> expression_identifier
%                   lhsTable.lookdown(expression_identifier) -> blockHandle
%       startSys    System from which blocks in lhsTable can be found (the 
%                   expression should have been made from analysis of this 
%                   system).
%       endSys      System in which to create the expressions.
%       subsystem_rule  Rule about how to treat subsystems, see the logic
%                       simplifier config file for details.
%

% Note: Some variables will be prefixed with "s_" or "e_" to indicate what 
% system the variable relates to. "s_": for startSys, "e_": for endSys.

%% Initializations

% e_lhs2handle: For the LHS of an expression, gives the associated handle
%   in the final system. If the expression hasn't been generated yet, then
%   the LHS will not be a key.
e_lhs2handle = containers.Map('KeyType', 'char', 'ValueType', 'double');

% s2e_blockHandles: Mapping block handles between start and end system (only
%   add an item if it gets copied into the end system (endSys).
s2e_blockHandles = containers.Map('KeyType', 'double', 'ValueType', 'double');

% lefts: List of LHS's in exprs
% rights: List of RHS's in exprs
[lefts, rights] = getAllLhsRhs(exprs);

%% Find the 'right-most' expressions
%   By this we mean expressions which are not depended on. Expressions
%   which are not depended on will correspond with blocks further in the
%   data flow of the Simulink diagram. Thus these expressions are
%   'right-most' assuming the Simulink diagram has left-to-right flow.
%
% TODO: Account for loops in the Simulink diagram
% TODO: Check if need to account for expressions within subsystems
%
% Old approach was able to simply reorder expressions to be made in a
% suitable order, however this approach was less intuitive and was not easy
% to maintain during certain code modifications
depMat = getExprDepMat(exprs);
notDepByMat = zeros(1,size(depMat,1)); % notDepBy: not depended on by anything
for i = 1:size(depMat,1)
    notDepByMat(i) = ~any(depMat(:,i));
end

%% Generate Expressions
% TODO - account for loops / subsystems / other things that aren't handled yet / at all by this method
% TODO - Describe what's going on in the for loop overall
for i = find(notDepByMat) % When notDepByMat is 1
    %% Get info about the expression
    expr = exprs{i};

    lhs = lefts{i};
    rhs = rights{i};

    s_h = s_lhsTable.lookdown(lhs); % Expression handle
    s_blk = getBlock(s_h); % Block corresponding to the handle (i.e. parent of port else same as handle)
    bType = get_param(s_blk, 'BlockType');

    %% Figure out in which (sub)system to generate the expression
    if any(strcmp(subsystem_rule, {'blackbox', 'part-simplify'}))
        % Create expression in the (sub)system it comes from, but in the
        % new model
        createIn = regexprep(get_param(s_blk, 'Parent'),['^' startSys], endSys, 'ONCE');
    elseif strcmp(subsystem_rule, 'full-simplify')
        % Create expression at the highest level (subsystems will be 
        % 'flattened')
        createIn = endSys;
    else
        error('Error, invalid subsystem_rule')
    end
    
    %%
    if strcmp(bType, 'ActionPort') && strcmp(subsystem_rule, 'full-simplify')
        % Expression isn't desired; skip
        continue
    elseif ~strcmp(createIn, endSys)
        % Expression will be handled through other iterations of this loop via
        % the recursive nature of createExpr; skip
        continue
    end
    
    %%
    connectSrcs = createExpr(lhs, exprs, startSys, createIn, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
    
    if isBlackBoxExpression(expr)
        % Note: The corresponding block would have been made in createExpr
        
        for j = 1:length(connectSrcs)
            % Create Terminator
            term_h = add_block('built-in/Terminator', [createIn '/gen_' 'Terminator'], 'MAKENAMEUNIQUE', 'ON');
            % Get Terminator input port
            ph = get_param(term_h, 'PortHandles');
            assert(length(ph.Inport) == 1, 'Error: Terminator expected to have 1 input port.')
            connectDst = ph.Inport(1);
            % Connect the blackbox to the Terminator
            connectPorts(createIn, connectSrcs(j), connectDst);
        end
    else
        % TODO make a function to return these supported blocks so that it's
        % easier to change/find later if needed
        supportedStartBlocks = {'Outport','DataStoreWrite','Goto'};
        
        %% Get connectDst & Create block for the lhs if needed
        if any(strcmp(bType,supportedStartBlocks))
            e_blk = [createIn '/' get_param(s_blk, 'Name')]; % Default name of the block to put in endSys
            
            % Create block
            e_bh = add_block(s_blk, e_blk, 'MakeNameUnique', 'On');
            e_blk = getfullname(e_bh);
        else
            % I don't think this can ever happen so I'm just going to
            % leave the error here to check for now
            error('Error: Unexpected case.')
            
            % Create Terminator
            e_bh = add_block('built-in/Terminator', [createIn '/gen_' 'Terminator'], 'MAKENAMEUNIQUE', 'ON');
            e_blk = getfullname(e_bh);
        end
        
%         %% Get connectDst & Create block for the lhs if needed
%         % This uses similar code to some used in createExpr
%         % In this case, expressionType(s_h) will probably be guaranteed to
%         % be 'blk', but this assumption wasn't made below
%         if ~e_lhs2handle.isKey(lhs)
%             s_bh = get_param(s_blk, 'Handle');
%             if ~s2e_blockHandles.isKey(s_bh)
%                 if any(strcmp(bType,supportedStartBlocks))
%                     [e_bh, e_blk] = createBlockCopy(s_blk, startSys, createIn, s2e_blockHandles);
%                 else
%                     % I don't think this can ever happen so I'm just going to
%                     % leave the error here to check for now
%                     error('Error: Unexpected case.')
%                     
%                     % Create Terminator
%                     e_bh = add_block('built-in/Terminator', [createIn '/gen_' 'Terminator'], 'MAKENAMEUNIQUE', 'ON');
%                     e_blk = getfullname(e_bh);
%                     s2e_blockHandles(s_bh) = e_bh;
%                 end
%             else
%                 % block already created
%                 e_bh = s2e_blockHandles(s_bh);
%                 e_blk = getfullname(e_bh);
%             end
%             
%             % Record that lhs has been added
%             switch expressionType(s_h)
%                 case 'out'
%                     error('Error: Something went wrong, if expression type is ''out'', then it should depend on another expression.')
%                 case 'blk'
%                     e_h = e_bh;
%                     e_lhs2handle(lhs) = e_h;
%                 case 'in'
%                     error('Error: Something went wrong, if expression type is ''in'', then it should depend on another expression.')
%                 otherwise
%                     error('Error: Unexpected eType')
%             end
%         else
%             e_blk = getBlock(e_lhs2handle(lhs));
%         end
        
        % Find the handle to connect to
        ph = get_param(e_blk, 'PortHandles');
        assert(length(ph.Inport) == 1, 'Error: Block expected to have 1 input port.')
        connectDst = ph.Inport(1);
        
        %% Connect RHS to LHS
        assert(length(connectSrcs) == 1, 'Error: Non-blackbox expression expected to just have one outgoing port.')
        connectPorts(createIn, connectSrcs, connectDst);
    end
end

%% Fix port numbers - they weren't added in a particular order so the 

% s_inports = find_system(startSys, 'SearchDepth', '1', 'BlockType', 'Inport');
e_inports = find_system(endSys, 'SearchDepth', '1', 'BlockType', 'Inport');
% assert(length(s_inports) == length(e_inports), 'Error: Expected same number of inports in the resulting system as the starting system.')
for i = 1:length(e_inports)
    name = get_param(e_inports{i}, 'Name');
    s_inport = find_system(startSys, 'SearchDepth', '1', 'BlockType', 'Inport', 'Name', name);
    assert(length(s_inport) == 1, 'Error: All inports in the resulting system should have a match in the starting system.')
    pNum = get_param(s_inport{1}, 'Port');
    set_param(e_inports{i}, 'Port', num2str(pNum));
end
% s_outports = find_system(startSys, 'SearchDepth', '1', 'BlockType', 'Outport');
e_outports = find_system(endSys, 'SearchDepth', '1', 'BlockType', 'Outport');
% assert(length(s_outports) == length(e_outports), 'Error: Expected same number of outports in the resulting system as the starting system.')
for i = 1:length(e_outports)
    name = get_param(e_outports{i}, 'Name');
    s_outport = find_system(startSys, 'SearchDepth', '1', 'BlockType', 'Outport', 'Name', name);
    assert(length(s_outport) == 1, 'Error: All outports in the resulting system should have a match in the starting system.')
    pNum = get_param(s_outport{1}, 'Port');
    set_param(e_outports{i}, 'Port', num2str(pNum));
end
end