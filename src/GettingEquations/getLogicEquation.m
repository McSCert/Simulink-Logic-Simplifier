function newEqus = getLogicEquation(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport)
    %
    
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
                newEqus = binaryLogicEqu2('<>', num);
            case '=='
                newEqus = binaryLogicEqu2('==', num);
            case '<='
                newEqus = binaryLogicEqu2('<=', num);
            case '>='
                newEqus = binaryLogicEqu2('>=', num);
            case '<'
                newEqus = binaryLogicEqu2('<', num);
            case '>'
                newEqus = binaryLogicEqu2('>', num);
                
            otherwise
                error(['Operator ' operator ' currently not supported...']);
        end
    else % Mask off
        operator = get_param(blk, 'Operator');
        
        switch operator
            case 'NOT'
                assert(numInputs == 1);
                
                % Get the equation for the source
                [srcEqus, srcID] = getEqus(startSys, srcHandles(1), blocks, lhsTable, subsystem_rule, extraSupport);
                
                equ = [handleID ' = ' '~' srcID]; % This block/port's equation with respect to its sources
                newEqus = {equ, srcEqus{1:end}}; % Equations involved in this block's equations
            case 'AND'
                newEqus = binaryLogicEqu('&');
            case 'OR'
                newEqus = binaryLogicEqu('|');
            case '~='
                newEqus = binaryLogicEqu('<>');
            case '=='
                newEqus = binaryLogicEqu('==');
            case '<='
                newEqus = binaryLogicEqu('<=');
            case '>='
                newEqus = binaryLogicEqu('>=');
            case '<'
                newEqus = binaryLogicEqu('<');
            case '>'
                newEqus = binaryLogicEqu('>');
                
            otherwise
                error(['Operator ' operator ' currently not supported...']);
        end
    end
    
    function neqs = binaryLogicEqu(sym)
        assert(numInputs > 1);
        
        neqs = {}; % newEqus
        
        % Get the equation for the source port
        [srceqs, sID] = getEqus(startSys, srcHandles(1), blocks, lhsTable, subsystem_rule, extraSupport);
        neqs = [neqs, srceqs]; % Add equations for current source
        equ = [handleID ' = ' '(' sID ')']; % Equation for the block/port so far
        
        for j=2:numInputs
            % Get the equation for the source port
            [srceqs, sID] = getEqus(startSys, srcHandles(j), blocks, lhsTable, subsystem_rule, extraSupport);
            neqs = [neqs, srceqs]; % Equations involved in this block's equations
            equ = [equ ' ' sym ' (' sID ')']; % This block/port's equation with respect to its sources
        end
        
        neqs = [{equ}, neqs]; % Equations involved in this block's equations
    end
    function neqs = binaryLogicEqu2(sym, var2)
        assert(numInputs == 1);
        
        neqs = {}; % newEqus
        
        % Get the equation for the source port
        [srceqs, sID] = getEqus(startSys, srcHandles(1), blocks, lhsTable, subsystem_rule, extraSupport);
        neqs = [neqs, srceqs]; % Equations involved in this block's equations
        equ = [handleID ' = ' '(' sID ') ' sym ' (' var2 ')']; % Equation for the block/port so far
        neqs = [{equ}, neqs]; % Equations involved in this block's equations
    end
end