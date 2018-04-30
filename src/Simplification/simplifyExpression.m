function expr = simplifyExpression(expr)
    % SIMPLIFYEXPRESSION Simplifies a given expression.
    %   Notes: 'simple' is ill defined so results may not be strictly
    %           'simpler'.
    %           Expression must be of an appropriate form (TODO: define
    %           this form).
    %
    %   Inputs:
    %       expr    A string representing an expression. A symbolic
    %               expression in MATLAB will work.
    %
    %   Outputs:
    %       expr    A simplified form of the original expression.
    
    % Tests:
    %   simplifyExpression('3')
    %   simplifyExpression('true')
    %   simplifyExpression('TRUE')
    %   simplifyExpression('true == 1')
    %   simplifyExpression('true == TRUE')
    %   simplifyExpression('x')
    %   simplifyExpression('A&~A')
    %   simplifyExpression('~(A <= 1)')
    
    %% Modify the form of expr for the actual simplification
    
    % TODO - get rid of this
    % When does this trigger? should the input ever have this?
	%	Consider different versions of MATLAB (esp. 2011b)
    assert(isempty(strfind(expr, '<>')), 'Assertion triggered for debugging')
    
    % Swap operators for MATLAB equivalents
    expr = strrep(expr,'<>','~=');
    
    % Evaluate parts that MATLAB can already evaluate
    truePat = identifierPattern('TRUE');
    falsePat = identifierPattern('FALSE');
    expr = regexprep(expr, truePat, '1'); % Replace TRUE/FALSE with 1/0 so that MATLAB can evaluate them
    expr = regexprep(expr, falsePat, '0');
    expr = evaluateConstOps(expr);
    
    % Add brackets to remove potential ambiguity
    expr = bracketForPrecedence(expr, true);
    expr = removeSpareBrackets(expr); % Removing brackets for easier debugging
    
    % Swap logical 1/0 for TRUE/FALSE (determine if 1/0 is logical from context)
    % This is done because symengine will assume 1/0 are numerical
    expr = makeBoolsTorF(expr,'upper');
    
    %% Perform the simplification
    expr = lsSimplify(expr);
    
    %% Do final bracketing so that precedence does not need to be considered
    % in other functions
    expr = bracketForPrecedence(expr, true);
    expr = removeSpareBrackets(expr); % Cleaning up excess brackets
end

function newExpr = lsSimplify(expr)
    [~, ids] = getIdentifiers(expr);
    idMap = containers.Map(); % idMap maps from identifiers to expressions they represent
    initMappings = cell(1,length(ids)); initMappings(:) = {''};
    % Add ids to idMap with empty values to indicate that an id doesn't represent anything
    addCells2Map(idMap,ids,initMappings);
    
    % Simplify and when new ids are added to idMap, also add the simplified
    % expression they represent.
    newExpr = lsSimplifyAux(expr, idMap);
    
    % Swap ids in idMap for the expression they represent
    for i = 1:length(idMap.keys)
        key = idMap.keys; key = key{i}; % key = ith key
        value = idMap(key);
        if ~strcmp(value, '')
            newExpr = regexprep(newExpr, ['(^|\W)' key '(\W|$)'], ['(' value ')']); % match identifier when the character before and after isn't valid in an identifier
        end
    end
end

function newExpr = lsSimplifyAux(expr, idMap)
    
    % Notes of things to account for:
    % (X>Y) == ((X~=Y) & (~(Y>X))) or equivalently ((X>Y)&(Y>X))==False
    % (X<2)&(1>X) -> X<1
    
