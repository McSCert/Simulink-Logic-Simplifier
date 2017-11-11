function exprs = getExprsForBlocks(startSys, blocks, sysBlocks, lhsTable, subsystem_rule)
%
%
%   Inputs:
%       startSys    Starting system
%       blocks      Blocks we want expressions for. Other blocks will be
%                   treated as blackboxes.
%       sysBlocks   All blocks in the startSys. May include blocks within
%                   subsystems.
%
%   Updates: (input and output)
%       lhsTable    Records object handles and their representation within 
%                   expressions.
%
%   Outputs:
%       exprs       List of expressions. Cell array of chars.

% for each b in sysBlocks
%   if b has no outports
%       get expressions for b
%   else
%       for each o in outports, get expressions for outports of b

exprs = {};
for i = 1:length(sysBlocks)
    % Get outports
    ports = get_param(sysBlocks{i}, 'PortHandles');
    dstPorts = ports.Outport;
    
    if isempty(dstPorts)
        [newExprs, ~] = getExprs(startSys, get_param(sysBlocks{i}, 'Handle'), blocks, lhsTable, subsystem_rule);
        exprs = [exprs, newExprs];
    else
        for j = 1:length(dstPorts)
            [newExprs, ~] = getExprs(startSys, dstPorts(j), blocks, lhsTable, subsystem_rule);
            exprs = [exprs, newExprs];
        end
    end
end
end

function [newExprs, handleID] = getExprs(startSys, h, blocks, lhsTable, subsystem_rule)

if ~lhsTable.lookup.isKey(h)
    % Get expression type - 'blk', 'in', or 'out'
    eType = expressionType(h);
    
    % Get block type
    blk = getBlock(h);
    bType = get_param(blk, 'BlockType');
    
    isMask = strcmp(get_param(blk, 'Mask'), 'on');
    % Get mask type if it exists and determine if the mask/block type is
    % supported
    if isMask
        mType = get_param(blk, 'MaskType');
        isSupp = isSupportedMaskType(mType);
    else
        isSupp = isSupportedBlockType(bType);
    end
    
    % Figure out what to call the handle in expressions
    % Note: The type variable below can't be used to reliably get type data,
    % its purpose is just to be human readable for analysis.
    if isMask
        type = [mType '_' eType '_'];
    else
        type = [bType '_' eType '_'];
    end
    type = regexprep(regexprep(type,'([^A-Za-z0-9])',''), '(^[0-9]*)', ''); % Strip characters that aren't valid for the expression structure
    handleID = getUniqueId(type, lhsTable);
    % Add to lhsTable
    lhsTable.add(h, handleID); % This will tell us not to get this expression again (apart from the main use of lhsTable)
    
    inBlx = any(strcmp(blk, blocks));
    switch eType
        case 'blk'
            if inBlx && isMask && isSupp
                newExprs = getSuppMaskBlkExpression();
            elseif inBlx && isSupp
                newExprs = getSuppBlkExpression();
            else
                % Block is not supported or it isn't in blocks (blocks
                % designates the set of blocks we want to simplify)
                
                % Treat as blackbox
                newExprs = getBlackBoxExpression();
            end
        case 'out'
            if ~inBlx || (isMask && ~isSupp) || (~isMask && ~isSupp)
                % Block is not supported or it isn't in blocks (blocks
                % designates the set of blocks we want to simplify)
                
                % Treat as blackbox
                newExprs = getBlackBoxExpression();
            else
                if isMask
                    newExprs = getSuppMaskOutExpression();
                else
                    newExprs = getSuppOutExpression();
                end
            end
        case 'in'
            % Get the source
            srch = getSrcPorts(h); % DstPort of a block which connects to this
            assert(length(srch) == 1, 'Error, an input port is expected to have a single source.')
            
            % Get the expression for the handle and its sources recursively
            [srcExprs, srcID] = getExprs(startSys, srch, blocks, lhsTable, subsystem_rule);
            
            expr = [handleID ' = ' srcID]; % This block/port's expression with respect to its sources
            newExprs = [{expr}, srcExprs]; % Expressions involved in this block/port's expression
        otherwise
            error('Error, unexpected eType')
    end
else
    handleID = lhsTable.lookup(h);
    newExprs = {};
