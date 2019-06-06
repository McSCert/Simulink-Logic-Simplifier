function idPat = identifierPattern(id)
% IDENTIFIERPATTERN Get the regular expression pattern to match the given
%   identifier.
%
%   Inputs:
%       id      Char array representing an identifier that may be used in a
%               Logic Simplifier equation.
%
%   Outputs:
%       idPat   Regular expression pattern to use to find the identifier.
%

idPat = ['(?<=(^|[^0-9A-z_]))(' id ')(?=([^0-9A-z_]|$))'];
end