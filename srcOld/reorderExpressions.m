function exprs = reorderExpressions(startSystem, exprs, predicates)
%
% Reorder expressions based on the LHS of each expression
%   First sort by lowest depth with respect to the starting system
%   (startSystem depth = 0).
%   Then blocks go before ports.
%   Then ports for inport blocks go last.
%   Then lowest port number for ports goes first.

% Using a bubblesort approach
n = length(exprs);
cont = true;
while cont
    cont = false;
    for i = 2:n
        bool = checkPriority2Greater1(exprs{i-1},exprs{i});
        
        if bool % Current expression has higher priority than previous
            % Swap
            temp = exprs{i-1};
            exprs{i-1} = exprs{i};
            exprs{i} = temp;
            
            % Remember there was a swap
            cont = true;
        end
    end
end

    function bool = checkPriority2Greater1(expr1,expr2)
        % Checks if priority of expr2 is greater than the priority of expr1
        
        %   Lowest depth takes highest priority.
        %   handletype of block is higher priority than port.
        %   If handleType is port, then Inport blocks have lowest priority
        %   If handleType is port, then lowest port number has highest priority.
        
        sort1 = getSortingParameters(startSystem, expr1, predicates);
        sort2 = getSortingParameters(startSystem, expr2, predicates);
        
        if sort2.depth < sort1.depth
            bool = true;
            return
        elseif sort2.depth > sort1.depth
            bool = false;
            return
        end
        assert(sort2.depth == sort1.depth)
        
        if strcmp(sort2.handletype,'block') && ~strcmp(sort1.handletype,'block')
            bool = true;
            return
        elseif strcmp(sort1.handletype,'block') && ~strcmp(sort2.handletype,'block')
            bool = false;
            return
        end
        assert(strcmp(sort2.handletype,sort1.handletype))
        
        if strcmp(sort2.handletype, 'block')
            % Equal priority, expr2 not strictly greater so return false
            bool = false;
            return
        end
        assert(strcmp(sort1.handletype, 'port') && strcmp(sort2.handletype, 'port'))
        
        if strcmp(sort2.blocktype,'Inport')
            % expr2 has less or equal priority; return false
            % if expr1 is also an Inport, then they tie in port number and
            % thus tie overall
            bool = false;
            return
        elseif strcmp(sort1.blocktype,'Inport')
            % expr2 has greater priority because it is not an Inport
            bool = true;
            return
        end
        
        if sort2.portnumber < sort1.portnumber
            bool = true;
            return
        else
            bool = false;
            return
        end
        
    end
end

function sortingParams = getSortingParameters(startSystem, expr, predicates)
[lhs, ~] = getExpressionLhsRhs(expr);
handle = getKeyFromVal(predicates, lhs);

% Determine if lhs is for a block or a port
handleType = get_param(handle,'Type');

% Get the block
if strcmp(handleType, 'block')
    block = getfullname(handle);
elseif strcmp(handleType, 'port')
    block = get_param(handle, 'Parent');
end

% Get block type
blockType = get_param(block, 'BlockType');

% Get depth of the block
depth = getDepth(startSystem, block);

% If handle type is port, get port number
if strcmp(handleType, 'port')
    pNum = get_param(handle, 'PortNumber');
else
    pNum = 0; % Default that we'll use for blocks
end

sortingParams = struct(...
    'depth',depth, ...
    'handletype',handleType, ...
    'blocktype',blockType, ...
    'portnumber', pNum);
end