function [newEqus, handleID] = getIfEqu(startSys, h, handleID, blocks, lhsTable, subsystem_rule, extraSupport)
% GETIFEQU Parse the conditions of the if block in order to produce a logical
%   equation indicative of the if block.
%   Assumed that subsystem_rule is 'full_simplify', for other cases If blocks
%   should actually be treated as blackbox because of the way they interact
%   with SubSystems.
%
%   Inputs:
%       startSys        Starting system.
%       h               Handle of a block to find an equation for.
%       handleID        Char array representation for h used in equations.
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
%       handleID    Char array representation for h used in equations. (This
%                   never gets set - will be removed in a future version)
%

    blk = getBlock(h);

    % Get the expressions in the if block
    portNum = get_param(h, 'PortNumber');
    expressions = get_param(blk, 'ElseIfExpressions');
    if ~isempty(expressions)
        expressions = regexp(expressions, ',', 'split');
        expressions = [{get_param(blk, 'IfExpression')}, expressions];
    else
        expressions = {};
        expressions{end + 1} = get_param(blk, 'IfExpression');
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

    newEqus = {};

    % Swap out u1, u2, ..., un for the appropriate source
    inPorts = get_param(blk, 'PortHandles');
    inPorts = inPorts.Inport;
    conditionIndices = regexp(exprOut, 'u[0-9]+');
    for i = 1:length(conditionIndices)
        backIndex = length(exprOut) - conditionIndices(i);
        condition = regexp(exprOut(length(exprOut)-backIndex:end), '^u[0-9]+', 'match');
        condition = condition{1};
        condNum = condition(2:end); % Also the port number
        srcHandle = inPorts(str2double(condNum));

        % Get the equation for the source
        [srcEqus, srcID] = getEqus(startSys, srcHandle, blocks, lhsTable, subsystem_rule, extraSupport);

        ifExpr = [ifExpr(1:end-backIndex-1) '(' srcID ')' ifExpr(end-backIndex+length(condition):end)]; % This block/port's equation with respect to its sources
        newEqus = [newEqus, srcEqus]; % Equations involved in this block's equations
    end

    equ = [handleID ' = ' ifExpr];
    newEqus = [{equ}, newEqus]; % Equations involved in this block's equations
end