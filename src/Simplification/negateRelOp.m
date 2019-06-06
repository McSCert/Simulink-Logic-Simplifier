function nop = negateRelOp(op)
% NEGATERELOP Get the single operator that could be used in place of the given
%   operator to give equivalent results to the negation to the parent
%   expression.
%   E.g. For parent expression A ~= B call negateRelOp('~='), the single
%   operator that can be used in place of the given operator ~= to give
%   equivalent results to the negation of the parent expression (i.e. ~(A ~= B))
%   is ==. In other words the output of == means that ~(A ~= B) is equivalent to
%   A == B.
%   Exception is made for operators that cannot be negated in this way,
%   in these cases op is simply returned.
%
%   Inputs:
%       op      Char array of a relational operator. Options are: 
%               {'<=', '<', '>=', '>', '==', '~='}.
%
%   Outputs:
%       nop     Char array of the negated operator such that:
%               ~(A op B) is equivalent to (A nop B).
%
    switch op
        case '<='
            nop = '>';
        case '<'
            nop = '>=';
        case '>='
            nop = '<';
        case '>'
            nop = '<=';
        case '=='
            nop = '~=';
        case '~='
            nop = '==';
        otherwise
            % If input isn't an operator that can be negated, we'll just
            % return op
            nop = op;
    end
end