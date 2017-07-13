function expr = swapEquiv(expr)
% SWAPEQUIV replaces an == or ~= operation with an equivalent operation 
%   using &, |, and ~. To be a valid transformation, this assumes that the 
%   operands are logical.
%
%   Assumes there is only one operator in the expression.
%
%   Input:
%       expr    Char array expression consisting of 2 identifiers or
%               constants and either the == or the ~= operator. The
%               operands are assumed to be logical.
%
%   Output:
%       expr    Updated expression using &, |, and ~ operators instead.
%
% X == Y =>   ((X) & (Y)) | (~(X) & ~(Y))
% X ~= Y => ~(((X) & (Y)) | (~(X) & ~(Y)))

pat = '^(.)*(==|~=)(.)*$'; % Starts with anything until == or ~=, then ends with anything
tokens = regexp(expr, pat, 'tokens');
assert(~isempty(tokens), 'Unexpected input expression.')

X = tokens{1}{1}; % left hand side
E = tokens{1}{2}; % == or ~=
Y = tokens{1}{3}; % right hand side

if strcmp(E, '==')
    expr = [  '((' X ')&(' Y '))|(~(' X ')&~(' Y '))' ];
else
    expr = ['~(((' X ')&(' Y '))|(~(' X ')&~(' Y ')))'];
end

end