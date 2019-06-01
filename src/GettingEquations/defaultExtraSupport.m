function [isSupported, newEquations] = defaultExtraSupport(varargin)
% DEFAULTEXTRASUPPORT
%
%   Inputs:
%       h   Handle of a block or port to make an equation for.
%
%   Outputs:
%       isSupported
%       newEquations
%
%   Other inputs come from and are simply returned to getEqus (so they
%   shouldn't be worried about).

    isSupported = false;
    newEquations = {};
end