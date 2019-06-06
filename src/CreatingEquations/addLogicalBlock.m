function block = addLogicalBlock(opType, sys, varargin)
% ADDLOGICALBLOCK Add a logical operator block of the specified opType.
%
%   Inputs:
%       opType      Char array of the desired Operator parameter for the logical
%                   operator block.
%       sys         Char array of the system in which the block will be
%                   generated. 
%       varargin    Parameter value pairs to pass to the add_block function when
%                   adding the block.
%
%   Outputs:
%       block       Handle of the added block.
%
%   Usage:
%       % Create a NOT block named 'gen_NOT'.
%       block = addLogicalBlock('NOT', gcs)
%

    % Make sure added operator block has a unique name associated with it
    block = add_block('built-in/Logic', getGenBlockName(sys, opType), ...
        'MAKENAMEUNIQUE','ON', varargin{:});

    % temp - eventually pass this with varargin, and potentially avoid the need
    % for it
    set_param(block, 'AllPortsSameDT', 'off');

    % Set operator
    set_param(block, 'Operator', opType);
end