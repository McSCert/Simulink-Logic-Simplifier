function idPat = identifierPattern(id)
% Get the regular expression pattern to match the given identifier

idPat = ['(^|[^0-9A-z_])(' id ')([^0-9A-z_]|$)'];
end