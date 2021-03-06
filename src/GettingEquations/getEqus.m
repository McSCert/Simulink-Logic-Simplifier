function [newEqus, handleID] = getEqus(startSys, h, blocks, lhsTable, subsystem_rule, extraSupport)
% GETEQUS Get a list of equations to represent the value of h. If an
% equation has previously been done (indicated by lhsTable), then that
% equation won't be generated again and won't be included in the output.
% This is a recursive function.
%
%   Inputs:
%       startSys        The parent system of the blocks that are being used to
%                       find an equation for h.
%       h               Handle of a block to find an equation for.
%       blocks          Blocks to not treat as blackbox while finding an
%                       equation for h.
%       subsystem_rule  A config option indicating how to address subsystems in 
%                       the simplification process.
%       extraSupport    A function determined by a config option that allows the
%                       Logic Simplifier Tool to provide support for blocks that
%                       are not otherwise handled by the Logic Simplifier Tool.
%
%   Updates: (input and output)
%       lhsTable    A BiMap object (see BiMap.m) that records object handles and
%                   their representation within equations. The BiMap is updated
%                   with new handles and their representations as equations for
%                   them are found.
%
%   Outputs:
%       newEqus     Equations found during the current recursive iteration that
%                   were not already found. If the left hand side of an equation
%                   is in lhsTable when this is called, then it was already
%                   found.
%       handleID    Char array representation for h used in equations.
%

