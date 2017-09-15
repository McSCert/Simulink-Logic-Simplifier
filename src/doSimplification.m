function [endingExpressions, startingExpressions] = doSimplification(sys, blocks)
% DOSIMPLIFICATION Performs simplification on the input blocks.
%
%   Inputs:
%       sys     Handle of empty system to place the simplified blocks in.
%       blocks  List of blocks to perform simplification on.
%
%   Outputs:
%       startingExpressions     Expressions extracted from blocks for
%                               simplification.
%       endingExpressions       Expressions generated by simplifying the
%                               starting expressions to use to build a
%                               simpler model.

% Constants:
SUBSYSTEM_RULE = getLogicSimplifierConfig('subsystem_rule', 'blackbox'); % Indicates how to address subsystems in the simplification process

sysName = getfullname(sys);
origSys = get_param(blocks{1}, 'Parent');

% TODO - predicates will likely need to be passed around between functions
% and this may not be where it should be defined (or even how it should be
% defined.
%predicates = BiMap('double','char'); % Keys: block handles; Values: name of predicate to use in expressions

% Keep a list of blocks/ports that we have expressions for
predicates = containers.Map('KeyType','double','ValueType','char');
% Keep record of the inports that a source goes to for non obvious block
% types (e.g. If blocks)
inExprs = containers.Map('KeyType','char','ValueType','char'); % Key is a value from predicates, Value is a char indicating another value from predicates as well as an inport

% Get expression for each block in form:
% 'blockID = expr', where expr is an expression which may involve other blockIDs
% --getExps2Simp(blx)
% ---output: cell array of expressions, 1 for each of blx, 1 for each subsystem input, 1 for each subsystem output
tempExpressions = getBlockExpressions(origSys, blocks, predicates, inExprs);

% % Find which expressions should be subbed into others
% subsIdx = whichExpressionsToSub(tempExpressions); % subsI is indices from tempExpressions
% % Substitute expressions each other
% startingExpressions = substituteExpressions(tempExpressions, subsIdx);
startingExpressions = substituteExpressions(tempExpressions, blocks, predicates);

% Simplify each expression
endingExpressions = cell(1,length(startingExpressions));
for i = 1:length(startingExpressions)
    [lhs, rhs] = getExpressionLhsRhs(startingExpressions{i});
    
    %Do the simplification
    simpleRhs = simplifyExpression(rhs);
    
    %Strip whitespace
    simpleRhs = regexprep(simpleRhs, '\s', '');
    endingExpressions{i} = [lhs, ' = ', simpleRhs];
end

endingExpressions = reorderExpressions(origSys, endingExpressions, predicates);

expressionsToGenerate = endingExpressions;
if strcmp(SUBSYSTEM_RULE, 'blackbox')
    % Remove expressions for SubSystems so that we don't try to produce
    % their contents.
    for i = length(expressionsToGenerate):-1:1
        [lhs, ~] = getExpressionLhsRhs(expressionsToGenerate{i});
        handle = getKeyFromVal(predicates, lhs);
        
        handleType = get_param(handle,'Type');

        % Get the block
        if strcmp(handleType, 'block')
            block = getfullname(handle);
        elseif strcmp(handleType, 'port')
            block = get_param(handle, 'Parent');
        end
        blockType = get_param(block, 'BlockType');
        
        if strcmp(blockType, 'SubSystem')
            expressionsToGenerate(i) = [];
        end
    end
end

atomics = containers.Map();

% Create top-level Inports
atomics = copySystemInports(origSys, sysName, atomics, predicates);

% Create needed SubSystems and the Inports within them.
if strcmp(SUBSYSTEM_RULE, 'blackbox')
    % Simply duplicate SubSystems at top-level
    atomics = copySystemSubSystems(origSys, sysName, atomics, predicates);
else
    for i = 1:length(endingExpressions) % <- loop on endingExpressions where SubSystems have not been removed
        [lhs, ~] = getExpressionLhsRhs(endingExpressions{i});
        handle = getKeyFromVal(predicates, lhs);
        
        handleType = get_param(handle,'Type');
        
        % Get the block
        if strcmp(handleType, 'block')
            block = getfullname(handle);
        elseif strcmp(handleType, 'port')
            block = get_param(handle, 'Parent');
        end
        blockType = get_param(block, 'BlockType');
        
        if strcmp(blockType, 'SubSystem')
            % Create SubSystem block in new system
            newBlock = regexprep(block,['^' origSys], sysName, 'ONCE');
            try
%                 newBlockHandle = add_block(block, newBlock);
%                 Simulink.SubSystem.deleteContents(newBlockHandle)
                add_block('built-in/SubSystem', newBlock);
                
                % Preserve block color
                foreColor = get_param(block, 'ForegroundColor');
                backColor = get_param(block, 'BackgroundColor');
                set_param(newBlock, 'ForegroundColor', foreColor)
                set_param(newBlock, 'BackgroundColor', backColor)
                
                % If a SubSystem block is masked, then its background color
                % will not use a gradient, otherwise it will. So if the 
                % SubSystem in the old model used a mask, this part of the
                % appearance will not be maintained (because we don't want
                % to create a new mask for the sole purpose of imitating
                % appearance).
                
                atomics = copySystemInports(block, newBlock, atomics, predicates);
            catch ME
                if (strcmp(ME.identifier,'Simulink:Commands:AddBlockCantAdd'))
%                     newBlockHandle = get_param(newBlock, 'Handle');
                else
                    rethrow(ME)
                end
            end
            
            % Create Outport for the SubSystem port
            assert(strcmp(handleType, 'port'))
            pNum = get_param(handle, 'PortNumber');
            outport = find_system(block, 'SearchDepth', 1, 'BlockType', 'Outport', 'Port', num2str(pNum)); % Finds the Outport corresponding to the SubSystem port from the original system
            assert(length(outport) == 1)
            outport = outport{1};
            
            newOutport = regexprep(outport,['^' origSys], sysName, 'ONCE');
            add_block(outport, newOutport);
%             newOut = add_block(outport, newOutport);
%             atomics(expressionID) = newOut;
            
            % Add SubSystem port to atomics
            expressionID = predicates(handle);
            atomics(expressionID) = inoutblock2subport(newOutport);
        elseif strcmp(blockType, 'If') || strcmp(blockType, 'SwitchCase')
            % Create If/SwitchCase block in new system
            newBlock = regexprep(block,['^' origSys], sysName, 'ONCE');
            try
                newBlockHandle = add_block(block, newBlock);
            catch ME
                if (strcmp(ME.identifier,'Simulink:Commands:AddBlockCantAdd'))
                    newBlockHandle = get_param(newBlock, 'Handle');
                else
                    rethrow(ME)
                end
            end
            
            % Since the block was copied we won't need to worry about 
            % having the right number of ports
            
            % Add If port to atomics
            assert(strcmp(handleType, 'port'))
            pNum = get_param(handle, 'PortNumber');
            
            ifPortHandle = find_system(newBlockHandle, 'FindAll', 'on', 'Type', 'port', 'PortType', 'outport', 'PortNumber', pNum);
            assert(length(ifPortHandle) == 1)
            
            expressionID = predicates(handle);
            atomics(expressionID) = ifPortHandle;
        end
    end
end

memo = containers.Map();

% Create blocks for each expression
for i = 1:length(expressionsToGenerate)
    createLogicBlocks(expressionsToGenerate{i}, atomics, memo, predicates, inExprs, origSys, sysName);
end

% Create blocks for each expression
% for i = 1:length(expressionsToGenerate)
%     createLogicBlocks3(expressionToGenerate{i});
% end

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

% Perform second pass, finding common block patterns and reducing them
for i = 1:length(blocks)
    if isLsNewerVer()
        secondPass(sysName);
    end
end

end

function atomics = copySystemInports(startSys, endSys, atomics, predicates)
inports = find_system(startSys, 'SearchDepth', 1, 'BlockType', 'Inport'); % List of inports in the system
for i = 1:length(inports)
    ports = get_param(inports{i}, 'PortHandles');
    dstPort = ports.Outport;
    assert(length(dstPort) == 1, 'Unexpected number of outports on block.')
    
    newBlock = regexprep(inports{i},['^' startSys], endSys, 'ONCE');
    newIn = add_block(inports{i}, newBlock);
    
    if ~isKey(predicates, dstPort)
        % The inport isn't used
    else
        expressionID = predicates(dstPort); % ID used to refer to this block in expressions
        atomics(expressionID) = newIn;
    end
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
            expressionID = predicates(oldSubOutports(j));
            atomics(expressionID) = subOutports(j);
        end
    end
end
end