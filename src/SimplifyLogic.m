function expression = SimplifyLogic(blocks)
%SIMPLIFYLOGIC A function that takes a set of logic blocks and simplifies
%them.

memo = containers.Map();
atomics = containers.Map();

parent = get_param(blocks{1}, 'parent');
inports = find_system(parent, 'SearchDepth', 1, 'BlockType', 'Inport');
froms = find_system(parent, 'SearchDepth', 1, 'BlockType', 'From');
constants = find_system(parent, 'SearchDepth', 1, 'BlockType', 'Constant');

parentName = get_param(parent, 'Name');
try
    demoSys = open_system([parentName '_newLogic']);
catch
    demoSys = new_system([parentName '_newLogic']);
    open_system(demoSys);
end

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
    trueBlockGiven = false; falseBlockGiven = false; % Run without FCA blocks
    if strcmp(expressionToGenerate, '(TRUE)') || strcmp(expressionToGenerate, '(CbTRUE)')
        if trueBlockGiven
            constLoc = ['ChryslerLib/Parameters' char(10) '&' char(10) 'Constants/TRUE Constant'];
            memo('(TRUE)')=add_block(constLoc, [getfullname(demoSys) '/simplifier_generated_true'],'MAKENAMEUNIQUE','ON');
        else
            memo('(TRUE)')=add_block('built-in/Constant', ...
                [getfullname(demoSys) '/simplifier_generated_true'],'MAKENAMEUNIQUE','ON','Value','1','OutDataTypeStr','boolean');
        end
        outExpression = '(TRUE)';
    elseif strcmp(expressionToGenerate, '(FALSE)') || strcmp(expressionToGenerate, '(CbFALSE)')
        if falseBlockGiven
            constLoc = ['ChryslerLib/Parameters' char(10) '&' char(10) 'Constants/FALSE Constant'];
            memo('(FALSE)') = add_block(constLoc, [getfullname(demoSys) '/simplifier_generated_false'],'MAKENAMEUNIQUE','ON');
        else
            memo('(FALSE)')=add_block('built-in/Constant', ...
                [getfullname(demoSys) '/simplifier_generated_false'],'MAKENAMEUNIQUE','ON','Value','0','OutDataTypeStr','boolean');
        end
        outExpression = '(FALSE)';
    else
        [outExpression, ~] = createLogicBlocks(expressionToGenerate, 1, 1, atomics, memo, getfullname(demoSys));
    end
    
    %Connect to the outport
    logicOut = memo(outExpression);
    logicOutPort = get_param(logicOut, 'PortHandles');
    logicOutPort = logicOutPort.Outport;
    outBlockInPort = get_param(outBlock, 'PortHandles');
    outBlockInPort = outBlockInPort.Inport;
    
    add_line(getfullname(demoSys), logicOutPort,outBlockInPort);
    
    if isLsNewerVer()
        %Perform second pass, finding common block patterns and reducing them
        secondPass(getfullname(demoSys));
    end
    
    del = 'off';
    if strcmp(del,'on')
        %Delete blocks with ports unconnected to other blocks (should mean the
        %block wasn't needed)
        deleteIfUnconnectedSignal(demoSys, 1);
    end
    
    %Fix the layout
    AutoLayout(getfullname(demoSys));
    
    %Zoom on new system
    set_param(getfullname(demoSys), 'Zoomfactor', '100');
end
end