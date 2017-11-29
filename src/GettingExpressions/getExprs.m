function [newExprs, handleID] = getExprs(startSys, h, blocks, lhsTable, subsystem_rule, extraSupport)
% GETEXPRS Get a list of expressions to represent the value of h. If an
% expression has previously been done (indicated by lhsTable), then that
% expression won't be generated again and won't be included in the output.


% Notes/rough overview:
%   If h is an input port, then create an expression which sets it to the
%       output port which sends a signal to h
%   If the block/mask type corresponding with h is not supported or not listed 
%       in blocks, then create a blackbox expression for it
%   If it is supported and listed in blocks, then create an appropriate
%       expression for the block given using it's next sources as input
%       "next source" will generally be an input port of a block
%   When creating expressions, for any input to that expression, find the
%       expression for that input (through a recursive call)

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
            [inExtraSupp, newExprs] = extraSupport(startSys, h, blocks, lhsTable, subsystem_rule, extraSupport);
            if ~inExtraSupp
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
            end
        case 'out'
            [inExtraSupp, newExprs] = extraSupport();
            if ~inExtraSupp
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
            end
        case 'in'
            % Get the source
            srch = getSrcPorts(h); % DstPort of a block which connects to this
            assert(length(srch) == 1, 'Error, an input port is expected to have a single source.')
            
            % Get the expression for the handle and its sources recursively
            [srcExprs, srcID] = getExprs(startSys, srch, blocks, lhsTable, subsystem_rule, extraSupport);
            
            expr = [handleID ' = ' srcID]; % This block/port's expression with respect to its sources
            newExprs = [{expr}, srcExprs]; % Expressions involved in this block/port's expression
        otherwise
            error('Error: Unexpected eType')
    end
else
    handleID = lhsTable.lookup(h);
    newExprs = {};
