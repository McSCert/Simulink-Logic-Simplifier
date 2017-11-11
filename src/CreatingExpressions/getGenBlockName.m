function fullname = getGenBlockName(sys, indicator)
% GETGENBLOCKNAME Uses a naming convention for the Logic Simplifier
%   tool to generate blocks with related names. Does not check if name is
%   unique.
%
%   Input:
%       sys         The system in which the block will be generated.
%       indicator   Some string to indicate what the block is. E.g. block type,
%                   operator type, ...
%
%   Output:
%       fullname    Full name (includes path) of block to generate from the
%                   Logic Simplifier.
%
% Purpose of the function is to ensure some consistency of naming convention
% across files.

fullname = [sys '/gen_' indicator];

end