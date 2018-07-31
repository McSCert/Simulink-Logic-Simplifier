function [finalEqus, baseEqus] = doSimplification(sys, blocks, varargin)
% DOSIMPLIFICATION Performs simplification on the input blocks.
%
%   Inputs:
%       sys         Handle of empty system to place the simplified blocks in.
%       blocks      List of blocks to perform simplification on.
%       varargin    See "Initializations" in the code
%
%   Outputs:
%       baseEqus   Equations extracted from blocks for simplification.
%       finalEqus  Equations generated by simplifying the starting
%                   equations to use to build a simpler model.

%% Initializations
subsystem_rule = 'blackbox'; % Default
extraSupportFun = @defaultExtraSupport;
generate_mode = 'All';
blocks_to_simplify = 'selected';
assert(mod(length(varargin),2) == 0, 'Even number of varargin arguments expected.')
for i = 1:2:length(varargin)
    param = varargin{i};
    value = varargin{i+1};
    
    switch param
        case 'subsystem_rule'
            subsystem_rule = value;
        case 'extra_support_function'
            assert(exist(value, 'file') == 2, ...
                'Error: extra_support_function in the config is expected to be a file on the MATLAB path.')
            extraSupportFun = eval(['@' value]);
        case 'generate_mode'
            assert(any(strcmpi(value, {'SimplifiedOnly', 'All'})), ...
                'Unexpected parameter value.')
            generate_mode = value;
        case 'blocks_to_simplify'
            assert(any(strcmpi(value, {'Selected', 'Unselected'})), ...
                'Unexpected parameter value.')
            blocks_to_simplify = value;
        otherwise
            error(['Error in ' mfilename ' unexpected Name for Name-Value pair input argument.'])
    end
end

endSys = getfullname(sys);
assert(all(strcmp(get_param(blocks{1}, 'Parent'), get_param(blocks,'Parent'))), ['Error in ' mfilename ', all blocks must be in the same system.'])
startSys = get_param(blocks{1}, 'Parent');

% Keep a list of blocks/ports that we have equations for
%   Note: handles are 'lookup' keys, and string identifiers are 'lookdown' keys
lhsTable = BiMap('double','char');

%% Get block lists
% blocks - blocks to simplify 
% sysBlocks - blocks to simplify and blocks to simplify around

topSysBlocks = find_system(startSys, 'SearchDepth', '1');
topSysBlocks = topSysBlocks(2:end); % Remove startSys

% Get block list including blocks from the top-level and ones from nested
% levels depending on the subsystem_rule parameter.
sysBlocks = topSysBlocks;
if strcmp(blocks_to_simplify, 'selected')
    % Do nothing
elseif strcmp(blocks_to_simplify, 'unselected')
    blocks = setdiff(topSysBlocks, blocks);
else
    error('Error, invalid blocks_to_simplify')
end
if strcmp(subsystem_rule, 'full-simplify') || strcmp(subsystem_rule, 'part-simplify')
    % All blocks in subsystems of blocks should be included as blocks to
    % simplify
    
    tmpBlocks = blocks; % use temp variable so indices aren't messed up
    for i = 1:length(blocks) 
        % Note this loop uses blocks not sysBlocks, we want sysBlocks to involve
        % all blocks in any subsystem being modified, we only want to
        % modify subsystems in blocks.
        if strcmp(get_param(blocks{i}, 'BlockType'), 'SubSystem') ...
                && strcmp(get_param(blocks{i}, 'Mask'), 'off')
            subBlocks = find_system(blocks{i});
            assert(~isempty(subBlocks),'Temporary assertion for debugging.') % TODO remove this
            sysBlocks = union(sysBlocks, subBlocks);
            tmpBlocks = union(tmpBlocks, subBlocks);
        end
    end
    blocks = tmpBlocks;
elseif strcmp(subsystem_rule, 'blackbox')
    % No changes needed. We aren't simplifying within subsystems.
else
    error('Error, invalid subsystem_rule')
end

%% Get starting equations
%   Expected form: 'handleID = expr' or 'handleID =? expr'
%   'handleID' is a char used to identify a Simulink object
%   '=?' indicates the equation is blackbox; only the interface is known
%   expr is an expression using {<,<=,>,>=,==,~=,&,|}
baseEqus = getEqusForBlocks(startSys, blocks, sysBlocks, lhsTable, subsystem_rule, extraSupportFun);

