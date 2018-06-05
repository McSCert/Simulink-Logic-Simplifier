function createEquations(equs, s_lhsTable, startSys, endSys, subsystem_rule)
% CREATEEQUATIONS Generate blocks to represent a set of equations.
%
%   Inputs:
%       equs        Cell array of equations (strings) to generate.
%       s_lhsTable  A BiMap (2-way containers.Map()) linking identifiers in
%                   equs to blocks in startSys.
%                   lhsTable.lookup(blockHandle) -> <equation_identifier>
%                   lhsTable.lookdown(<equation_identifier>) -> blockHandle
%       startSys    System from which blocks in lhsTable can be found (the 
%                   equation should have been made from analysis of this 
%                   system).
%       endSys      System in which to create the representations of the
%                   equations.
%       subsystem_rule  Rule about how to treat subsystems, see the logic
%                       simplifier config file for details.
%

% Note: Some variables will be prefixed with "s_" or "e_" to indicate what 
% system the variable relates to. "s_": for startSys, "e_": for endSys.

%% Initializations

% e_lhs2handle: For the LHS of an equation, gives the associated handle
%   in the final system. If the equation hasn't been generated yet, then
%   the LHS will not be a key.
e_lhs2handle = containers.Map('KeyType', 'char', 'ValueType', 'double');

% s2e_blockHandles: Mapping block handles between start and end system (only
%   add an item if it gets copied into the end system (endSys).
s2e_blockHandles = containers.Map('KeyType', 'double', 'ValueType', 'double');

% lefts: List of LHS's in equs
% rights: List of RHS's in equs
[lefts, rights] = getAllLhsRhs(equs);

%% Find the 'right-most' equations
%   By this we mean equations which are not depended on. equations
%   which are not depended on will correspond with blocks further in the
%   data flow of the Simulink diagram. Thus these equations are
%   'right-most' assuming the Simulink diagram has left-to-right flow.
%
% TODO: Account for loops in the Simulink diagram
% TODO: Check if need to account for equations within subsystems
%
% Old approach was able to simply reorder equations to be made in a
% suitable order, however this approach was less intuitive and was not easy
% to maintain during certain code modifications
depMat = getEquDepMat(equs);
notDepByMat = zeros(1,size(depMat,1)); % notDepBy: not depended on by anything
for i = 1:size(depMat,1)
    notDepByMat(i) = ~any(depMat(:,i));
end

%% Generate equations
% TODO - account for loops / subsystems / other things that aren't handled yet / at all by this method
% TODO - Describe what's going on in the for loop overall
%   -For each 'right-most' equation, create blocks to represent the rhs,
%   then create the block on the lhs and connect the parts
%   
for i = find(notDepByMat) % When notDepByMat is 1
    %% Get info about the equation
    equ = equs{i};

    lhs = lefts{i};
    %rhs = rights{i};

    s_h = s_lhsTable.lookdown(lhs); % Equation handle
    s_blk = getBlock(s_h); % Block corresponding to the handle (i.e. parent of port else same as handle)
    bType = get_param(s_blk, 'BlockType');

    %% Figure out in which (sub)system to generate the equation
    if any(strcmp(subsystem_rule, {'blackbox', 'part-simplify'}))
        % Create equation in the (sub)system it comes from, but in the
        % new model
        createIn = regexprep(get_param(s_blk, 'Parent'),['^' startSys], endSys, 'ONCE');
    elseif strcmp(subsystem_rule, 'full-simplify')
        % Create equation at the highest level (subsystems will be 
        % 'flattened')
        createIn = endSys;
    else
        error('Error, invalid subsystem_rule')
    end
    
    %%
    if strcmp(bType, 'ActionPort') && strcmp(subsystem_rule, 'full-simplify')
        % Equation isn't desired; skip
        continue
    elseif ~strcmp(createIn, endSys)
        % Equation will be handled through other iterations of this loop via
        % the recursive nature of createRhs; skip
        continue
    end
    
    %%
    if isBlackBoxEquation(equ)
        %%
        % Note: The block for the lhs will be made in createRhs because of
        % the way it treats blackboxes
        
        %% Create blocks for the rhs
        createRhs(lhs, equs, startSys, createIn, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
    elseif any(strcmp(bType, {'Outport','DataStoreWrite','Goto'}))
        %% Get connectDst & create block for the lhs
        [~, e_blk] = createBlockCopy(s_blk, startSys, createIn, s2e_blockHandles);
        
        % Find the handle to connect to
        ph = get_param(e_blk, 'PortHandles');
        assert(length(ph.Inport) == 1, 'Error: Block expected to have 1 input port.')
        connectDst = ph.Inport(1);
        
        %% Get connectSrc and create blocks for the rhs
        connectSrc = createRhs(lhs, equs, startSys, createIn, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
        assert(length(connectSrc) == 1, 'Error: Non-blackbox equation expected to have 1 outgoing port.')
        
        %% Connect RHS to LHS
        connectPorts(createIn, connectSrc, connectDst);
    else
        % I don't think this can ever happen so I'm just going to
        % leave the error here to check for now
        error('Error: Unexpected case.')
        
        %% Get connectSrc and create blocks for the rhs
        createRhs(lhs, equs, startSys, createIn, s_lhsTable, e_lhs2handle, s2e_blockHandles, subsystem_rule);
    end
end

%% Fix port numbers 
%   Inports and Outports weren't added in a particular order so they were 
%   automatically given port numbers different from what they were in the 
%   original system so they need to be corrected

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