end

    function nex = getBlackBoxExpression()
        
        % Get the source ports of the blk (i.e. inport, enable, ifaction, etc.)
        ph = get_param(blk, 'PortHandles');
        pfields = fieldnames(ph);
        srcHandles = [];
        for i=setdiff(1:length(pfields), 2) % for all inport field types
            srcHandles = [srcHandles, ph.(pfields{i})];
        end
        
        % Get the expressions for the sources
        nex = {};
        expr = [handleID ' =? ']; % Note the notation '=?' being used for blackboxes
        for i = 1:length(srcHandles)
            [srcExprs, srcID] = getExprs(startSys, srcHandles(i), blocks, lhsTable, subsystem_rule);
            nex = [nex, srcExprs];
            expr = [expr, srcID, ','];
        end
        if ~isempty(srcHandles)
            expr = expr(1:end-1); % Remove trailing comma
        end
        
        nex = [nex, {expr}];
    end

    function nex = getSuppBlkExpression()
        % Get expression for unmasked handles with eType of 'blk'
        switch bType
            case {'DataStoreWrite', 'Goto', 'Outport'}
                % Get the source port
                ph = get_param(blk, 'PortHandles');
                srch = ph.Inport;
                assert(length(srch) == 1, 'Error, a block was expected to have a single source port.')
                
                % Get the expression for the handle and its sources recursively
                [srcExprs, srcID] = getExprs(startSys, srch, blocks, lhsTable, subsystem_rule);
                
                expr = [handleID ' = ' srcID]; % This block/port's expression with respect to its sources
                nex = [{expr}, srcExprs]; % Expressions involved in this block/port's expression
            case 'SubSystem'
                % TODO: This may need to be modified in the future to consider
                % implicit data flow.
                nex = getBlackBoxExpression();
            otherwise
                error('Error, unsupported BlockType when supported type expected.')
        end
    end

    function nex = getSuppMaskBlkExpression()
        % Get expression for masked handles with eType of 'blk'
        switch mtype
            % Nothing supported at present
            otherwise
                error('Error, unsupported MaskType when supported type expected.')
        end
    end

    function nex = getSuppOutExpression()
        % Get expression for unmasked handles with eType of 'out'
        
        % Note for subsystems and inports with subsystem_rule of
        % part-simplify: These aren't linked with blocks at higher
        % subsystem levels, but they could be, to do this, create the
        % expression as a blackbox instead. After making this change, the
        % function for creating blocks from the expression would need to
        % change so as to handle that connection without trying to connect
        % a signal line.
        
        switch bType
            case 'SubSystem'
                % TODO: This may need to be modified in the future to consider
                % implicit data flow.
                
                if any(strcmp(subsystem_rule, {'blackbox', 'part-simplify'}))
                    nex = getBlackBoxExpression();
                elseif strcmp('full-simplify', subsystem_rule)
                    
                    % Get the immediate source of the output port (i.e. the outport block within the subsystem)
                    outBlock = subport2inoutblock(h);
                    outBlock = outBlock{1};
                    srcHandle = get_param(outBlock, 'Handle');
                    
                    % Get the expressions for the sources
                    [srcExprs, srcID] = getExprs(startSys, srcHandle, blocks, lhsTable, subsystem_rule);
                    
                    expr = [handleID ' = ' srcID];
                    nex = [{expr}, srcExprs];
                else
                    error('Error, invalid subsystem_rule')
                end
            case 'Inport'
                if strcmp(get_param(blk, 'Parent'), startSys)
                    nex = {[handleID ' =? ']};
                elseif ~strcmp(get_param(blk, 'Parent'), startSys) && ...
                        strcmp('full-simplify', subsystem_rule)
                    % Get the source of the inport block (i.e. the corresponding
                    % input port of the subsystem)
                    inPort = inout2subport(h);
                    srcHandle = inPort{1};
                    
                    % Get the expressions for the sources
                    [srcExprs, srcID] = getExprs(startSys, srcHandle, blocks, lhsTable, subsystem_rule);
                    
                    expr = [handleID ' = ' srcID];
                    nex = [{expr}, srcExprs];
                elseif ~strcmp(get_param(blk, 'Parent'), startSys) && ...
                        any(strcmp(subsystem_rule, {'blackbox', 'part-simplify'}))
                    nex = {[handleID ' =? ']};
                else
                    error('Error, invalid subsystem_rule')
                end
            case 'Constant'
                chrysler = false; % using Chrysler blocks
                valIsNan = isnan(str2double(get_param(blk,'Value'))); % constant is using a string value
                valIsTorF = any(strcmp(get_param(blk,'Value'), {'true','false'}));
                
                % there may be a better way to identify Chrysler's constants
                if chrysler && (valIsNan && ~valIsTorF)
                    expr = [handleID ' =? ' get_param(blk, 'Value')];
                else
                    expr = [handleID ' = ' get_param(blk, 'Value')];
                end
                nex = {expr};
            case {'Logic', 'RelationalOperator'}
                [nex, ~] = getLogicExpression(startSys, h, handleID, blocks, lhsTable, subsystem_rule);
            otherwise
                error('Error, unsupported BlockType when supported type expected.')
        end
    end

    function nex = getSuppMaskOutExpression()
        % Get expression for masked handles with eType of 'out'
        switch mtype
            case {'Compare To Constant', 'Compare To Zero'}
                % TODO
            otherwise
                error('Error, unsupported MaskType when supported type expected.')
        end
    end
end

function [newExprs, handleID] = getLogicExpression(startSys, h, handleID, blocks, lhsTable, subsystem_rule)
% In theory you could do: get_param(block, 'Inputs')
%But I found in practice it returned the wrong number...

