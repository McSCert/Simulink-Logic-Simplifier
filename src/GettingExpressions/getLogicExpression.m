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