end

    function nex = getBlackBoxExpression()
        
        % Get the source ports of the blk (i.e. inport, enable, ifaction, etc.)
        srcHandles = getPorts(blk, 'In');
                
        % Get the expressions for the sources
        nex = {};
        expr = [handleID ' =? ']; % Note the notation '=?' being used for blackboxes
        for i = 1:length(srcHandles)
            [srcExprs, srcID] = getExprs(startSys, srcHandles(i), blocks, lhsTable, subsystem_rule, extraSupport);
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
                [srcExprs, srcID] = getExprs(startSys, srch, blocks, lhsTable, subsystem_rule, extraSupport);
                
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
                elseif strcmp(subsystem_rule, 'full-simplify')
                    
                    % Get the immediate source of the output port (i.e. the outport block within the subsystem)
                    outBlock = subport2inoutblock(h);
                    srcHandle = get_param(outBlock, 'Handle');
                    
                    % Get the expressions for the sources
                    [srcExprs, srcID] = getExprs(startSys, srcHandle, blocks, lhsTable, subsystem_rule, extraSupport);
                    
                    expr = [handleID ' = ' srcID];
                    nex = srcExprs;
                    
                    ifPort = getPorts(blk, 'Ifaction');
                    assert(length(ifPort) <= 1, 'Error: Expected 0 or 1 if action port on a subsystem.')
                    
                    if ~isempty(ifPort)
                        % Get the expressions for the Ifaction port
                        [srcExprs, srcID] = getExprs(startSys, ifPort, blocks, lhsTable, subsystem_rule, extraSupport);
                        
                        expr = [expr ' & ' srcID];
                        nex = [{expr}, srcExprs, nex];
                    else
                        nex = [{expr}, nex];
                    end
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
                    srcHandle = inoutblock2subport(blk);
                    
                    % Get the expressions for the sources
                    [srcExprs, srcID] = getExprs(startSys, srcHandle, blocks, lhsTable, subsystem_rule, extraSupport);
                    
                    expr = [handleID ' = ' srcID];
                    nex = [{expr}, srcExprs];
                elseif ~strcmp(get_param(blk, 'Parent'), startSys) && ...
                        any(strcmp(subsystem_rule, {'blackbox', 'part-simplify'}))
                    nex = {[handleID ' =? ']};
                else
                    error('Error, invalid subsystem_rule')
                end
            case 'Constant'
                value = get_param(blk, 'Value');
                valIsNan = isnan(str2double(get_param(blk,'Value'))); % constant is using a string value
                valIsTorF = any(strcmp(get_param(blk,'Value'), {'true','false'}));
                
                if valIsTorF
                    expr = [handleID ' = ' value];
                elseif valIsNan
                    expr = [handleID ' =? '];
                else
                    expr = [handleID ' = ' value];
                end
                
                nex = {expr};
            case {'Logic', 'RelationalOperator'}
                [nex, ~] = getLogicExpression(startSys, h, handleID, blocks, lhsTable, subsystem_rule);
            case 'If'
                if any(strcmp(subsystem_rule, {'blackbox', 'part-simplify'}))
                    nex = getBlackBoxExpression();
                elseif strcmp(subsystem_rule, 'full-simplify')
                    [nex, ~] = getIfExpr(startSys, h, handleID, blocks, lhsTable, subsystem_rule);
                else
                    error('Error, invalid subsystem_rule')
                end
            case 'Switch'
                % TODO make other symbols work with the simplifier for switch
                % won't work as it requires * and + operators
                
                % Get the source ports of the blk (i.e. inports)
                ph = get_param(blk, 'PortHandles');
                srcHandles = ph.Inport;
            
                assert(length(srcHandles) == 3) % IfElseif requires condition, then case, and else case
                
                % Get source expressions
                [srcExprs1, srcID1] = getExpr(startSys, srcHandles(1), blocks, lhsTable, subsystem_rule, extraSupport);
                [srcExprs2, srcID2] = getExpr(startSys, srcHandles(2), blocks, lhsTable, subsystem_rule, extraSupport);
                [srcExprs3, srcID3] = getExpr(startSys, srcHandles(3), blocks, lhsTable, subsystem_rule, extraSupport);
                
                criteria_param = get_param(block, 'Criteria');
                thresh = get_param(block, 'Threshold');
                criteria = strrep(strrep(criteria_param, 'u2 ', ['(' srcID2 ')']), 'Threshold', thresh); % Replace 'u2 ' and 'Threshold'
                
                % Record source expressions
                mult_add_available = false; % This will be made true/removed once * and + are accepted
                if mult_add_available
                    expr = [handleID ' = ' '(((' criteria ')*(' srcID1 '))+(~(' criteria ')*(' srcID3 ')))']; % This block/port's expression with respect to its 1st source
                else
                    expr = [handleID ' = ' '(((' criteria ')&(' srcID1 '))|(~(' criteria ')&(' srcID3 ')))']; % srcID1 and 3 may not be logical so this doesn't work
                end
                newExprs = [{expr}, srcExprs1, srcExprs2, srcExprs3]; % Expressions involved in this block's expressions
            case 'From'
                % Get corresponding Goto block
                %goto = getGoto4From(block);
                gotoInfo = get_param(blk, 'GotoBlock');
                srcHandle = gotoInfo.handle;
                if isempty(srcHandle) || ~any(strcmp(getBlock(srcHandle), blocks))
                    % Goto not found or should not be linked because it is
                    % blackbox
                    
                    % Record as a blackbox expression
                    expr = [handleID ' =? '];
                    nex = {expr};
                else
                    % Get Goto expressions
                    [srcExprs, srcID] = getExprs(startSys, srcHandle, blocks, lhsTable, subsystem_rule, extraSupport);
                    
                    % Record this block's expressions
                    expr = [handleID ' = ' srcID]; % The expression for this handle
                    nex = [{expr}, srcExprs]; % Expressions involved in this block's expressions
                end
            case 'DataStoreRead'
                nex = getBlackBoxExpression();
            case 'Merge'
            
            otherwise
                error('Error, unsupported BlockType when supported type expected.')
        end
    end

    function nex = getSuppMaskOutExpression()
        % Get expression for masked handles with eType of 'out'
        switch mType
            case {'Compare To Constant', 'Compare To Zero'}
                [nex, ~] = getLogicExpression(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport);
            otherwise
                error('Error, unsupported MaskType when supported type expected.')
        end
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