%% Substitute equations
%   Substitute to get rid of extranneous equations before simplification
preSimpleEqus = substituteEqus(baseEqus, blocks, lhsTable, subsystem_rule);

%% Simplify expressions
postSimpleEqus = cell(1,length(preSimpleEqus));
for i = 1:length(preSimpleEqus)
    if ~isBlackBoxEquation(preSimpleEqus{i})
        [lhs, rhs] = getEquationLhsRhs(preSimpleEqus{i});
        
        % TODO
        %Swap Chrysler's CbTRUE for symengine's TRUE
%         rhs = strrep(rhs, 'CbTRUE', 'TRUE');
%         rhs = strrep(rhs, 'CbFALSE', 'FALSE');
        
        %Do the simplification
        simpleRhs = simplifyExpression(rhs);
        
        %Strip whitespace
        simpleRhs = regexprep(simpleRhs, '\s', '');
        postSimpleEqus{i} = [lhs, ' = ', simpleRhs];
    else
        postSimpleEqus{i} = preSimpleEqus{i};
    end
end

%% Create blocks for each equation
s2e_blockHandles = createEquations(postSimpleEqus, lhsTable, startSys, endSys, subsystem_rule);

swapBlockPattern(endSys, extraSupportFun);

if strcmpi(generate_mode, 'simplifiedonly')
    unselectedBlocks = setdiff(topSysBlocks,blocks);
    unselectedBlocksHdls = get_param(unselectedBlocks,'Handle');
    for i = 1:length(unselectedBlocksHdls)
        % For all blocks that weren't selected at top-level
        
        % Search for a corresponding end block
        if s2e_blockHandles.isKey(unselectedBlocksHdls{i})
            e_handle = s2e_blockHandles(unselectedBlocksHdls{i});
            
            % Delete block and its lines
            delete_block_lines(e_handle)
            delete_block(e_handle)
        end
    end
elseif ~strcmpi(generate_mode, 'All')
    error('Unexpected parameter value.')
end

RemoveSimulinkDuplicates(blocks, 'DeleteDuplicateBlocks', 'on');

branchingImplicit2multipleImplicit(endSys);

finalEqus = postSimpleEqus;

