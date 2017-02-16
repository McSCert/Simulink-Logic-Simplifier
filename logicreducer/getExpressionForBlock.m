function expr = getExpressionForBlock(blockPort)
%   Terminal blocks are farthest possible src blocks in the chain
%   expr is the expression the block represents
    blockCategoryDic = getCategoryDic();
    
    blockName = get_param(blockPort, 'parent');
    blockType = get_param(blockName, 'BlockType');
    %checks the block type, and gets an expression for the block based on its associated blocktype.
    %blocktype in this case is an arbitrary label given to types of blocks in the accompanying xml file to this function.
    switch blockCategoryDic(blockType)
        case 'IO'
            expr = getIOExpr(blockName, blockType, blockPort);
        case 'Memory'
            expr = getMemoryExpr(blockName, blockType);
        case 'Branching'
            expr = getBranchingExpr(blockName, blockType, blockPort);
        case 'Collapsible'
            expr = getSimpleExpr(blockName, blockType);
        otherwise
            error(['Unsupposed block category ' blockCategoryType(blockType)]);
    end

end

%The following are functions that create an expression for each associated block category.
%The getLocalVarName function essentially declares that block as an atomic proposition
%in the logical expression.

function memoryExpr =...
    getMemoryExpr(blockName, blockType)
    
    blockCategoryDic = getCategoryDic();
    switch blockType
        case 'UnitDelay'
            localVar = getLocalVarName(blockName);
            memoryExpr = localVar;
        case 'Delay'
%           For now treating same as UnitDelay... TODO customize it.
            localVar = getLocalVarName(blockName);
            memoryExpr = localVar;
        case 'From'
            %For now treating same as UnitDelay... TODO customize it.
            memoryExpr = get_param(blockName, 'Name');
        otherwise
            error(['Blocktype unsupported ' blockType '...']);
    end
end

function branchingExpr = getBranchingExpr(blockName, blockType, blockPort)
    %currently these blocks are handled in the most basic way possible: assuming these blocks
    %as atomic propositions. To implement if blocks, we must change the case 'If' with a function.

    switch blockType
        case 'Switch'
            lines = get_param(blockName, 'LineHandles');
            lines = lines.Inport;
            expr1 = getExpressionForBlock(get_param(lines(1), 'SrcPortHandle'));
            expr2 = getExpressionForBlock(get_param(lines(2), 'SrcPortHandle'));
            expr3 = getExpressionForBlock(get_param(lines(3), 'SrcPortHandle'));
            branchingExpr = ['(((' expr2 ')&(' expr1 '))|(~(' expr2 ')&(' expr3 ')))'];
        case 'If'
            branchingExpr = getIfExpr(blockName, blockPort);
        case 'Deadzone'
            branchingExpr = getLocalVarName(blockName);
        case 'Merge'
            ports = get_param(blockName, 'PortHandles');
            ports = ports.Inport;
            line = get_param(ports(1), 'Line');
            srcPort = get_param(line, 'SrcPortHandle');
            branchingExpr = [ '(' getExpressionForBlock(srcPort)];
            for n = 2:length(ports)
                line = get_param(ports(n), 'Line');
                srcPort = get_param(line, 'SrcPortHandle');
                branchingExpr = [branchingExpr '&' getExpressionForBlock(srcPort)];
            end
            branchingExpr = [branchingExpr ')'];
        otherwise
            error(['Blocktype unsupported ' blockType '...']);
    end
end

