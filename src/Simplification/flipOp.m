function fop = flipOp(op)
% FLIPOP 'Flip' an operator such that its inputs need to be given in reverse
%   order to give the same results. If there is no valid flip then the same
%   operator is returned.
%
%   Inputs:
%       op      Char array of an operator. Options are: 
%               {'<=', '<', '>=', '>', '==', '~=', '&', '|'}.
%
%   Outputs:
%       fop     Char array of the flipped operator such that:
%               (A op B) is equivalent to (B fop A).
%

    switch op
        case '<='
            fop = '>=';
        case '<'
            fop = '>';
        case '>='
            fop = '<=';
        case '>'
            fop = '<';
        case {'==', '~=', '&', '|'}
            fop = op;
        otherwise
            % If input isn't an operator that can have the order of inputs
            % flipped, we'll just return op
            fop = op;
    end
end