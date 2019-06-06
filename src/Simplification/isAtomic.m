function b = isAtomic(expr)
% ISATOMIC Find if expression is considered atomic.
%
%   Inputs:
%       expr    Identifier, numeric value, true/TRUE, or false/FALSE.
%
%   Outputs:
%       b       Logical indicating if expr is atomic.
    
    % If there is no non-word character, then it is atomic.
    b = isempty(regexp(expr,'\W','once'));
end