function ifExpr = getIfExpr(blockName, blockPort)
    %this function will parse the conditions of the if block
    %in order to produce a logical expression indicative of the if block
    portNum = get_param(blockPort, 'PortNumber');
    expressions = get_param(blockName, 'ElseIfExpressions');
    if ~isempty(expressions)
        expressions = regexp(expressions, ',', 'split');
        expressions = [{get_param(blockName, 'IfExpression')} expressions];
    else
        expressions = {};
        expressions{end + 1} = get_param(blockName, 'IfExpression');
    end
    exprOut = '(';
    for i = 1:portNum - 1
        exprOut = [exprOut '(~(' expressions{i} '))&' ];
    end
    try
        exprOut = [ exprOut '(' expressions{portNum} '))' ];
    catch
        exprOut = exprOut(1:end - 2);
        exprOut = [exprOut '))'];
    end
    ifExpr = exprOut;
    
    inPorts = get_param(blockName, 'PortHandles');
    inPorts = inPorts.Inport;
    conditionIndices = regexp(exprOut, 'u[0-9]+');
    for i = 1:length(conditionIndices)
        backIndex = length(exprOut) - conditionIndices(i);
        condition = regexp(exprOut(length(exprOut)-backIndex:end), '^u[0-9]+', 'match');
        condition = condition{1};
        condNum = condition(2:end);
        lineForCond = get_param(inPorts(str2num(condNum)), 'line');
        srcPort = get_param(lineForCond, 'SrcPortHandle');
        ifExpr = [ifExpr(1:end-backIndex-1) '(' getExpressionForBlock(srcPort) ')' ifExpr(end-backIndex+length(condition):end)];
    end
end

function simpleExpr = getSimpleExpr(blockName, blockType)

    blockCategoryDic = getCategoryDic();
    switch blockType
        case 'Constant'
            simpleExpr = get_param(blockName, 'Value');
        case 'Logic'
            simpleExpr = getLogicExpr(blockName);
        case 'RelationalOperator'
            simpleExpr = getLogicExpr(blockName);
        otherwise
            error(['Blocktype unsupported ' blockType '...']);
    end
end

function ioExpr = getIOExpr(blockName, blockType, blockPort)

    blockCategoryDic = getCategoryDic();
    switch blockType
        case 'Inport'
            ioExpr = get_param(blockName, 'Name');
        case 'Outport'
            srcPorts = getSrcPorts(blockName);
            if(length(srcPorts) > 1)
                error('outport assumption wrong');
            end
            ioExpr = checkForConnectedLocalVar(blockName);
            if (isempty(ioExpr))
                ioExpr = [get_param(blockName, 'Name') ' = '...
                    getExpressionForBlock(srcPorts(1))];
            else
                ioExpr = [get_param(blockName, 'Name') ' = ' ioExpr];
            end
        case 'DataStoreRead'
            localVar = getLocalVarName(blockName);
            ioExpr = localVar;
        case 'DataStoreWrite'
            ioExpr = checkForConnectedLocalVar(blockName);
            if(isempty(ioExpr))
                ioExpr = [getLocalVarName(blockName) '='...
                    getExpressionForBlock(blockPort)];
            end
        case 'SubSystem'
            specialPort = find_system(blockName, 'SearchDepth', 1, 'BlockType', 'ActionPort');
            ports = get_param(blockName, 'PortHandles');
            oportNum = get_param(blockPort, 'PortNumber');
            
            %get expression for subsystem
            portBlock = find_system(blockName, 'SearchDepth', 1, 'BlockType', 'Outport', 'Port', num2str(oportNum));
            portBlock = portBlock{1};
            oportInLine = get_param(portBlock, 'LineHandles');
            oportInLine = oportInLine.Inport;
            callPort = get_param(oportInLine, 'SrcPortHandle');
            
            subExpr = getExpressionForBlock(callPort);
            
            if ~isempty(specialPort)
                iport = ports.Ifaction;
                line = get_param(iport, 'Line');
                port = get_param(line, 'SrcPortHandle');
                ifblock = get_param(port, 'parent');
                const = find_system(blockName, 'SearchDepth', 1, 'BlockType', 'Constant');
                
                %Find the expression
                exp = getIfExpr(ifblock, port);
                ioExpr = ['(~' exp ' | ' subExpr ')'];
            else
                inportBlocks = find_system(blockName, 'SearchDepth', 1, 'BlockType', 'Inport');
                
                for i = 1:length(inportBlocks)
                    inportName = get_param(inportBlocks{i}, 'Name');
                    inportNum = str2num(get_param(inportBlocks{i}, 'Port'));
                    subsysInLines = get_param(blockName, 'LineHandles');
                    subsysInLines = subsysInLines.Inport;
                    if ismatrix(subsysInLines)
                        exprPort = get_param(subsysInLines(inportNum), 'SrcPortHandle');
                        %add stuff for swapping inport stuff for expr
                    else
                        exprPort = get_param(subsysInLines, 'SrcPortHandle');
                        %add stuff for swapping inport stuff for expr
                    end
                end
            end
        otherwise
            error(['Blocktype unsupported ' blockType '...']);
    end
