function fullname = getGenBlockName(sys, indicator)
% GETGENBLOCKNAME Use a naming convention for the Logic Simplifier Tool to
%   generate blocks with related names. Does not check if name is unique.

% The purpose of the function is to ensure some consistency of naming convention
% across files.
%
%   Inputs:
%       sys         The system in which the block will be generated.
%       indicator   Some string to indicate what the block is. E.g. block type,
%                   operator type, ...
%
%   Outputs:
%       fullname    Full name (includes path) of block to generate from the
%                   Logic Simplifier.
%
    fullname = [sys '/gen_' indicator];
end