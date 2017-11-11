function createExpressions(exprs, s_lhsTable, startSys, endSys)
% CREATEEXPRESSIONS Generate blocks to represent an expression.
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
%

% Note: Some variables will be prefixed with "s_" or "e_" to indicate what 
% system the variable relates to. "s_": for startSys, "e_": for endSys.

%% Init
% TODO: use e_lhsTable instead of running findsystem every time (forgot to
% do during implementation)
e_lhsTable = BiMap('double','char'); % Add the corresponding elements from s_lhsTable as they are created
[lefts, rights] = getAllLhsRhs(exprs);

%% Reorder expressions 
%   Essentially this will allow blocks to be connected where they need to be 
%   when the expressions are created.

% TODO figure out best way to reorder
% postSimpleExprs = reorderExpressions(startSys, exprs, lhsTable); -- old method, might still be fine

% TODO consider alternate approach (if others don't work)
% Find expressions with no dependencies, build those, then build ones which
% only depend on it, ...
%
% exprDeps = getExprDependencies(exprs);
% noDepsMat = zeros(1,length(exprDeps));
% for i = 1:length(exprDeps)
%     noDepsMat(i) = ~isempty(exprDeps{i,2});
% end

% TODO: alternate approach (currently preferred approach):
% Find expressions which are independ
% Find expressions with no dependencies, create them and recursively create
% the expressions that depend on them
% Watch out for loops
depMat = getExprDepMat(exprs);
notDepByMat = zeros(1,size(depMat,1)); % notDepBy: not depended on by anything
for i = 1:size(depMat,1)
    notDepByMat(i) = ~any(depMat(:,i));
end

%% Generate Expressions
% TODO - account for loops / subsystems / other things that aren't handled yet / at all by this method
%
% TODO fix this to account for current implementation
% for each unused expr
%   createL(LHS(expr_i))
%   createR(RHS(expr_i))
%   connect(LHS,RHS)
for i = find(notDepByMat) % When notDepByMat is 1
    %% Get info about the expression
    expr = exprs{i};

    lhs = lefts{i};
    rhs = rights{i};

    s_h = s_lhsTable.lookdown(lhs); % Expression handle
    s_blk = getBlock(s_h); % Block corresponding to the handle (i.e. parent of port else same as handle)
    bType = get_param(s_blk, 'BlockType');

    %% Figure out in which (sub)system to generate the expression
    % TODO
    createIn = endSys; % Temp: assume no subsystems being kept
    
    %%
    connectSrcs = createExpr(lhs, exprs, startSys, createIn, s_lhsTable);
    
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
            connectPorts(createIn, connectSrcs(j), connectDst)
        end
    else
        % TODO make a function to return this so that it's easier to
        % change/find later if needed
        supportedStartBlocks = {'Outport','DataStoreWrite','Goto'};
        
        % Get connectDst
        if any(strcmp(bType,supportedStartBlocks))
            e_blk = regexprep(s_blk,['^' startSys], createIn, 'ONCE'); % Name of the block in endSys
            if isempty(find_system(createIn, 'Name', get_param(s_blk, 'Name'))) % block not made yet
                % Create block
                e_bh = add_block(s_blk, e_blk);
            else
                e_bh = get_param(e_blk, 'Handle');
            end
            % Find the handle to connect to 
            ph = get_param(e_bh, 'PortHandles');
            assert(length(ph.Inport) == 1, 'Error: Block expected to have 1 input port.')
            connectDst = ph.Inport(1);
        else
            % Create Terminator
            term_h = add_block('built-in/Terminator', [createIn '/gen_' 'Terminator'], 'MAKENAMEUNIQUE', 'ON');
            % Get Terminator input port
            ph = get_param(term_h, 'PortHandles');
            assert(length(ph.Inport) == 1, 'Error: Terminator expected to have 1 input port.')
            connectDst = ph.Inport(1);
        end
        
        % Connect RHS to LHS
        assert(length(connectSrcs) == 1, 'Error: Non-blackbox expression expected to just have one outgoing port.')
        connectPorts(createIn, connectSrcs, connectDst)
    end
end
end