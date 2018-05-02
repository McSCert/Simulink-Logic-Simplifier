function newEqus = substituteEqus(equs, blocks, lhsTable, subsystem_rule)
% SUBSTITUTEEXPRS Substitute indicated equations into each other to
%   reduce the number of equations and so they can be better simplified.
%
%   Inputs:
%       equs   Cell array of equations to simplify.
%       blocks
%       lhsTable
%
%   Outputs:
%       newEqus

newEqus = equs;
removeIdx = zeros(1,length(equs));

% Get the left and right hand sides for each equation
lefts = cell(1,length(equs));
rights = cell(1,length(equs));
for i = 1:length(newEqus)
    [lhs, rhs] = getEquationLhsRhs(newEqus{i});
    lefts{i} = lhs;
    rights{i} = rhs;
end

% Get the block associated with each equation
equBlocks = cell(1,length(newEqus));
for i = 1:length(newEqus)
    equBlocks{i} = getBlock(lhsTable.lookdown(lefts{i}));
end

% Do substitutions
%   Don't perform the substitution 
%       if the equation being subbed in is not supposed to be simplified further, or 
%       if the equation being subbed into is not supposed to be simplified further.

for i = length(newEqus):-1:1
    if allowedToSubIntoOthers(lefts{i}, newEqus{i}, newEqus)
        % Substitute equation into other equations
        % Because it only subs into earlier equations there shouldn't be
        % any problems with redoing substitutions due to loops.
        for j = 1:length(newEqus)
            if allowedToBeSubbedInto(newEqus{i})
                idPat = ['(^|[^0-9A-Za-z_])(', lefts{i}, ')([^0-9A-Za-z_]|$)'];
                if regexp(rights{j}, idPat, 'ONCE') % lhs is in rhs of another equation
                    % Do substitution
                    rights{j} = regexprep(rights{j}, idPat, ['$1' '(' rights{i} ')' '$3']);
                    newEqus{j} = [lefts{j}, ' = ', rights{j}];
                    
                    % Record that this equation can ultimately be removed from
                    % the set of equations.
                    removeIdx(i) = 1;
                end
            end
        end
    end
end

% Remove unneeded equations
for i = length(newEqus):-1:1
    if removeIdx(i) == 1
%         % Don't actually remove if the equation is for a block in the
%         % original input.
%         if ~ismember(equBlocks{i},blocks)
%             newEqus(i) = [];
%         end
        newEqus(i) = [];
    end
end

end

function bool = allowedToSubIntoOthers(lhs, newEqu, newEqus)
% True if the equation with this LHS should be substituted into other
% equations.

% TODO: check if this is a neccessary restriction
% If lhs is in the rhs of a blackbox then don't sub into others
for i = 1:length(newEqus)
    idPat = ['(^|[^0-9A-Za-z_])(', lhs, ')([^0-9A-Za-z_]|$)'];
    if isBlackBoxEquation(newEqus{i})
        [~, rhsi] = getEquationLhsRhs(newEqus{i});
        if regexp(rhsi, idPat, 'ONCE') % The ith equation directly depends on lhs
            bool = false;
            return
        end
    end
end

if isBlackBoxEquation(newEqu)
    bool = false;
else
    bool = true;
end
end

function bool = allowedToBeSubbedInto(newEqu)
% True if the equation with this LHS may have other equations be 
% substituted into it.

if isBlackBoxEquation(newEqu)
    bool = false;
else
    bool = true;
end
end

% function bool = allowedToSubIntoOthers(lhs, newEqu, newEqus, SUBSYSTEM_RULE)
% % True if the equation with this LHS should be substituted into other
% % equations.
% 
% % If lhs is in the rhs of a blackbox then don't sub into others
% for i = 1:length(newEqus)
%     idPat = ['(^|[^0-9A-Za-z_])(', lhs, ')([^0-9A-Za-z_]|$)'];
%     if isBlackBoxEquation(newEqus{i})
%         [~, rhsi] = getEquationLhsRhs(newEqus{i});
%         if regexp(rhsi, idPat, 'ONCE') % The ith equation directly depends on lhs
%             bool = false;
%             return
%         end
%     end
% end
% 
% if isBlackBoxEquation(newEqu)
%     bool = false;
% else    
%     if strcmp(SUBSYSTEM_RULE, 'full-simplify')
%         % No restrictions on substitutions
%         bool = true;
%     elseif strcmp(SUBSYSTEM_RULE, 'part-simplify') || strcmp(SUBSYSTEM_RULE, 'blackbox')
%         % Don't substitute equations for subsystem out/inputs (implicit or explicit)
%         
%         % Check if its an out/input equation for a subsystem
%         %   output: I.e. lhs starts with 'SubSystem_port_'
%         %   input: I.e. lhs is 'Inport_port_Sub_#'
%         if ~isempty(regexp(lhs, '^SubSystem_port_', 'ONCE')) || ...
%                 ~isempty(regexp(lhs,'^Inport_port_Sub_', 'ONCE'))
%             bool = false;
%         else
%             bool = true;
%         end
%     else
%         error(['Error using ' mfilename ':' char(10) ...
%             ' invalid config parameter: subsystem_rule. Please fix in the config.txt.'])
%     end
% end
% 
% end

% function bool = allowedToBeSubbedInto(lhs, block, newEqu, SUBSYSTEM_RULE)
% % True if the equation with this LHS may have other equations be 
% % substituted into it.
% 
% if isBlackBoxEquation(newEqu)
%     bool = false;
% else
%     if strcmp(SUBSYSTEM_RULE, 'full-simplify')
%         % No restrictions on substitutions
%         bool = true;
%     elseif strcmp(SUBSYSTEM_RULE, 'part-simplify') || strcmp(SUBSYSTEM_RULE, 'blackbox')
%         % With action subsystems, the output equation is of form: A = B&C and
%         % simplifying this may modify the contents of the system. Thus these
%         % should not be subbed into.
%         % Similarly, for If/SwitchCase blocks, if the equation is changed
%         % unexpectedly, a new If/SwitchCase block may not be able to be created
%         % in the new model which would mess up the action subsystem. Thus these
%         % should not be subbed into.
%         
%         if isAction(block)
%             % It's an equation for an action subsystem
%             bool = false;
%         elseif ~isempty(regexp(lhs, '^If_port_', 'ONCE')) || ...
%                 ~isempty(regexp(lhs,'^SwitchCase_port_', 'ONCE'))
%             % It's an equation for an If/SwitchCase block
%             %   If: I.e. lhs starts with 'If_port_'
%             %   SwitchCase: I.e. lhs starts with 'SwitchCase_port_'
%             bool = false;
%         else
%             bool = true;
%         end
%     else
%         error(['Error using ' mfilename ':' char(10) ...
%             ' invalid config parameter: subsystem_rule. Please fix in the config.txt.'])
%     end
% end
% 
%     function bool = isAction(b)
%         ph = get_param(b,'PortHandles');
%         bool = ~isempty(ph.Ifaction);
%     end
% end