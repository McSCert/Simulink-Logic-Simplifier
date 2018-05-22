function nop = flipOp(op)
    % FLIPOP 'Flip' an operator such that its inputs need to be given in reverse
    % order to give the same results. If there is no valid flip then the
    % same operator is returned.
    switch op
        case '<='
            nop = '>=';
        case '<'
            nop = '>';
        case '>='
            nop = '<=';
        case '>'
            nop = '<';
        case {'==', '~=', '&', '|'}
            nop = op;
        otherwise
            % If input isn't an operator that can have the order of inputs
            % flipped, we'll just return op
            nop = op;
    end
end