function subsIdx = whichExpressionsToSub(exprs)
% WHICHEXPRESSIONSTOSUB Determine which expressions should be substituted
%   into others.
%
%   Inputs:
%       exprs   Cell array of expressions to simplify.
%
%   Outputs:
%       subsIdx Array of 1/0s corresponding with whether each expression in
%               exprs with the same indices should be substituted into
%               others.

% Constants:
SUBSYSTEM_RULE = getLogicSimplifierConfig('subsystem_rule', 'blackbox'); % Indicates how to address subsystems in the simplification process

subsIdx = ones(1,length(exprs)); % Initialize with assumption that all should be substituted

if strcmp(SUBSYSTEM_RULE, 'full-simplify')
    % Do nothing,
    % Don't need to turn off the expressions that disturb the subsystems
elseif strcmp(SUBSYSTEM_RULE, 'part-simplify') || strcmp(SUBSYSTEM_RULE, 'blackbox')
    % Don't substitute expressions for subsystem out/inputs (implicit or explicit)
    
    % Find all expressions for subsystem out/inputs (implicit or explicit)
    subsysIdx = findSubsysExpressions(exprs);
    subsIdx = subsIdx & ~subsysIdx;
else
    error(['Error using ' mfilename ':' char(10) ...
        ' invalid config parameter: subsystem_rule. Please fix in the config.txt.'])
end

% Also exclude expressions based on loops
loopIdx = findLoopRoots(exprs); % 'root' is not well defined because it is a loop...
subsIdx = subsIdx & ~loopIdx;

end

function subsysIdx = findSubsysExpressions(exprs)

subsysIdx = zeros(1,length(exprs)); % Initialize with assumption that none are subsystem expressions

for i = 1:length(exprs)
    [lhs, ~] = getExpressionLhsRhs(exprs{i});
    
    % Check if its an output expression for a subsystem
    %   I.e. lhs starts with 'SubSystem_port_'
    if ~isempty(regexp(lhs, '^SubSystem_port_', 'ONCE'))
        subsysIdx(i) = 1;
        continue
    end
    
    % Check if its an input expression for a subsystem
    %   I.e. lhs is 'Inport_port_Sub_#'
    if ~isempty(regexp(lhs,'^Inport_port_Sub_', 'ONCE'))
        subsysIdx(i) = 1;
        continue
    end
    
    %% TODO: check if implicit out/inputs
end
end

function loopIdx = findLoopRoots(exprs)
%% TODO
%Current implementation is completely temporary

loopIdx = zeros(1,length(exprs));
end