function connective = getFullConnective(str, idx)
% GETFULLCONNECTIVE Finds the largest valid connective in str given the start 
%   position of the connective is at idx.
%
%   Input:
%       str     String to check.
%       idx     Starting index of the connective in str 
%
%   Output:
%       connective  Largest connective in str, starting at idx.
%
% E.g. str = 'foo<=bar'; idx = 4;
% connective = getFullConnective(str, idx)
% 
% connective will be set to '<=' not '<'

conPat = '[><]=?|[~=]=|~|\-|&|\|';
connective = regexp(str(idx:end), ['^' conPat], 'match', 'once');
end