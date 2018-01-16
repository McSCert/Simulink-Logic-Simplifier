function exprs = getExprsForBlocks(startSys, blocks, sysBlocks, lhsTable, subsystem_rule, extraSupport)
% GETEXPRSFORBLOCKS Create a list of expressions which represent the
%   logical values of a port/block within startSys based on their inputs.
%   Together these expressions can be used to represent the whole system.
%   It's not feasible to simply represent anything, supported block and mask
%   types are listed in isSupportedBlockType.m and isSupportedMaskType.m
%   respectively. Unsupported situations are simply treated like a blackbox
%   and the resulting expression will be blackbox (i.e. the expression will
%   indicate that it's value is unknown, but if there are inputs those will
%   be represented).
%
%   Inputs:
%       startSys    Starting system
%       blocks      Blocks we want expressions for. Other blocks will be
%                   treated as blackboxes (we still generate an expression for 
%                   blackboxes, but they will be treated differently).
%       sysBlocks   All blocks in the startSys. May include blocks within
%                   subsystems (depends on subsystem_rule).
%       subsystem_rule  Rule about how to treat subsystems, see the logic
%                       simplifier config file for details.
%       extraSupport    A function which is checked to provide support for
%                       extra block types.
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
%       for each o in outports of b, get expressions for o

exprs = {};
for i = 1:length(sysBlocks)
    % Get outports
    ports = get_param(sysBlocks{i}, 'PortHandles');
    dstPorts = ports.Outport;
    
    if isempty(dstPorts)
        [newExprs, ~] = getExprs(startSys, get_param(sysBlocks{i}, 'Handle'), blocks, lhsTable, subsystem_rule, extraSupport);
        exprs = [exprs, newExprs];
    else
        for j = 1:length(dstPorts)
            [newExprs, ~] = getExprs(startSys, dstPorts(j), blocks, lhsTable, subsystem_rule, extraSupport);
            exprs = [exprs, newExprs];
        end
    end
end
end