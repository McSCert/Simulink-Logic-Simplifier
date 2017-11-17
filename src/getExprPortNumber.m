function pNum = getExprPortNumber(expr, lhsTable)
% Returns the port number of the handle associated with the LHS of the given
% expression.
% pNum == 0 -> expression type is blk; no associated pNum

[lhs, ~] = getExpressionLhsRhs(expr);

h = lhsTable.lookdown(lhs);

eType = expressionType(h);

switch eType
    case {'out', 'in'}
        pNum = get_param(h, 'PortNumber');
    case 'blk'
        pNum = 0;
    otherwise
        error('Error: Unexpected eType')
end

end