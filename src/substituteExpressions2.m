function newExprs = substituteExpressions2(exprs, blocks, predicates)
% SUBSTITUTEEXPRESSIONS Substitute indicated expressions into each other to
%   reduce the number of expressions and so they can be better simplified.
%
%   Inputs:
%       exprs   Cell array of expressions to simplify.
%       blocks
%       predicates
%
%   Outputs:
%       newExprs

%% TODO - Modify for loops

% Constants:
SUBSYSTEM_RULE = getLogicSimplifierConfig('subsystem_rule', 'blackbox'); % Indicates how to address subsystems in the simplification process

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
exprBlocks = cell(1,length(exprs));
for i = 1:length(newExprs)
    handle = getKeyFromVal(predicates, lefts{i});
    
    handleType = get_param(handle,'Type');

    % Get the block
    if strcmp(handleType, 'block')
        exprBlocks{i} = getfullname(handle);
    elseif strcmp(handleType, 'port')
        exprBlocks{i} = get_param(handle, 'Parent');
    end
end

% Do substitutions
%   Don't perform the substitution if the expression being subbed in is not
%   supposed to be simplified further, or if the expression being subbed
%   into is not supposed to be simplified further.

% cont = true;
% while cont
%     cont = false;
for i = length(newExprs):-1:1
    if allowedToSubIntoOthers(lefts{i}, SUBSYSTEM_RULE)
        % Substitute expression into other expressions
        % Because it only subs into earlier expressions there shouldn't be
        % any problems with redoing substitutions due to loops.
        for j = 1:length(newExprs)
            if allowedToBeSubbedInto(lefts{j}, exprBlocks{j}, SUBSYSTEM_RULE)
                idPat = ['(^|[^0-9A-z_])(', lefts{i}, ')([^0-9A-z_]|$)'];
                if regexp(rights{j}, idPat, 'ONCE') % lhs is in rhs of another expression
                    % Do substitution
                    rights{j} = regexprep(rights{j}, idPat, ['$1' '(' rights{i} ')' '$3']);
                    newExprs{j} = [lefts{j}, ' = ', rights{j}];
                    
%                     cont = true;
                    
                    % This expression can ultimately be removed from the
                    % set of expressions; record that.
                    removeIdx(i) = 1;
                end
            end
        end
    end
end
% end

% Remove unneeded expressions
for i = length(newExprs):-1:1
    if removeIdx(i) == 1
        % Don't actually remove if the expression is for a block in the
        % original input.
        if ~ismember(exprBlocks{i},blocks)
            newExprs(i) = [];
        end
    end
end

end

function bool = allowedToSubIntoOthers(lhs, SUBSYSTEM_RULE)
% True if the expression with this LHS should be substituted into other
% expressions.

if strcmp(SUBSYSTEM_RULE, 'full-simplify')
    % No restrictions on substitutions
    bool = true;
elseif strcmp(SUBSYSTEM_RULE, 'part-simplify') || strcmp(SUBSYSTEM_RULE, 'blackbox')
    % Don't substitute expressions for subsystem out/inputs (implicit or explicit)
    
    % Check if its an out/input expression for a subsystem
    %   output: I.e. lhs starts with 'SubSystem_port_'
    %   input: I.e. lhs is 'Inport_port_Sub_#'
    if ~isempty(regexp(lhs, '^SubSystem_port_', 'ONCE')) || ...
            ~isempty(regexp(lhs,'^Inport_port_Sub_', 'ONCE'))
        bool = false;
    else
        bool = true;
    end
else
    error(['Error using ' mfilename ':' char(10) ...
        ' invalid config parameter: subsystem_rule. Please fix in the config.txt.'])
end

%% TODO - Also exclude expressions based on loops

end

function bool = allowedToBeSubbedInto(lhs, block, SUBSYSTEM_RULE)
% True if the expression with this LHS may have other expressions be 
% substituted into it.

if strcmp(SUBSYSTEM_RULE, 'full-simplify')
    % No restrictions on substitutions
    bool = true;
elseif strcmp(SUBSYSTEM_RULE, 'part-simplify') || strcmp(SUBSYSTEM_RULE, 'blackbox')
    % With action subsystems, the output expression is of form: A = B&C and
    % simplifying this may modify the contents of the system. Thus these
    % should not be subbed into.
    % Similarly, for If/SwitchCase blocks, if the expression is changed 
    % unexpectedly, a new If/SwitchCase block may not be able to be created 
    % in the new model which would mess up the action subsystem. Thus these
    % should not be subbed into.
    
    if isAction(block)
        % It's an expression for an action subsystem
        bool = false;
    elseif ~isempty(regexp(lhs, '^If_port_', 'ONCE')) || ...
            ~isempty(regexp(lhs,'^SwitchCase_port_', 'ONCE'))
        % It's an expression for an If/SwitchCase block
        %   If: I.e. lhs starts with 'If_port_'
        %   SwitchCase: I.e. lhs starts with 'SwitchCase_port_'
        bool = false;
    else
        bool = true;
    end
else
    error(['Error using ' mfilename ':' char(10) ...
        ' invalid config parameter: subsystem_rule. Please fix in the config.txt.'])
end

%% TODO - Also exclude expressions based on loops

    function bool = isAction(b)
        ph = get_param(b,'PortHandles');
        bool = ~isempty(ph.Ifaction);
    end
end