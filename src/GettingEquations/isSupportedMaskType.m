function bool = isSupportedMaskType(maskType)
% ISSUPPORTEDMASKTYPE Determine if the mask is supported for simplification.
%
%   Inputs:
%       maskType    A mask type char array.
%
%   Outputs:
%       bool        True if supported, otherwise false.
%

    supportedMaskTypes = {'Compare To Constant', 'Compare To Zero'};
    bool = any(strcmp(maskType, supportedMaskTypes));
end