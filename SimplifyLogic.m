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
        if strcmp(get_param(constants{i}, 'Mask'), 'on')||strcmp(name(1:2), 'Ke')
            try
                newIn = add_block(constants{i}, [parentName '_newLogic/' name]);
                atomics(name) = newIn;
            catch
            end
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

        expression = strrep(expression, 'CbTRUE', 'TRUE');
        expression = strrep(expression, 'CbFALSE', 'FALSE');
        expression = strrep(expression, '&', ' and ');
        expression = strrep(expression, '~', ' not ');
        expression = strrep(expression, '|', ' or ');
        expression = strrep(expression, '==', '=');

        %Let MATLAB simplify the expression
        newExpression = evalin(symengine, ['simplify(' expression ', condition)']);

        %Convert from symbolic type to string
        newExpression = char(newExpression);

        newExpression = strrep(newExpression, 'and', '&');
        newExpression = strrep(newExpression, 'not', '~');
        newExpression = strrep(newExpression, 'or', '|');
        newExpression = strrep(newExpression, '<>', '~=');
        newExpression = regexprep(newExpression, '[^<>]=[^<>]', '==');

        %Strip whitespace
        newExpression = regexprep(newExpression,'[^\w&_|~><=()]','');

        %Make the newExpression well formed
        expressionToGenerate = makeWellFormed(newExpression);

        %Remove old blocks and add new ones representing simplified logical
        %expression
        [outExpression, ~] = createLogicBlocks(expressionToGenerate, 1, 1, atomics, memo, getfullname(demoSys));

        %Connect to the outport
        logicOut = memo(outExpression);
        logicOutPort = get_param(logicOut, 'PortHandles');
        logicOutPort = logicOutPort.Outport;
        outBlockInPort = get_param(outBlock, 'PortHandles');
        outBlockInPort = outBlockInPort.Inport;

        add_line(getfullname(demoSys), logicOutPort,outBlockInPort);

        %Perform second pass, finding common block patterns and reducing them
        secondPass(getfullname(demoSys));

        %Fix the layout
        AutoLayout(getfullname(demoSys));

        % Zoom on new system
        set_param(getfullname(demoSys), 'Zoomfactor', '100');
    end
end