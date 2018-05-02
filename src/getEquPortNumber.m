function pNum = getEquPortNumber(equ, lhsTable)
% Returns the port number of the handle associated with the LHS of the given
% equation.
% pNum == 0 -> equation type is blk; no associated pNum

[lhs, ~] = getEquationLhsRhs(equ);

h = lhsTable.lookdown(lhs);

eType = equationType(h);

switch eType
    case {'out', 'in'}
        pNum = get_param(h, 'PortNumber');
    case 'blk'
        pNum = 0;
    otherwise
        error('Error: Unexpected eType')
end

end