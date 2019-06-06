function newEqus = substituteEqus(equs, blocks, lhsTable, subsystem_rule)
% SUBSTITUTEEXPRS Substitute indicated equations into each other to
%   reduce the number of equations and so they can be better simplified.
%
%   Inputs:
%       equs            Cell array of equations to simplify.
%       blocks          Blocks to not treat as blackbox while finding an
%                       equation for h. (To be removed in a future version)
%       lhsTable        A BiMap object (see BiMap.m) that records object handles
%                       and their representation within equations. The BiMap is
%                       updated with new handles and their representations as
%                       equations for them are found.
%                       - This function should not update lhsTable.
%       subsystem_rule  A config option indicating how to address subsystems in 
%                       the simplification process. (To be removed in a future
%                       version)
%
%   Outputs:
%       newEqus         Equations created from the substitutions.
%
    
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