%%
% sysName = endSys
% origSys = startSys
% predicates = lhsTable
% tempExpressions = baseExprs
% startingExpressions = preSimpleExprs
% endingExpressions = postSimpleExprs
% 
% % Reorder so that blocks can be connected where they need to be when the expressions are created.
% endingExpressions = reorderExpressions(origSys, endingExpressions, predicates);
% 
% expressionsToGenerate = endingExpressions;
% if strcmp(SUBSYSTEM_RULE, 'blackbox')
%     % Remove expressions for SubSystems so that we don't try to produce their contents.
%     for i = length(expressionsToGenerate):-1:1
%         [lhs, ~] = getExpressionLhsRhs(expressionsToGenerate{i});
%         handle = getKeyFromVal(predicates, lhs);
%         
%         handleType = get_param(handle,'Type');
% 
%         % Get the block
%         if strcmp(handleType, 'block')
%             block = getfullname(handle);
%         elseif strcmp(handleType, 'port')
%             block = get_param(handle, 'Parent');
%         end
%         blockType = get_param(block, 'BlockType');
%         
%         if strcmp(blockType, 'SubSystem')
%             expressionsToGenerate(i) = [];
%         end
%     end
% end
% 
% atomics = containers.Map();
% 
% % Create top-level Inports
% atomics = copySystemInports(origSys, sysName, atomics, predicates);
% 
% % Create needed SubSystems and the Inports within them.
% if strcmp(SUBSYSTEM_RULE, 'blackbox')
%     % Simply duplicate SubSystems at top-level
%     atomics = copySystemSubSystems(origSys, sysName, atomics, predicates);
% else
%     for i = 1:length(endingExpressions) % <- loop on endingExpressions where SubSystems have not been removed
%         [lhs, ~] = getExpressionLhsRhs(endingExpressions{i});
%         handle = getKeyFromVal(predicates, lhs);
%         
%         handleType = get_param(handle,'Type');
%         
%         % Get the block
%         if strcmp(handleType, 'block')
%             block = getfullname(handle);
%         elseif strcmp(handleType, 'port')
%             block = get_param(handle, 'Parent');
%         end
%         blockType = get_param(block, 'BlockType');
%         
%         % If SubSystem, create it in the new system, unless it's masked
%         % If masked SubSystem, we'll create it with the other blackboxes
%         if strcmp(blockType, 'SubSystem') && ~strcmp(get_param(block, 'Mask'), 'on')
%             newBlock = regexprep(block,['^' origSys], sysName, 'ONCE');
%             try
%                 add_block('built-in/SubSystem', newBlock);
%                 
%                 % Preserve some block parameters from the original SubSystem
%                 for param = {'ForegroundColor', 'BackgroundColor', 'ShowName', 'Orientation', 'NamePlacement'}
%                     set_param(newBlock, param{1}, get_param(block, param{1}))
%                 end
%                 
%                 % If a SubSystem block is masked, then its background color
%                 % will not use a gradient, otherwise it will. So if the 
%                 % SubSystem in the old model used a mask, this part of the
%                 % appearance will not be maintained (because we don't want
%                 % to create a new mask for the sole purpose of imitating
%                 % appearance).
%                 
%                 atomics = copySystemInports(block, newBlock, atomics, predicates);
%             catch ME
%                 if (strcmp(ME.identifier,'Simulink:Commands:AddBlockCantAdd'))
% %                     newBlockHandle = get_param(newBlock, 'Handle');
%                 else
%                     rethrow(ME)
%                 end
%             end
%             
%             % Create Outport for the SubSystem port
%             assert(strcmp(handleType, 'port'))
%             pNum = get_param(handle, 'PortNumber');
%             outport = find_system(block, 'SearchDepth', 1, 'BlockType', 'Outport', 'Port', num2str(pNum)); % Finds the Outport corresponding to the SubSystem port from the original system
%             assert(length(outport) == 1)
%             outport = outport{1};
%             
%             newOutport = regexprep(outport,['^' origSys], sysName, 'ONCE');
%             add_block(outport, newOutport);
%             
%             % Add SubSystem port to atomics
%             expressionID = predicates(handle);
%             atomics(expressionID) = inoutblock2subport(newOutport);
%         elseif strcmp(blockType, 'If') || strcmp(blockType, 'SwitchCase')
%             % Create If/SwitchCase block in new system
%             newBlock = regexprep(block,['^' origSys], sysName, 'ONCE');
%             try
%                 newBlockHandle = add_block(block, newBlock);
%             catch ME
%                 if (strcmp(ME.identifier,'Simulink:Commands:AddBlockCantAdd'))
%                     newBlockHandle = get_param(newBlock, 'Handle');
%                 else
%                     rethrow(ME)
%                 end
%             end
%             
%             % Since the block was copied we won't need to worry about 
%             % having the right number of ports
%             
%             % Add If port to atomics
%             assert(strcmp(handleType, 'port'))
%             pNum = get_param(handle, 'PortNumber');
%             
%             ifPortHandle = find_system(newBlockHandle, 'FindAll', 'on', 'Type', 'port', 'PortType', 'outport', 'PortNumber', pNum);
%             assert(length(ifPortHandle) == 1)
%             
%             expressionID = predicates(handle);
%             atomics(expressionID) = ifPortHandle;
%         end
%     end
% end
% 
% % Create black boxes
% blackBoxes = {}; % Block names for blackboxes
% for i = 1:length(expressionsToGenerate)
%     isBB = isBlackBoxExpression(expressionsToGenerate{i});
%     if isBB
%         [lhs, ~] = getExpressionLhsRhs(expressionsToGenerate{i});
%         
%         % Get info about LHS
%         handle = getKeyFromVal(predicates, lhs);
%         handleType = get_param(handle,'Type');
%         % Get the block
%         if strcmp(handleType, 'block')
%             block = getfullname(handle);
%         elseif strcmp(handleType, 'port')
%             block = get_param(handle, 'Parent');
%         end
% 
%         blackBoxes{end+1} = block;
%     end
% end
% blackBoxes = unique(blackBoxes);
% atomics = copyBlackBoxes(origSys, sysName, atomics, predicates, blackBoxes);
% 
% memo = containers.Map();
% 
% % Create blocks for each expression
% for i = 1:length(expressionsToGenerate)
%     createLogicBlocks(expressionsToGenerate{i}, atomics, memo, predicates, inExprs, origSys, sysName);
% end

