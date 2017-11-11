function newExprs = substituteExprs(exprs, blocks, lhsTable, subsystem_rule)
% SUBSTITUTEEXPRS Substitute indicated expressions into each other to
%   reduce the number of expressions and so they can be better simplified.
%
%   Inputs:
%       exprs   Cell array of expressions to simplify.
%       blocks
%       lhsTable
%
%   Outputs:
%       newExprs

newExprs = exprs;
removeIdx = zeros(1,length(exprs));

% Get the left and right hand sides for each expression
lefts = cell(1,length(exprs));
rights = cell(1,length(exprs));
for i = 1:length(newExprs)
    [lhs, rhs] = getExpressionLhsRhs(newExprs{i});
    lefts{i} = lhs;
    rights{i} = rhs;
end

% Get the block associated with each expression
exprBlocks = cell(1,length(newExprs));
for i = 1:length(newExprs)
    exprBlocks{i} = getBlock(lhsTable.lookdown(lefts{i}));
end

% Do substitutions
%   Don't perform the substitution 
%       if the expression being subbed in is not supposed to be simplified further, or 
%       if the expression being subbed into is not supposed to be simplified further.

for i = length(newExprs):-1:1
    if allowedToSubIntoOthers(lefts{i}, newExprs{i}, newExprs)
        % Substitute expression into other expressions
        % Because it only subs into earlier expressions there shouldn't be
        % any problems with redoing substitutions due to loops.
        for j = 1:length(newExprs)
            if allowedToBeSubbedInto(newExprs{i})
                idPat = ['(^|[^0-9A-Za-z_])(', lefts{i}, ')([^0-9A-Za-z_]|$)'];
                if regexp(rights{j}, idPat, 'ONCE') % lhs is in rhs of another expression
                    % Do substitution
                    rights{j} = regexprep(rights{j}, idPat, ['$1' '(' rights{i} ')' '$3']);
                    newExprs{j} = [lefts{j}, ' = ', rights{j}];
                    
                    % Record that this expression can ultimately be removed from
                    % the set of expressions.
                    removeIdx(i) = 1;
                end
            end
        end
    end
end

% Remove unneeded expressions
for i = length(newExprs):-1:1
    if removeIdx(i) == 1
%         % Don't actually remove if the expression is for a block in the
%         % original input.
%         if ~ismember(exprBlocks{i},blocks)
%             newExprs(i) = [];
%         end
        newExprs(i) = [];
    end
end

end

function bool = allowedToSubIntoOthers(lhs, newExpr, newExprs)
% True if the expression with this LHS should be substituted into other
% expressions.

% TODO: check if this is a neccessary restriction
% If lhs is in the rhs of a blackbox then don't sub into others
for i = 1:length(newExprs)
    idPat = ['(^|[^0-9A-Za-z_])(', lhs, ')([^0-9A-Za-z_]|$)'];
    if isBlackBoxExpression(newExprs{i})
        [~, rhsi] = getExpressionLhsRhs(newExprs{i});
        if regexp(rhsi, idPat, 'ONCE') % The ith expression directly depends on lhs
            bool = false;
            return
        end
    end
end

if isBlackBoxExpression(newExpr)
    bool = false;
else
    bool = true;
end
end

function bool = allowedToBeSubbedInto(newExpr)
% True if the expression with this LHS may have other expressions be 
% substituted into it.

if isBlackBoxExpression(newExpr)
    bool = false;
else
    bool = true;
end
end

% function bool = allowedToSubIntoOthers(lhs, newExpr, newExprs, SUBSYSTEM_RULE)
% % True if the expression with this LHS should be substituted into other
% % expressions.
% 
% % If lhs is in the rhs of a blackbox then don't sub into others
% for i = 1:length(newExprs)
%     idPat = ['(^|[^0-9A-Za-z_])(', lhs, ')([^0-9A-Za-z_]|$)'];
%     if isBlackBoxExpression(newExprs{i})
%         [~, rhsi] = getExpressionLhsRhs(newExprs{i});
%         if regexp(rhsi, idPat, 'ONCE') % The ith expression directly depends on lhs
%             bool = false;
%             return
%         end
%     end
% end
% 
% if isBlackBoxExpression(newExpr)
%     bool = false;
% else    
%     if strcmp(SUBSYSTEM_RULE, 'full-simplify')
%         % No restrictions on substitutions
%         bool = true;
%     elseif strcmp(SUBSYSTEM_RULE, 'part-simplify') || strcmp(SUBSYSTEM_RULE, 'blackbox')
%         % Don't substitute expressions for subsystem out/inputs (implicit or explicit)
%         
%         % Check if its an out/input expression for a subsystem
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

% function bool = allowedToBeSubbedInto(lhs, block, newExpr, SUBSYSTEM_RULE)
% % True if the expression with this LHS may have other expressions be 
% % substituted into it.
% 
% if isBlackBoxExpression(newExpr)
%     bool = false;
% else
%     if strcmp(SUBSYSTEM_RULE, 'full-simplify')
%         % No restrictions on substitutions
%         bool = true;
%     elseif strcmp(SUBSYSTEM_RULE, 'part-simplify') || strcmp(SUBSYSTEM_RULE, 'blackbox')
%         % With action subsystems, the output expression is of form: A = B&C and
%         % simplifying this may modify the contents of the system. Thus these
%         % should not be subbed into.
%         % Similarly, for If/SwitchCase blocks, if the expression is changed
%         % unexpectedly, a new If/SwitchCase block may not be able to be created
%         % in the new model which would mess up the action subsystem. Thus these
%         % should not be subbed into.
%         
%         if isAction(block)
%             % It's an expression for an action subsystem
%             bool = false;
%         elseif ~isempty(regexp(lhs, '^If_port_', 'ONCE')) || ...
%                 ~isempty(regexp(lhs,'^SwitchCase_port_', 'ONCE'))
%             % It's an expression for an If/SwitchCase block
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