% Notes/rough overview:
%   If h is an input port, then create an equation which sets it to the
%       output port which sends a signal to h
%   If the block/mask type corresponding with h is not supported or not listed
%       in blocks, then create a blackbox equation for it
%   If it is supported and listed in blocks, then create an appropriate
%       equation for the block given using it's next sources as input
%       "next source" will generally be an input port of a block
%   When creating equations, for any input to that equation, find the
%       equation for that input (through a recursive call)

    if ~lhsTable.lookup.isKey(h)
        % Get equation type - 'blk', 'in', or 'out'
        eType = equationType(h);

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

        % Figure out what to call the handle in equations
        % Note: The type variable below can't be used to reliably get type data,
        % its purpose is just to be human readable for analysis.
        if isMask
            type = [mType '_' eType '_'];
        else
            type = [bType '_' eType '_'];
        end
        type = regexprep(regexprep(type,'([^A-Za-z0-9])',''), '(^[0-9]*)', ''); % Strip characters that aren't valid for the equation structure
        handleID = getUniqueId(type, lhsTable);
        % Add to lhsTable
        lhsTable.add(h, handleID); % This will tell us not to get this equation again (apart from the main use of lhsTable)

        inBlx = any(strcmp(blk, blocks));
        switch eType
            case 'blk'
                if ~inBlx
                    % Not selected for simplification so must be blackbox
                    % Treat as blackbox
                    newEqus = getBlackBoxEquation();
                else
                    [inExtraSupp, newEqus] = extraSupport(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport);
                    if ~inExtraSupp
                        if ~isSupp
                            % Block is not supported by this function
                            % Treat as blackbox
                            newEqus = getBlackBoxEquation();
                        else
                            if isMask
                                newEqus = getSuppMaskBlkEquation();
                            else
                                newEqus = getSuppBlkEquation();
                            end
                        end
                    end % else use result from extraSupport
                end
            case 'out'
                if ~inBlx
                    % Not selected for simplification so must be blackbox
                    % Treat as blackbox
                    newEqus = getBlackBoxEquation();
                else
                    [inExtraSupp, newEqus] = extraSupport(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport);
                    if ~inExtraSupp
                        if ~isSupp
                            % Block is not supported by this function
                            % Treat as blackbox
                            newEqus = getBlackBoxEquation();
                        else
                            if isMask
                                newEqus = getSuppMaskOutEquation();
                            else
                                newEqus = getSuppOutEquation();
                            end
                        end
                    end % else use result from extraSupport
                end
            case 'in'
                % Get the source
                srch = getSrcPorts(h); % DstPort of a block which connects to this
                assert(length(srch) == 1, 'Error, an input port is expected to have a single source.')

                % Get the equation for the handle and its sources recursively
                [srcEqus, srcID] = getEqus(startSys, srch, blocks, lhsTable, subsystem_rule, extraSupport);

                equ = [handleID ' = ' srcID]; % This block/port's equation with respect to its sources
                newEqus = [{equ}, srcEqus]; % Equations involved in this block/port's equation
            otherwise
                error('Error: Unexpected eType')
        end
    else
        handleID = lhsTable.lookup(h);
        newEqus = {};
    end

    function neq = getBlackBoxEquation()

        % Get the source ports of the blk (i.e. inport, enable, ifaction, etc.)
        srcHandles = getPorts(blk, 'In');

        % Get the equations for the sources
        neq = {};
        equ = [handleID ' =? ']; % Note the notation '=?' being used for blackboxes
        for i = 1:length(srcHandles)
            [srcEqus, srcID] = getEqus(startSys, srcHandles(i), blocks, lhsTable, subsystem_rule, extraSupport);
            neq = [neq, srcEqus];
            equ = [equ, srcID, ','];
        end
        if ~isempty(srcHandles)
            equ = equ(1:end-1); % Remove trailing comma
        end

        neq = [neq, {equ}];
    end

    function neq = getSuppBlkEquation()
        % Get equation for unmasked handles with eType of 'blk'
        switch bType
            case {'DataStoreWrite', 'Goto', 'Outport'}
                % Get the source port
                ph = get_param(blk, 'PortHandles');
                srch = ph.Inport;
                assert(length(srch) == 1, 'Error, a block was expected to have a single source port.')

                bbFlag = false; % Default

                % If a DSW/Goto leads into a block that is being
                % considered blackbox, then that block must not be removed,
                % thus the DSW/Goto needs to stay as well to send it data.
                % Thus if a corresponding DSR/From is not in blocks, then
                % the current block must be made blackbox.
                if any(strcmp(bType, {'DataStoreWrite', 'Goto'}))
                    if strcmp(bType, 'Goto')
                        findFun = @findFromsInScope;
                    elseif strcmp(bType, 'DataStoreWrite')
                        findFun = @ findReadsInScope;
                    end
                    dstBlocks = findFun(blk);
                    for i = 1:length(dstBlocks)
                        dBlk = dstBlocks{i};
                        if isempty(find(strcmp(dBlk,blocks))) % if dBlk not in blocks
                            bbFlag = true; % means that the goto/write has a from/read not in blocks
                            break;
                        end
                    end
                end

                if bbFlag == true
                    neq = getBlackBoxEquation();
                else
                    % Get the equation for the handle and its sources recursively
                    [srcEqus, srcID] = getEqus(startSys, srch, blocks, lhsTable, subsystem_rule, extraSupport);

                    equ = [handleID ' = ' srcID]; % This block/port's equation with respect to its sources
                    neq = [{equ}, srcEqus]; % Equations involved in this block/port's equation
                end
            case 'SubSystem'
                % TODO: This may need to be modified in the future to consider
                % implicit data flow.
                neq = getBlackBoxEquation();
            otherwise
                error('Error, unsupported BlockType when supported type expected.')
        end
    end

    function neq = getSuppMaskBlkEquation()
        % Get equation for masked handles with eType of 'blk'
        switch mtype
            % Nothing supported at present
            otherwise
                error('Error, unsupported MaskType when supported type expected.')
        end
    end

    function neq = getSuppOutEquation()
        % Get equation for unmasked handles with eType of 'out'

        % Note for subsystems and inports with subsystem_rule of
        % part-simplify: These aren't linked with blocks at higher
        % subsystem levels, but they could be, to do this, create the
        % equation as a blackbox instead. After making this change, the
        % function for creating blocks from the equation would need to
        % change so as to handle that connection without trying to connect
        % a signal line.

        switch bType
            case 'SubSystem'
                % TODO: This may need to be modified in the future to consider
                % implicit data flow.

                if any(strcmp(subsystem_rule, {'blackbox', 'part-simplify'}))
                    neq = getBlackBoxEquation();
                elseif strcmp(subsystem_rule, 'full-simplify')

                    % Get the immediate source of the output port (i.e. the outport block within the subsystem)
                    outBlock = subport2inoutblock(h);
                    srcHandle = get_param(outBlock, 'Handle');

                    % Get the equations for the sources
                    [srcEqus, srcID] = getEqus(startSys, srcHandle, blocks, lhsTable, subsystem_rule, extraSupport);

                    equ = [handleID ' = ' srcID];
                    neq = srcEqus;

                    ifPort = getPorts(blk, 'Ifaction');
                    assert(length(ifPort) <= 1, 'Error: Expected 0 or 1 if action port on a subsystem.')

                    if ~isempty(ifPort)
                        % Get the equations for the Ifaction port
                        [srcEqus, srcID] = getEqus(startSys, ifPort, blocks, lhsTable, subsystem_rule, extraSupport);

                        equ = [equ ' & ' srcID];
                        neq = [{equ}, srcEqus, neq];
                    else
                        neq = [{equ}, neq];
                    end
                else
                    error('Error, invalid subsystem_rule')
                end
            case 'Inport'
                if strcmp(get_param(blk, 'Parent'), startSys)
                    neq = {[handleID ' =? ']};
                elseif ~strcmp(get_param(blk, 'Parent'), startSys) && ...
                        strcmp('full-simplify', subsystem_rule)
                    % Get the source of the inport block (i.e. the corresponding
                    % input port of the subsystem)
                    srcHandle = inoutblock2subport(blk);

                    % Get the equations for the sources
                    [srcEqus, srcID] = getEqus(startSys, srcHandle, blocks, lhsTable, subsystem_rule, extraSupport);

                    equ = [handleID ' = ' srcID];
                    neq = [{equ}, srcEqus];
                elseif ~strcmp(get_param(blk, 'Parent'), startSys) && ...
                        any(strcmp(subsystem_rule, {'blackbox', 'part-simplify'}))
                    neq = {[handleID ' =? ']};
                else
                    error('Error, invalid subsystem_rule')
                end
            case 'Constant'
                value = get_param(blk, 'Value');
                valIsNan = isnan(str2double(value)); % constant is using a string value
                valIsTorF = any(strcmp(value, {'true','false'}));

                if valIsTorF
                    equ = [handleID ' = ' value];
                elseif valIsNan
                    equ = [handleID ' =? '];
                else
                    equ = [handleID ' = ' value];
                end

                neq = {equ};
            case 'Ground'
                equ = [handleID ' = ' '0'];
                neq = {equ};
            case 'Logic'
                % Get operator
                operator = get_param(blk, 'Operator');

                switch operator
                    case 'AND'
                        sym = '&';
                        neq = getNaryOpEquation(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport, sym);
                    case 'OR'
                        sym = '|';
                        neq = getNaryOpEquation(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport, sym);
                    case 'NAND'
                        sym = '&';
                        neq = getNaryOpEquation(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport, sym);
                        % 1st equation in neq is an AND equation, we need
                        % to negate it
                        [lhs, rhs] = getEquationLhsRhs(neq{1});
                        neq{1} = [lhs ' = ' '~(' rhs ')'];
                    case 'NOR'
                        sym = '|';
                        neq = getNaryOpEquation(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport, sym);
                        % 1st equation in neq is an OR equation, we need
                        % to negate it
                        [lhs, rhs] = getEquationLhsRhs(neq{1});
                        neq{1} = [lhs ' = ' '~(' rhs ')'];
                    case 'NOT'
                        % Get the source port
                        srcHandle = getPorts(blk, 'Inport');
                        assert(length(srcHandle) == 1)

                        % Get the equation for the source
                        [srcEqus, srcID] = getEqus(startSys, srcHandle(1), blocks, lhsTable, subsystem_rule, extraSupport);

                        equ = [handleID ' = ' '~' srcID]; % This block/port's equation with respect to its sources
                        neq = {equ, srcEqus{1:end}}; % Equations involved in this block's equations
                    case {'XOR', 'NXOR'}
                        % This should be updated in the future depending on
                        % how well the simplification can handle XOR and NXOR.
                        % This current implementation assumes that they
                        % will most likely be simplified poorly if
                        % translated to an expression using ~, &, |
                        % so instead these are treated as blackbox.
                        % A first step for this in the future may be to
                        % implement it such that it is black box unless the
                        % operator can be removed entirely.

                        neq = getBlackBoxEquation();
                    otherwise
                        error('Unexpected Operator parameter on Logic block.')
                end
            case 'Merge'
                % Treat like an OR Logic block
                % This isn't necessarily an accurate representation so it
                % may be modified in the future e.g. only treat as an OR
                % under specific circumstances else treat as blackbox.
                neq = getNaryOpEquation(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport, '|');
            case 'RelationalOperator'
                % Get operator
                operator = get_param(blk, 'RelOp');

                if any(strcmp(operator, {'~=', '==', '<=', '>=', '<', '>'}))
                    sym = operator;
                    neq = getNaryOpEquation(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport, sym);
                end
            case 'If'
                if any(strcmp(subsystem_rule, {'blackbox', 'part-simplify'}))
                    neq = getBlackBoxEquation();
                elseif strcmp(subsystem_rule, 'full-simplify')
                    [neq, ~] = getIfEqu(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport);
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

                % Get source equations
                [srcEqus1, srcID1] = getEqus(startSys, srcHandles(1), blocks, lhsTable, subsystem_rule, extraSupport);
                [srcEqus2, srcID2] = getEqus(startSys, srcHandles(2), blocks, lhsTable, subsystem_rule, extraSupport);
                [srcEqus3, srcID3] = getEqus(startSys, srcHandles(3), blocks, lhsTable, subsystem_rule, extraSupport);

                criteria_param = get_param(blk, 'Criteria');
                thresh = get_param(blk, 'Threshold');
                criteria = strrep(strrep(criteria_param, 'u2 ', ['(' srcID2 ')']), 'Threshold', thresh); % Replace 'u2 ' and 'Threshold'

                % Record source equations
                mult_add_available = false; % This will be made true/removed once * and + are accepted
                if mult_add_available
                    equ = [handleID ' = ' '(((' criteria ')*(' srcID1 '))+(~(' criteria ')*(' srcID3 ')))']; % This block/port's equation with respect to its 1st source
                else
                    equ = [handleID ' = ' '(((' criteria ')&(' srcID1 '))|(~(' criteria ')&(' srcID3 ')))']; % srcID1 and 3 may not be logical so this doesn't work
                end
                neq = [{equ}, srcEqus1, srcEqus2, srcEqus3]; % Equations involved in this block's equations
            case 'From'
                % Get corresponding Goto block
                gotoInfo = get_param(blk, 'GotoBlock');
                srcHandle = gotoInfo.handle;
                if isempty(srcHandle) || ~any(strcmp(getBlock(srcHandle), blocks))
                    % Goto not found or should not be linked because it is
                    % blackbox

                    froms = findFromsInScope(srcHandle);
                    setEqu = false;
                    for i = 1:length(froms)
                        from_i = getPorts(froms{i}, 'Outport');
                        if lhsTable.lookup.isKey(from_i) ...
                                && from_i ~= lhsTable.lookdown(handleID)
                            equ = [handleID ' = ' lhsTable.lookup(from_i)];
                            setEqu = true;
                            break
                        end
                    end
                    if ~setEqu
                        % Record as a blackbox equation
                        equ = [handleID ' =? '];
                    end
                    neq = {equ};
                else
                    % Get Goto equations
                    [srcEqus, srcID] = getEqus(startSys, srcHandle, blocks, lhsTable, subsystem_rule, extraSupport);

                    % Record this block's equations
                    equ = [handleID ' = ' srcID]; % The equation for this handle
                    neq = [{equ}, srcEqus]; % Equations involved in this block's equations
                end
            case 'DataStoreRead'
                neq = getBlackBoxEquation();
            otherwise
                error('Error, unsupported BlockType when supported type expected.')
        end
    end

    function neq = getSuppMaskOutEquation()
        % Get equation for masked handles with eType of 'out'
        switch mType
            case {'Compare To Constant', 'Compare To Zero'}
                if strcmp(mType, 'Compare To Constant')
                    num = get_param(blk, 'Const');
                elseif strcmp(mType, 'Compare To Zero')
                    num = '0';
                end

                % Get operator
                operator = get_param(blk, 'RelOp');

                if any(strcmp(operator, {'~=', '==', '<=', '>=', '<', '>'}))
                    sym = operator;
                    neq = getNaryOpEquation(startSys, h, handleID, blocks, ...
                        lhsTable, subsystem_rule, extraSupport, sym, {num}); % note use of varargin for this function
                end
            otherwise
                error('Error, unsupported MaskType when supported type expected.')
        end
    end
end

function uid = getUniqueId(type, existingIDs)
    % GETUNIQUEID Gets a unique identifier for a block to use in equations
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
    assert(~isempty(regexp(type,'^\w*$', 'ONCE')), ...
        'Expression identifiers only use digits, letters, and underscores.')

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