function exprs = getBlockExpressions(startSystem, blocks, predicates)
% GETBLOCKEXPRESSIONS Get expressions recursively for the outputs of the
%   given set of blocks.
%
%   Inputs:
%       startSystem     The starting system where the given blocks are
%                       located before any recursive calls.
%       blocks          List of blocks to find expressions for. These
%                       blocks are expected to be from the same level of
%                       the same system.
%       predicates      containers.Map() of handles (the keys) and
%                       predicate identifiers which are in use (the
%                       values). The values should be unique (as well as
%                       the keys). predicates should be set to the
%                       following on the first call and will be updated
%                       through subsequent calls (this is automatic since
%                       it's passed by reference):
%                       containers.Map('KeyType','double','ValueType','char')
%
%   Outputs:
%       exprs   Expressions extracted from blocks.

exprs = {};
for i = 1:length(blocks)
    bHandle = get_param(blocks{i}, 'Handle');
    
    ports = get_param(blocks{i}, 'PortHandles');
    dstPorts = ports.Outport;
    
    % Get exprHandles
    % exprHandles is the handles for which we want to find expressions
    if isempty(dstPorts) % Then use the block handle for the expression
        exprHandles = bHandle; % Get a single expression for the block itself
    else
        exprHandles = dstPorts; % Get an expression for each Outport of the block
    end
    
    for j = 1:length(exprHandles)
        % Get the expression for the given handle.
        % Also figure out the expressions for subsequent sources which affect
        % the original expression.
        newExprs = getExpr(startSystem, exprHandles(j), predicates);
        exprs = {exprs{1:end}, newExprs{1:end}};
    end
end

end

function [newExprs, handleID] = getExpr(startSystem, handle, predicates)
% GETEXPR Gets the expressions which define the expression of the given
%   block/outport handle. Also returns the identifier used to refer to the
%   given handle within expressions.
%
%   Inputs:
%       startSystem     The starting system where the given blocks are
%                       located before any recursive calls.
%       handle          A handle for either a block with no outports or an
%                       outport which we want an expression for.
%       predicates      containers.Map() of handles (the keys) and
%                       predicate identifiers which are in use (the
%                       values). The values should be unique (as well as
%                       the keys).
%
%   Outputs:
%       newExprs    Expression(s) for the given block as well as subsequent
%                   ones which influence it. If the subsequent ones are
%                   already handled (as indicated by keys in predicates),
%                   then they will not be included.
%       handleID    Char array. Identifier used to refer to the given
%                   handle within expressions.

handleType = get_param(handle,'Type');

% Get the block
if strcmp(handleType, 'block')
    block = getfullname(handle);
elseif strcmp(handleType, 'port')
    block = get_param(handle, 'Parent');
end

if ~predicates.isKey(handle)
    blockType = get_param(block, 'BlockType');
    
    % Figure out what to call the handle in expressions
    type = [blockType, '_', handleType, '_'];
    if ~strcmp(startSystem, get_param(block, 'Parent'))
        type = [type, 'Sub', '_'];
    end
    handleID = getUniqueId(type, predicates);
    % Add to predicates
    predicates(handle) = handleID; % Now it's a key in predicates so we'll never try to get its expression again
    
    % Find the expression (structure of the expression depends on block type)
    switch blockType
        case 'Constant'
            expr = [handleID ' = ' get_param(block, 'Value')];
            newExprs = {expr};
        case 'If'
            [newExprs, ~] = getIfExpr(startSystem, handle, handleID, block, predicates);
        case 'Inport'
            if ~strcmp(get_param(block, 'Parent'), startSystem)
                srcHandle = getInportSrc(block);
                [srcExprs, srcID] = getExpr(startSystem, srcHandle, predicates);
                
                expr = [handleID ' = ' srcID]; % This block/port's expression with respect to its sources
                newExprs = {expr, srcExprs{1:end}}; % Expressions involved in this block's expressions
            else
                newExprs = {}; % Expression is nothing since inport is atomic
            end
        case {'Logic', 'RelationalOperator'}
            [newExprs, ~] = getLogicExpr(startSystem, handle, handleID, handleType, block, predicates);
        case 'Outport'
            % Get the source
            srcPorts = getSrcPorts(block); % DstPort of a block which connects to this
            assert(length(srcPorts) <= 1, 'Outport not expected to have multiple sources.')
            assert(~isempty(srcPorts), 'Outport missing input.') % In the future these cases may be handled
            
            % Get the expression for the handle and its sources recursively
            [srcExprs, srcID] = getExpr(startSystem, srcPorts(1), predicates);
            
            expr = [handleID ' = ' srcID]; % This block/port's expression with respect to its sources
            newExprs = {expr, srcExprs{1:end}}; % Expressions involved in this block's expressions
        case 'SubSystem'
            [newExprs, ~] = getSubSystemExpr(startSystem, handle, handleID, handleType, block, predicates);
            
        case 'UnitDelay'
        case 'Delay'
        case 'From'
        case 'Switch'
        case 'Deadzone'
        case 'Merge'
        case 'DataStoreRead'
        case 'DataStoreWrite'
        otherwise
            % If there is one source, and no output, then we can view it
            % like an outport.
            %% TODO - consider other cases to implement; even if we can't 
            % simplify the block, we might be able to simplify around it.
            
            % Get the source
            srcPorts = getSrcPorts(block); % DstPort of a block which connects to this
            
            % Check dstports
            ports = get_param(block, 'PortHandles');
            dstPorts = ports.Outport;
            
            % Stop if the 1 inport, 0 outport assumption is wrong
            unsupportError = ['Unsupported block type ' blockType '.'];
            assert(length(srcPorts) == 1, unsupportError)
            assert(isempty(dstPorts), unsupportError)
            
            % Get the expression for the handle and its sources recursively
            [srcExprs, srcID] = getExpr(startSystem, srcPorts(1), predicates);
            
            expr = [handleID ' = ' srcID]; % This block/port's expression with respect to its sources
            newExprs = {expr, srcExprs{1:end}}; % Expressions involved in this block's expressions
    end
else
    handleID = predicates(handle);
    newExprs = {};
end
end

function uid = getUniqueId(type, existingIDs)
% GETUNIQUEID Gets a unique identifier for a block to use in expressions
%   (rather than having to write the fullpath).
%
%   Inputs:
%       type        The type of identifier we want. (E.g. blocktype)
%       existingIDs A containers.Map variable in which the values are the
%                   identifiers which are already in use.
%
%   Output:
%       uid     Character array for a unique identifier. Uses a type to
%               assign the identifier and appends a number to the end to
%               keep it different from existing identifiers.

assert(ischar(type), '''type'' variable expected to be char.')
assert(~isempty(regexp(type,'^[0-9A-z_]*$', 'ONCE')), ...
    'Expression identifiers are required to only use characters from ''[0-9A-z_]''.')

count = 1;
while true
    if ~valueExists(existingIDs, [type num2str(count)])
        uid = [type num2str(count)];
        return
    end
    count = count + 1;
end

    function bool = valueExists(map, value)
        % Note value assumed to be a char
        
        matches = regexp(map.values, ['^' value '$'], 'ONCE');
        
        bool = false;
        for i = 1:length(matches)
            if ~isempty(matches{i})
                bool = true;
                return
            end
        end
    end
% Later, find a uid with regexp(str,[type num2str(#) '[^0-9A-z_]'])
% E.g. For uid From10: regexp(str,['From' num2str(10) '[^0-9A-z_]'])
% '[^0-9A-z_]' is to prohibit matching From100 for From10
end

function srcHandle = getInportSrc(inport)
% GETINPORTSRC Gets the handle of the port which the inport comes from.
%   I.e. the outport of the block which leads to the corresponding inport
%   of the subsystem containing the given inport block.
%
%   Input:
%       inport  Block handle or fullname of an inport block within a
%               SubSystem.
%
%   Output:
%       srcHandle   Handle of the corresponding port of the parent
%                   SubSystem.

parent = get_param(inport, 'Parent');
pNum = str2num(get_param(inport, 'Port'));
portHandles = get_param(parent, 'PortHandles');
inportHandles = portHandles.Inport;

% Loop through inports to find the one with the correct port number
for i = [pNum:length(inportHandles), 1:pNum-1] % Only relevant i is the correct one which is most likely pNum so we'll check that first
    if get_param(inportHandles(i), 'PortNumber') == pNum
        subPortHandle = inportHandles(i);
        break
    end
end
assert(exist('subPortHandle', 'var') == 1, 'Error: Source not found for the given inport.')

% Get the source
srcLine = get_param(subPortHandle, 'Line');
srcHandle = get_param(srcLine, 'SrcPortHandle');

end

function [newExprs, handleID] = getSubSystemExpr(startSystem, handle, handleID, handleType, block, predicates)

%% TODO, consider if it's an ifaction subsystem and such

if strcmp(handleType, 'block')
    ports = get_param(block, 'PortHandles');
    dstPorts = ports.Outport;
    assert(isempty(dstPorts))
    
    % The subsystem has no outports so there is no real
    % expression. But we would probably like the expressions
    % of its sources and its contents.
    
    % Get expressions for contents
    subBlocks = find_system(block, 'SearchDepth', 1);
    subBlocks = subBlocks(2:end); % Exclude subsystem itself from the set of blocks
    subExprs = getBlockExpressions(startSystem, subBlocks, predicates);
    
    %% The commented chunk below should be handled through the call to getBlockExpressions above
    % Get expressions for the subsystem's sources
    %     iPortTypes = setdiff(fieldnames(ports),'Outport');
    %     for i = 1:length(iPortTypes)
    %         fields = fieldnames(ports);
    %         iPorts = ports.(fields{i});
    %         for j = 1:length(iPorts)
    %             [iExprs, ~] = getExpr(startSystem, iPorts(j), predicates);
    %         end
    %     end
    %
    %     newExprs = {iExprs{1:end}, subExprs{1:end}};
    newExprs = subExprs;
    
elseif strcmp(handleType, 'port')
    % Handle is an outport of the subsystem
    
    % Find the handle of the corresponding outport within the
    % SubSystem.
    oportNum = get_param(handle, 'PortNumber');
    portBlock = find_system(block, 'SearchDepth', 1, 'BlockType', 'Outport', 'Port', num2str(oportNum));
    portBlock = portBlock{1};
    outHandle = get_param(portBlock, 'Handle');
    
    % Get the expression for the outport block
    [outExprs, outID] = getExpr(startSystem, outHandle, predicates);
    
    actionBlock = find_system(block, 'SearchDepth', 1, 'BlockType', 'ActionPort');
    if isempty(actionBlock)
        expr = [handleID ' = ' outID]; % This block/port's expression with respect to its sources
        newExprs = {expr, outExprs{1:end}}; % Expressions involved in this block's expressions
    else
        ports = get_param(block, 'PortHandles');
        actionPort = ports.Ifaction;
        line = get_param(actionPort, 'Line');
        srcPort = get_param(line, 'SrcPortHandle');
        
        % Get the expression for the if block
        [ifExprs, ifID] = getExpr(startSystem, srcPort, predicates);
        
        % Find the net expression
        % Anticipated Change: May want to AND the if expression with each
        % expression found inside subsystem.
        expr = [handleID ' = ' '(' ifID ' & ' outID ')']; % If the if condition is met, then the SubSystem expression determines the result, else it is false
        newExprs = {expr, ifExprs{1:end}, outExprs{1:end}}; % Expressions involved in this block's expressions
    end
else
    error('Error: Something went wrong, unexpected handle type.')
end
end

function [newExprs, handleID] = getIfExpr(startSystem, handle, handleID, block, predicates)
%this function will parse the conditions of the if block
%in order to produce a logical expression indicative of the if block

% Get the expressions in the if block
portNum = get_param(handle, 'PortNumber');
expressions = get_param(block, 'ElseIfExpressions');
if ~isempty(expressions)
    expressions = regexp(expressions, ',', 'split');
    expressions = [{get_param(block, 'IfExpression')} expressions];
else
    expressions = {};
    expressions{end + 1} = get_param(block, 'IfExpression');
end

% Determine the conditions that trigger the given output port of the if
% block
exprOut = '(';
for i = 1:portNum - 1
    exprOut = [ exprOut '(~(' expressions{i} '))&' ];
end
try
    exprOut = [ exprOut '(' expressions{portNum} '))' ];
catch
    exprOut = exprOut(1:end - 2);
    exprOut = [exprOut '))'];
end
ifExpr = exprOut;

newExprs = {};

% Swap out u1, u2, ..., un for the expression of the input to the
% corresponding port
inPorts = get_param(block, 'PortHandles');
inPorts = inPorts.Inport;
conditionIndices = regexp(exprOut, 'u[0-9]+');
for i = 1:length(conditionIndices)
    backIndex = length(exprOut) - conditionIndices(i);
    condition = regexp(exprOut(length(exprOut)-backIndex:end), '^u[0-9]+', 'match');
    condition = condition{1};
    condNum = condition(2:end);
    lineForCond = get_param(inPorts(str2double(condNum)), 'line');
    srcPort = get_param(lineForCond, 'SrcPortHandle');
    
    % Get the expression for the source
    [srcExprs, srcID] = getExpr(startSystem, srcPort, predicates);
    
    ifExpr = [ifExpr(1:end-backIndex-1) '(' srcID ')' ifExpr(end-backIndex+length(condition):end)]; % This block/port's expression with respect to its sources
    newExprs = {newExprs{1:end}, srcExprs{1:end}}; % Expressions involved in this block's expressions
end
expr = [handleID ' = ' ifExpr];
newExprs = {expr, newExprs{1:end}}; % Expressions involved in this block's expressions
end

function [newExprs, handleID] = getLogicExpr(startSystem, handle, handleID, handleType, block, predicates)
% In theory you could do: get_param(block, 'Inputs')
%But I found in practice it returned the wrong number...

srcPorts = getSrcPorts(block);
try
    assert(~isempty(srcPorts)) % Ensure minimum 1 source
    for i = 1:length(srcPorts)
        assert(srcPorts(i) ~= -1) % Ensure proper connection on each source
    end
catch
    error([block ' is missing at least one connection.']);
end

numInputs = length(srcPorts);
operator = get_param(block, 'Operator');
switch operator
    case 'NOT'
        assert(numInputs == 1);
        
        % Get the expression for the source
        [srcExprs, srcID] = getExpr(startSystem, srcPorts(1), predicates);
        
        expr = [handleID ' = ' '~' srcID]; % This block/port's expression with respect to its sources
        newExprs = {expr, srcExprs{1:end}}; % Expressions involved in this block's expressions
    case 'AND'
        newExprs = binaryLogicExpr('&');
%         assert(numInputs > 1);
%         
%         newExprs = {};
%         
%         % Get the expression for the source port
%         [srcExprs, srcID] = getExpr(startSystem, srcPorts(1), predicates);
%         newExprs = {newExprs{1:end}, srcExprs{1:end}}; % Add expressions for current source
%         expr = [handleID ' = ' '(' srcID ')']; % Expression for the block/port so far
%         
%         for i=2:numInputs
%             % Get the expression for the source port
%             [srcExprs, srcID] = getExpr(startSystem, srcPorts(i), predicates);
%             newExprs = {newExprs{1:end}, srcExprs{1:end}}; % Expressions involved in this block's expressions
%             expr = [expr ' & (' srcID ')']; % This block/port's expression with respect to its sources
%         end
%         
%         newExprs = {expr, newExprs{1:end}}; % Expressions involved in this block's expressions
        
    case 'OR'
        newExprs = binaryLogicExpr('|');
    case '~='
        newExprs = binaryLogicExpr('<>');
    case '=='
        newExprs = binaryLogicExpr('==');
    case '<='
        newExprs = binaryLogicExpr('<=');
    case '>='
        newExprs = binaryLogicExpr('>=');
    case '<'
        newExprs = binaryLogicExpr('<');
    case '>'
        newExprs = binaryLogicExpr('>');
        
    otherwise
        error(['Operator ' operator ' currently not supported...']);
end
    function nex = binaryLogicExpr(sym)
        assert(numInputs > 1);
        
        nex = {}; % newExprs
        
        % Get the expression for the source port
        [srcex, sID] = getExpr(startSystem, srcPorts(1), predicates);
        nex = {nex{1:end}, srcex{1:end}}; % Add expressions for current source
        ex = [handleID ' = ' '(' sID ')']; % Expression for the block/port so far
        
        for j=2:numInputs
            % Get the expression for the source port
            [srcex, sID] = getExpr(startSystem, srcPorts(j), predicates);
            nex = {nex{1:end}, srcex{1:end}}; % Expressions involved in this block's expressions
            ex = [ex ' ' sym ' (' sID ')']; % This block/port's expression with respect to its sources
        end
        
        nex = {ex, nex{1:end}}; % Expressions involved in this block's expressions
    end
end