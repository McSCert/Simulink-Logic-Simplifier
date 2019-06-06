function [isSupported, newEquations] = defaultExtraSupport(varargin)
% DEFAULTEXTRASUPPORT Default function providing support to the Logic Simplifier
%   Tool for more blocks. Being the default, this function does not actually
%   provide any additional support. The extraSupport function is determined by
%   the tool's config.txt file and is used within getEqus (other functions pass
%   the function around, but it is only used in the one place).
%
%   Inputs:
%       varargin        Accepts any input so as to not throw errors.
%                       For a non-default extra-support function, many arguments
%                       will generally just be passed in so that they can be
%                       passed on to a call of getEqus, but in this case there
%                       is no need to call getEqus.
%
%   Outputs:
%       isSupported     Always false indicating that no support is added by this
%                       function.
%       newEquations    Never finds any new equations. To add new equations, a
%                       non-default extra-support would determine how to handle
%                       a given block and then call getEqus to figure out how to
%                       address the blocks that lead into that block.
%

    isSupported = false;
    newEquations = {};
end