%%

    %Remove old blocks and add new ones representing simplified logical
    %expression
%     [outExpression, ~] = createLogicBlocks(expressionToGenerate, 1, 1, atomics, memo, getfullname(logicSys));
%     trueBlockGiven = false; falseBlockGiven = false; % Run without FCA blocks
%     if strcmp(expressionToGenerate, '(TRUE)') || strcmp(expressionToGenerate, '(CbTRUE)')
%         if trueBlockGiven
%             constLoc = ['ChryslerLib/Parameters' char(10) '&' char(10) 'Constants/TRUE Constant'];
%             memo('(TRUE)')=add_block(constLoc, [getfullname(demoSys) '/simplifier_generated_true'],'MAKENAMEUNIQUE','ON');
%         else
%             memo('(TRUE)')=add_block('built-in/Constant', ...
%                 [getfullname(demoSys) '/simplifier_generated_true'],'MAKENAMEUNIQUE','ON','Value','true','OutDataTypeStr','boolean');
%         end
%         outExpression = '(TRUE)';
%     elseif strcmp(expressionToGenerate, '(FALSE)') || strcmp(expressionToGenerate, '(CbFALSE)')
%         if falseBlockGiven
%             constLoc = ['ChryslerLib/Parameters' char(10) '&' char(10) 'Constants/FALSE Constant'];
%             memo('(FALSE)') = add_block(constLoc, [getfullname(demoSys) '/simplifier_generated_false'],'MAKENAMEUNIQUE','ON');
%         else
%             memo('(FALSE)')=add_block('built-in/Constant', ...
%                 [getfullname(demoSys) '/simplifier_generated_false'],'MAKENAMEUNIQUE','ON','Value','false','OutDataTypeStr','boolean');
%         end
%         outExpression = '(FALSE)';
%     else
%         [outExpression, ~] = createLogicBlocks(expressionToGenerate, 1, 1, atomics, memo, getfullname(demoSys));
%     end


%%
%%
% Put blocks in system according to the expressions

% memo = containers.Map();
% atomics = containers.Map();
% 
% parent = get_param(blocks{1}, 'parent'); % Get name of system the blocks are in
% parentName = get_param(parent, 'Name');
% inports = find_system(parent, 'SearchDepth', 1, 'BlockType', 'Inport'); % List of inports in the system
% froms = find_system(parent, 'SearchDepth', 1, 'BlockType', 'From'); % List of froms in the system
% constants = find_system(parent, 'SearchDepth', 1, 'BlockType', 'Constant'); % List of constant blocks in the system
% 
% for i = 1:length(inports)
%     ports = get_param(inports{i}, 'PortHandles');
%     dstPort = ports.Outport;
%     assert(length(dstPort) == 1, 'Unexpected number of outports on block.')
%     expressionID = predicates(dstPort); % ID used to refer to this block in expressions
%     
%     name = get_param(inports{i}, 'Name');
%     newIn = add_block(inports{i}, [sysName '/' name]);
%     
%     atomics(expressionID) = newIn;
% end
% 
% for i = 1:length(froms)
%     ports = get_param(froms{i}, 'PortHandles');
%     dstPort = ports.Outport;
%     assert(length(dstPort) == 1, 'Unexpected number of outports on block.')
%     expressionID = predicates(dstPort); % ID used to refer to this block in expressions
%     
%     name = get_param(froms{i}, 'Name');
%     newIn = add_block(froms{i}, [sysName '/' name]);
%     
%     atomics(expressionID) = newIn;
% end
% 
% for i = 1:length(constants)
%     ports = get_param(constants{i}, 'PortHandles');
%     dstPort = ports.Outport;
%     assert(length(dstPort) == 1, 'Unexpected number of outports on block.')
%     try
%         expressionID = predicates(dstPort); % ID used to refer to this block in expressions
%     catch % Fail for unused blocks
%         continue
%     end
%     
%     name = get_param(constants{i}, 'Value');
%     try
%         if strcmp(get_param(constants{i}, 'Mask'), 'on')||strcmp(name(1:2), 'Ke')
%             try
%                 newIn = add_block(constants{i}, [sysName '/' name]);
%                 
%                 atomics(expressionID) = newIn;
%             catch
%             end
%         end
%     catch
%     end
% end


