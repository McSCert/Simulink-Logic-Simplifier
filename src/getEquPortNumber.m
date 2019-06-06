function pNum = getEquPortNumber(equ, lhsTable)
% GETEQUPORTNUMBER Get port number of the handle associated with the LHS of the
%   given equation.
%   pNum == 0 -> equation type is blk; no associated pNum.
%
%   Inputs:
%       equ         Cell array of equations to simplify.
%       lhsTable    A BiMap object (see BiMap.m) that records object handles and
%                   their representation within equations. The BiMap is updated
%                   with new handles and their representations as equations for
%                   them are found.
%                   - This function should not update lhsTable.
%
%   Outputs:
%       pNum        Port number corresponding to the lhs of equ or 0 if there is
%                   no port number.
%

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