%     if strcmp(expr(1), '(') && findMatchingParen(expr, 1) == length(expr)
%         % expr is of form "(subexpr)", so run lsSimplify(subexpr)
%         newExpr = lsSimplifyAux(expr(2:end-1), idMap);
%     elseif strcmp(expr(1), '~')
%         % expr is of form "~subexpr"
%         % (due to bracketing, "~subexpr op subexpr" should not be possible)
%         %   mSimplify(~lsSimplify(subexpr))
%         subexpr = lsSimplifyAux(expr(2:end), idMap);
%         newExpr = mSimplify(~subexpr, idMap);
%     else
%         % expr is of form "subexpr1 op subexpr2"
%         % if op is relational {<,>,<=,>=,==,~=}:
%         %   relSimplify(lsSimplify(subexpr1) op lsSimplify(subexpr2))
%         % else op is not relational {&,|}:
%         %   mSimplify(lsSimplify(subexpr1) op lsSimplify(subexpr2))
%         
%         startIdx = getNextOp(expr);
%         
%         rhsIdx = match + regexp(expr(match+1:end), '(^[\s~=><&\|]*)', 'end'); % Index before the right-hand side subexpression starts
%         tok = regexp(expr(match+1:rhsIdx), '([~=><&\|]*)', 'tokens'); % Captures operators (and other cases using the same symbols)
%         assert(length(tok)==1, 'Pattern match failed; unexpected expression pattern.')
%         assert(length(tok{1})==1, 'Pattern match failed; unexpected expression pattern.')
%         op = tok{1}{1};
%         isRelOp = ~isempty(regexp(op, '^(>|>=|<|<=|==|~=)$', 'once')); % Checks if op is a relational operator
%         
%         lhs = lsSimplifyAux(expr(2:match-1), idMap); % Might be more efficient to do this in the simplification functions in case these don't need to be computed
%         rhs = lsSimplifyAux(expr(rhsIdx+1:end), idMap);
%         if isRelOp
%             newExpr = relSimplify(lhs, op, rhs, idMap);
%         else
%             newExpr = mSimplify([lhs op rhs], idMap);
%         end
%     end
    
    switch expr(1)
        case '('
            match = findMatchingParen(expr, 1);
            if match == length(expr)
                % expr is of form "(subexpr)", so run lsSimplify(subexpr)
                newExpr = lsSimplifyAux(expr(2:end-1), idMap);
            else
                % expr is of form "(subexpr1)op(subexpr2)"
                % if op is relational {<,>,<=,>=,==,~=}:
                %   relSimplify(lsSimplify(subexpr1) op lsSimplify(subexpr2))
                % else op is not relational {&,|}:
                %   mSimplify(lsSimplify(subexpr1) op lsSimplify(subexpr2))
                
                [startIdx, endIdx] = findNextOp(expr);
                assert(startIdx ~= 0 && endIdx ~= 0)
                op = expr(startIdx:endIdx);
                assert(~strcmp(op,'~'))
                isRelOp = ~isempty(regexp(op, '^(>|>=|<|<=|==|~=)$', 'once')); % Checks if op is a relational operator
                
                rhsIdx = endIdx + 1; % Index where the right-hand side subexpression starts
                
                lhs = lsSimplifyAux(expr(2:startIdx-1), idMap); % Might be more efficient to do this in the simplification functions in case these don't need to be computed
                rhs = lsSimplifyAux(expr(rhsIdx:end), idMap);
                if isRelOp
                    newExpr = relSimplify(lhs, op, rhs, idMap);
                else
                    newExpr = mSimplify([lhs op rhs], idMap);
                end
            end
        case '~'
            % expr is of form "~subexpr"
            % (due to bracketing, "~subexpr op subexpr" should not be possible)
            %   mSimplify(~lsSimplify(subexpr))
            subexpr = lsSimplifyAux(expr(2:end), idMap);
            newExpr = mSimplify(~subexpr, idMap);
        otherwise
            % expr is an identifier or value - no simplification available
            
			% Assert that expr is just an identifier/value
			assert(~isempty(regexp(expr, '^\s*\w*\s*$', 'once')), 'Expression of unexpected form.');
			
			newExpr = expr;
    end
    
    % % Let MATLAB simplify the expression as a condition
    % prev = expr; % Can use this to check equivalence between steps
    % expr = evalin(symengine, ['simplify(' prev ', condition)']);
    % expr = char(expr); % Convert from symbolic type to string
    % % Note the above converts 'X == 1 | X == 2' to 'X in {1, 2}'
    
    % Let MATLAB simplify the expression as a logical expression
    %prev = expr; % Can use this to check equivalence between steps
    %expr = evalin(symengine, ['simplify(' prev ', logic)']);
    %expr = char(expr); % Convert from symbolic type to string
    
    % %Let MATLAB simplify the expression using a different function
    % prev = expr; % Can use this to check equivalence between steps
    % expr = evalin(symengine, ['Simplify(' prev ')']);
    % expr = char(expr); % Convert from symbolic type to string
end

function newExpr = relSimplify(lhs, op, rhs, idMap)
    
    expr = [lhs, op, rhs];
    
    % Get unique identifiers for lhs and rhs
    lhsId = getNewId(idMap.keys);
    idMap(lhsId) = lhs;
    rhsId = getNewId(idMap.keys);
    idMap(rhsId) = rhs;
    
    % TODO
    % Try to simply expr
    % Compare lhs and rhs logically
    % E.g. if lhs = 'X<Y' and rhs = 'Y>X', then we can use a
    % single id to better simplify
    
    % if op has been simplified out, then return the full simplification
    % else return with unique id since mSimplify may produce unexpected
    %   results for relational operators
    id = getNewId(idMap.keys);
    idMap(id) = [lhs, op, rhs];
    
    newExpr = id; % id will later be replaced with idMap(id)
