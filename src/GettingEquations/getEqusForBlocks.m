function equs = getEqusForBlocks(startSys, blocks, sysBlocks, lhsTable, subsystem_rule, extraSupport)
% GETEQUSFORBLOCKS Create a list of equations which represent the
%   logical values of a port/block within startSys based on their inputs.
%   Together these equations can be used to represent the whole system.
%   It's not feasible to simply represent anything, supported block and mask
%   types are listed in isSupportedBlockType.m and isSupportedMaskType.m
%   respectively. Unsupported situations are simply treated like a blackbox
%   and the resulting equation will be blackbox (i.e. the equation will
%   indicate that the relationship from lhs to rhs is unknown, but the
%   dependencies will still be represented on the rhs.
%
%   Inputs:
%       startSys    Starting system
%       blocks      Blocks we want equations for. Other blocks will be
%                   treated as blackboxes (we still generate an equation for 
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
%                   equations.
%
%   Outputs:
%       equs       List of equations. Cell array of chars.

% for each b in sysBlocks
%   if b has no outports
%       get equations for b
%   else
%       for each o in outports of b, get equations for o

equs = {};
for i = 1:length(sysBlocks)
    % Get outports
    ports = get_param(sysBlocks{i}, 'PortHandles');
    dstPorts = ports.Outport;
    
    if isempty(dstPorts)
        [newEqus, ~] = getEqus(startSys, get_param(sysBlocks{i}, 'Handle'), blocks, lhsTable, subsystem_rule, extraSupport);
        equs = [equs, newEqus];
    else
        for j = 1:length(dstPorts)
            [newEqus, ~] = getEqus(startSys, dstPorts(j), blocks, lhsTable, subsystem_rule, extraSupport);
            equs = [equs, newEqus];
        end
    end
end
end