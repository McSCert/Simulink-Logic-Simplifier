function isNewer = isLsNewerVer()
% ISLSNEWERVER Indicates if the logic simplifier was called from a 
%   'newer version'.
%
%   Inputs:
%       N/A - your MATLAB version is implicit input.
%
%   Outputs:
%       isNewer     Logical true if the version is 2015a or newer.
%

ver = version('-release');
isNewer = str2num(ver(1:4)) >= 2015;
end