end

function logicExpr = getLogicExpr(blockName)
    % In theory you could do: get_param(blockName, 'Inputs')
    %But I found in practice it returned the wrong number...
    
    blockCategoryDic = getCategoryDic();
    srcPorts = getSrcPorts(blockName);
    try
        assert(~isempty(srcPorts))
        for i = 1:length(srcPorts)
            assert(srcPorts(i) ~= -1)
        end
    catch
        error(['Nothing is connected to ' blockName '...']);
    end
    numInputs = length(srcPorts);
    operator = get_param(blockName, 'Operator');
    switch operator
        case 'NOT'
            localVar = checkForConnectedLocalVar(blockName);
            if(isempty(localVar))
                logicExpr = ['~(' getExpressionForBlock(srcPorts(1)) ')'];
            else
               logicExpr = ['~' localVar]; 
            end
        case 'AND'
            logicExpr = ['(' getExpressionForBlock(srcPorts(1)) ')'];
            for i=2:numInputs
                localVar = getExpressionForBlock(srcPorts(i));
                logicExpr = [logicExpr '& (' localVar ')'];
            end
        case 'OR'
            logicExpr = ['(' getExpressionForBlock(srcPorts(1)) ')'];
            for i=2:numInputs
                localVar = getExpressionForBlock(srcPorts(i));
                logicExpr = [logicExpr '| (' localVar ') '];
            end
        case '~='
            logicExpr = ['(' getExpressionForBlock(srcPorts(1)) ')'];
            for i=2:numInputs
                localVar = getExpressionForBlock(srcPorts(i));
                logicExpr = [logicExpr '<> (' localVar ') '];
            end
        case '=='
            logicExpr = ['(' getExpressionForBlock(srcPorts(1)) ')'];
            for i=2:numInputs
                localVar = getExpressionForBlock(srcPorts(i));
                logicExpr = [logicExpr '== (' localVar ') '];
            end
        case '<='
            logicExpr = ['(' getExpressionForBlock(srcPorts(1)) ')'];
            for i=2:numInputs
                localVar = getExpressionForBlock(srcPorts(i));
                logicExpr = [logicExpr '<= (' localVar ') '];
            end
        case '>='
            logicExpr = ['(' getExpressionForBlock(srcPorts(1)) ')'];
            for i=2:numInputs
                localVar = getExpressionForBlock(srcPorts(i));
                logicExpr = [logicExpr '>= (' localVar ') '];
            end 
        case '<'
            logicExpr = ['(' getExpressionForBlock(srcPorts(1)) ')'];
            for i=2:numInputs
                localVar = getExpressionForBlock(srcPorts(i));
                logicExpr = [logicExpr '< (' localVar ') '];
            end
         case '>'
            logicExpr = ['(' getExpressionForBlock(srcPorts(1)) ')'];
            for i=2:numInputs
                localVar = getExpressionForBlock(srcPorts(i));
                logicExpr = [logicExpr '> (' localVar ') '];
            end 
        otherwise
            error(['Operator ' operator ' currently not supported...']);
    end
end