% % Put given blocks in system
% % for i = 1:length(blocks)
% %     name = get_param(blocks{i}, 'Name');
% %     outBlock = add_block(blocks{i}, [sysName '/' name]);
% % end
% for i = 1:length(expressionsToGenerate)
%     % Generate for RHS (outBlocks already added)
%     [outBlockID, expressionToGenerate] = getExpressionLhsRhs(expressionsToGenerate{i});
%     
%     %Make expression well formed
%     expressionToGenerate = makeWellFormed(expressionToGenerate);
%     
%     %Remove old blocks and add new ones representing simplified logical
%     %expression
%     [outExpression, ~] = createLogicBlocks(expressionToGenerate, 1, 1, atomics, memo, sysName);
%     
%     % Add block for lhs of expression
%     origOutBlockHandle = getKeyFromVal(predicates, outBlockID);
%     origOutBlock = getfullname(origOutBlockHandle);
%     origOutName = get_param(origOutBlockHandle, 'Name');
%     outBlock = add_block(origOutBlock, [sysName '/' origOutName]);
%     
%     % Connect to the outport
%     logicOut = memo(outExpression);
%     logicOutPort = get_param(logicOut, 'PortHandles');
%     logicOutPort = logicOutPort.Outport;
%     outBlockInPort = get_param(outBlock, 'PortHandles');
%     outBlockInPort = outBlockInPort.Inport;
%     
%     add_line(sysName, logicOutPort, outBlockInPort);
% end

end

function atomics = copySystemInports(startSys, endSys, atomics, predicates)
inports = find_system(startSys, 'SearchDepth', 1, 'BlockType', 'Inport'); % List of inports in the system
for i = 1:length(inports)
    ports = get_param(inports{i}, 'PortHandles');
    dstPort = ports.Outport;
    assert(length(dstPort) == 1, 'Unexpected number of outports on block.')
    
    assert(strcmp(startSys, get_param(block, 'Parent')))
    newIn = copy_block(inports{i}, endSys);
    
    if isKey(predicates, dstPort)
        equationID = predicates(dstPort); % ID used to refer to this block in equations
        atomics(equationID) = newIn;
    end % else the inport isn't used
end
end

function atomics = copySystemSubSystems(startSys, endSys, atomics, predicates)
subsystems = find_system(startSys, 'SearchDepth', 1, 'BlockType', 'SubSystem', 'Parent', startSys); % List of SubSystems in the system
for i = 1:length(subsystems)
    newBlock = regexprep(subsystems{i},['^' startSys], endSys, 'ONCE');
    newSub = add_block(subsystems{i}, newBlock);
    
    oldSubOutports = get_param(subsystems{i}, 'PortHandles');
    oldSubOutports = oldSubOutports.Outport;
    
    subOutports = get_param(newSub, 'PortHandles');
    subOutports = subOutports.Outport;
    
    assert(length(oldSubOutports) == length(subOutports))
    for j = 1:length(subOutports)
        if isKey(predicates, oldSubOutports(j))
            equationID = predicates(oldSubOutports(j));
            atomics(equationID) = subOutports(j);
        end
    end
end
end

function atomics = copyBlackBoxes(startSys, endSys, atomics, predicates, blackBoxes)
for i = 1:length(blackBoxes)
    newBlock = regexprep(blackBoxes{i},['^' startSys], endSys, 'ONCE');
    newBB = add_block(blackBoxes{i}, newBlock);
    
    oldBBOutports = get_param(blackBoxes{i}, 'PortHandles');
    oldBBOutports = oldBBOutports.Outport;
    
    BBOutports = get_param(newBB, 'PortHandles');
    BBOutports = BBOutports.Outport;
    
    assert(length(oldBBOutports) == length(BBOutports))
    for j = 1:length(BBOutports)
        if isKey(predicates, oldBBOutports(j))
            equationID = predicates(oldBBOutports(j));
            atomics(equationID) = BBOutports(j);
        end
    end
end
end