end

function newExpr = mSimplify(expr, idMap)
    
    newExpr = expr;
    
    % Swap functions (swap4Symengine and swap4Simulink) don't appear to be
    % needed for the current simplify function being used - however, the
    % function will error in older versions.
    
    % Swap out MATLAB symbols for ones that symengine uses
%     expr = swap4Symengine(expr);

    % MATLAB simplify
    identifiers = getIdentifiers(newExpr);
    eval(['syms ' identifiers]);
    try
        newExpr = eval(['simplify( ', newExpr, ', ''Steps'', 100 )']);
        newExpr = char(newExpr);
    catch ME
        if ~strcmp(ME.identifier, 'MATLAB:UndefinedFunction')
            rethrow(ME);
        end % else expr should be fully simplified already
    end
    
    %Swap symbols back
%     expr = swap4Simulink(expr);
    % newExpression = strrep(newExpression, '=', '=='); % is this needed for newer versions for some reason? % should have to use the same regexprep line that the older version uses at least
    
    % Swap out special MuPAD operations
    % References:
    % https://www.mathworks.com/help/symbolic/operators-1.html
    % https://www.mathworks.com/help/matlab/matlab_prog/operator-precedence.html
    % https://www.mathworks.com/help/symbolic/mupad_ref/in.html
    
    % Swap out 'in {...}':
    newExpr = swapIn(newExpr);
    
    newExpr = ['(' newExpr ')'];
end

function expr = swapIn(expr)
    % Swap out 'in {...}':
    % While we find 'in {...}',
    % Pattern is Case 1: 'X in {...} ...' or Case 2: '... ( Case 1 ) ...'
    % Replace Case 1 with: '((X == (...)) | (X == (...)) | ...) ...'
    
    inPat = '(in)[\s]*{([^}]*)}';
    while ~isempty(regexp(expr, '(in)[\s]*{([^}]*)}', 'once'))
        te = regexp(expr, inPat, 'tokenExtents', 'once');
        index = findUnclosedBracket(expr(1:te(1,1)-1));
        inSet = strsplit(expr(te(2,1):te(2,2)), ',\s*|,', 'DelimiterType', 'RegularExpression');
        X = expr(index+1:te(1,1)-1);
        
        replaceTxt = ['(((' X ') == (' inSet{1} '))']; % note 1 bracket unclosed
        for j = 2:length(inSet)
            replaceTxt = [replaceTxt ' | ((' X ') == (' inSet{j} '))'];
        end
        replaceTxt = [replaceTxt ')'];
        
        expr = [expr(1:index) replaceTxt expr(te(2,2)+2:end)]; % +2 to go to next char and skip the '}'
    end
    
    function idx = findUnclosedBracket(str)
        % Find the index of the rightmost unclosed open bracket, '('
        % Return idx == 0 if there is no unclosed '('
        count = 0; % Running count of found close brackets, ')'
        for i = length(str):-1:1
            if strcmp(str(i),'(')
                if count == 0
                    idx = i;
                    return
                else
                    count = count - 1;
                end
            elseif strcmp(str(i),')')
                count = count + 1;
            end
        end
        assert(~exist('idx', 'var'), 'Something went wrong.') % This function should end when idx is set
        idx = 0;
    end
end

function expr = swap4Symengine(expr)
    
    if ~isLsNewerVer()
        expr = strrep(expr, '~=', '<>'); % This line must go before the unary negation swap
        expr = strrep(expr, '~', ' not ');
        expr = strrep(expr, '==', '=');
        expr = strrep(expr, '&', ' and ');
        expr = strrep(expr, '|', ' or ');
    end
end

function expr = swap4Simulink(expr)
    
    if ~isLsNewerVer()
        expr = regexprep(expr, '(^|\s) not \s', '~');
        expr = strrep(expr, ' or ', '|'); % Without the spaces 'or' could be part of a variable name
        expr = strrep(expr, ' and ', '&');
        expr = regexprep(expr, '(^|[^<>~=])(=)([^=]|$)', '$1$2$2$3'); % if an = is not in <=, >=, ~=, ==, then replace = with ==
        expr = regexprep(expr, '(^|[^A-Za-z_])not\s', '$1~'); % This replaces not with ~ and makes sure not isn't a part of a variable name
        %     expr = strrep(expr, ' not ', '~');
        expr = strrep(expr, '<>', '~=');
    end
end