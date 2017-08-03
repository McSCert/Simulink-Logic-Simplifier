function [oldExpr newExpr] = SimplifyLogic(blocks)
% SIMPLIFYLOGIC A function that takes a set of logic blocks and simplifies
%   them.
%
%   Input:
%       blocks  Cell array of blocks (indicated by fullname). All blocks
%               should be in the same system/subsystem. Input blocks should
%               be the outputs of the simplification (i.e. if the only only
%               block is an outport, it will simplify the blocks that
%               impact it).
%
%   Outputs:
%       oldExpr     Cell array of expressions found for the blocks as
%                   given.
%       newExpr     Cell array of expressions found for the blocks after
%                   the simplification process.

% Constants:
DELETE_UNUSED = getLogicSimplifierConfig('delete_unused', 'off'); % Indicates whether or not to delete blocks which are unused in the final model
REPLACE_EXISTING_MODEL = 'on'; % When creating the model for the simplification, it will replace a file with the same name if 'on' otherwise it will error

memo = containers.Map();
atomics = containers.Map();

parent = get_param(blocks{1}, 'parent'); % Get name of system the blocks are in
inports = find_system(parent, 'SearchDepth', 1, 'BlockType', 'Inport'); % List of inports in the system
froms = find_system(parent, 'SearchDepth', 1, 'BlockType', 'From'); % List of froms in the system
constants = find_system(parent, 'SearchDepth', 1, 'BlockType', 'Constant'); % List of constant blocks in the system

% Create a new system for the simplification
parentName = get_param(parent, 'Name');
try
    logicSys = new_system([parentName '_newLogic']); % This will error if it's already open
catch ME
    if strcmp(REPLACE_EXISTING_MODEL, 'off')
        rethrow(ME)
    elseif strcmp(REPLACE_EXISTING_MODEL, 'on')
        close_system([parentName '_newLogic']);
        logicSys = new_system([parentName '_newLogic']);
    else
        error(['Error in ' mfilename ', REPLACE_EXISTING_MODEL should be ''on'' or ''off''.']);
    end
end
open_system(logicSys);
% try
%     demoSys = open_system([parentName '_newLogic']);
% catch
%     demoSys = new_system([parentName '_newLogic']);
%     open_system(demoSys);
% end

for i = 1:length(inports)
    name = get_param(inports{i}, 'Name');
    newIn = add_block(inports{i}, [parentName '_newLogic/' name]);
    atomics(name) = newIn;
end

for i = 1:length(froms)
    name = get_param(froms{i}, 'Name');
    newIn = add_block(froms{i}, [parentName '_newLogic/' name]);
    atomics(name) = newIn;
end

for i = 1:length(constants)
    name = get_param(constants{i}, 'Value');
    try
        if strcmp(get_param(constants{i}, 'Mask'), 'on')||strcmp(name(1:2), 'Ke')
            try
                newIn = add_block(constants{i}, [parentName '_newLogic/' name]);
                atomics(name) = newIn;
            catch
            end
        end
    catch
    end
end

for i = 1:length(blocks)
    name = get_param(blocks{i}, 'Name');
    outBlock = add_block(blocks{i}, [parentName '_newLogic/' name]);
    
    %Get source for outport block
    outportPort = get_param(blocks{i}, 'PortHandles');
    outportPort = outportPort.Inport;
    line = get_param(outportPort, 'line');
    srcBlock = get_param(line, 'SrcBlockHandle');
    
    %Find the logical expression of the blocks
    port = get_param(srcBlock, 'PortHandles');
    port = port.Outport;
    %[expression, ~] = getExpressionForBlock(port);
    expression = getExpressionForBlock(port);
    
    %Swap Chrysler's CbTRUE for symengine's TRUE
    expression = strrep(expression, 'CbTRUE', 'TRUE');
    expression = strrep(expression, 'CbFALSE', 'FALSE');
    
    %Do the simplification
    newExpression = simplifyExpression(expression);
    
    %Strip whitespace
    newExpression = regexprep(newExpression,'\s','');
    % newExpression = regexprep(newExpression,'[^\w&_|~><=()]','');
    %^this also removes the minus even though it probably wasn't intended to
    
    %Make the newExpression well formed
    expressionToGenerate = makeWellFormed(newExpression);
    
    %Remove old blocks and add new ones representing simplified logical
    %expression
    [outExpression, ~] = createLogicBlocks(expressionToGenerate, 1, 1, atomics, memo, getfullname(logicSys));
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

    %Connect to the outport
    logicOut = memo(outExpression);
    logicOutPort = get_param(logicOut, 'PortHandles');
    logicOutPort = logicOutPort.Outport;
    outBlockInPort = get_param(outBlock, 'PortHandles');
    outBlockInPort = outBlockInPort.Inport;
    
    add_line(getfullname(logicSys), logicOutPort,outBlockInPort);
    
    if isLsNewerVer()
        %Perform second pass, finding common block patterns and reducing them
        secondPass(getfullname(logicSys));
    end
end

if strcmp(DELETE_UNUSED,'on')
    %Delete blocks with ports unconnected to other blocks (should mean the
    %block wasn't needed)
    deleteIfUnconnectedSignal(logicSys, 1);
end

%Fix the layout
AutoLayout(getfullname(logicSys));

%Zoom on new system
set_param(getfullname(logicSys), 'Zoomfactor', '100');

oldExpr = expression;
newExpr = newExpression;
end