% Get the block
blk = getBlock(h);

% Get the source ports of the blk (i.e. inport, enable, ifaction, etc.)
ph = get_param(blk, 'PortHandles');
pfields = fieldnames(ph);
srcHandles = [];
for i=setdiff(1:length(pfields), 2) % for all inport field types (though only regular inports should matter)
    srcHandles = [srcHandles, ph.(pfields{i})];
end

assert(~isempty(srcHandles)) % Ensure minimum 1 source

numInputs = length(srcHandles);
if strcmp(get_param(blk, 'Mask'), 'on')
    operator = get_param(blk, 'RelOp');
    
    maskType = get_param(blk, 'MaskType');
    switch maskType
        case 'Compare To Constant'
            num = get_param(blk, 'Const');
        case 'Compare To Zero'
            num = '0';
        otherwise
            error(['Something went wrong in ' mfilename ' MaskType is currently not supported...']);
    end
    
    switch operator
        case '~='
            newExprs = binaryLogicExpr2('<>', num);
        case '=='
            newExprs = binaryLogicExpr2('==', num);
        case '<='
            newExprs = binaryLogicExpr2('<=', num);
        case '>='
            newExprs = binaryLogicExpr2('>=', num);
        case '<'
            newExprs = binaryLogicExpr2('<', num);
        case '>'
            newExprs = binaryLogicExpr2('>', num);
            
        otherwise
            error(['Operator ' operator ' currently not supported...']);
    end
else % Mask off
    operator = get_param(blk, 'Operator');
    
    switch operator
        case 'NOT'
            assert(numInputs == 1);
            
            % Get the expression for the source
            [srcExprs, srcID] = getExprs(startSys, srcHandles(1), blocks, lhsTable, subsystem_rule);
            
            expr = [handleID ' = ' '~' srcID]; % This block/port's expression with respect to its sources
            newExprs = {expr, srcExprs{1:end}}; % Expressions involved in this block's expressions
        case 'AND'
            newExprs = binaryLogicExpr('&');
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
end

    function nex = binaryLogicExpr(sym)
        assert(numInputs > 1);
        
        nex = {}; % newExprs
                
        % Get the expression for the source port
        [srcex, sID] = getExprs(startSys, srcHandles(1), blocks, lhsTable, subsystem_rule);
        nex = [nex, srcex]; % Add expressions for current source
        ex = [handleID ' = ' '(' sID ')']; % Expression for the block/port so far
        
        for j=2:numInputs
            % Get the expression for the source port
            [srcex, sID] = getExprs(startSys, srcHandles(j), blocks, lhsTable, subsystem_rule);
            nex = [nex, srcex]; % Expressions involved in this block's expressions
            ex = [ex ' ' sym ' (' sID ')']; % This block/port's expression with respect to its sources
        end
        
        nex = [{ex}, nex]; % Expressions involved in this block's expressions
    end
    function nex = binaryLogicExpr2(sym, var2)
        assert(numInputs == 1);
        
        nex = {}; % newExprs
        
        % Get the expression for the source port
        [srcex, sID] = getExprs(startSys, srcHandles(1), blocks, lhsTable, subsystem_rule);
        nex = [nex, srcex]; % Expressions involved in this block's expressions
        ex = [handleID ' = ' '(' sID ') ' sym ' (' var2 ')']; % Expression for the block/port so far
        nex = [{ex}, nex]; % Expressions involved in this block's expressions
    end
end

function uid = getUniqueId(type, existingIDs)
% GETUNIQUEID Gets a unique identifier for a block to use in expressions
%   (rather than having to write the fullpath).
%
%   Inputs:
%       type        The type of identifier we want. (E.g. blocktype)
%       existingIDs A bimap object (comes with Logic Simplifier).
%                   If existingIDs.lookdown('id') is defined then 'id'
%                   is an existing identifier.
%
%   Output:
%       uid     Character array for a unique identifier. Uses a type to
%               assign the identifier and appends a number to the end to
%               keep it different from existing identifiers.

assert(ischar(type), '''type'' variable expected to be char.')
assert(~isempty(regexp(type,'^[0-9A-Za-z_]*$', 'ONCE')), ...
    'Expression identifiers are required to only use characters from ''[0-9A-Za-z_]''.')

count = 1;
while true
    id = [type num2str(count)];
    if ~idExists()
        uid = id;
        return
    end
    count = count + 1;
end
    
    function bool = idExists()
        try 
            existingIDs.lookdown(id);
            bool = 1;
        catch ME
            if strcmp(ME.identifier, 'MATLAB:Containers:Map:NoKey')
                bool = 0;
            else
                rethrow(ME);
            end
        end
    end

% Later, find a uid within a string with:
%   regexp(str,[type num2str(#) '[^0-9A-Za-z_]'])
% E.g. For uid From10: 
%   regexp(str,['From' num2str(10) '[^0-9A-Za-z_]'])
% '[^0-9A-Za-z_]' is to prohibit matching From100 for From10
end