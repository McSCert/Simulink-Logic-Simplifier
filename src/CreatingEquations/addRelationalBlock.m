function block = addRelationalBlock(opType, sys, varargin)
% ADDRELATIONALBLOCK Add a relational operator block of the specified optype.
%
%   Inputs:
%       opType      Char array of the desired Operator parameter for the
%                   relational operator block.
%       sys         Char array of the system in which the block will be
%                   generated. 
%       varargin    Parameter value pairs to pass to the add_block function when
%                   adding the block.
%
%   Outputs:
%       block       Handle of the added block.
%
%   Usage:
%       % Create an equality block named 'gen_RelationalOp'.
%       block = addRelationalBlock('==', gcs)
%

    % Make sure added operator block has a unique name associated with it
    block = add_block('built-in/RelationalOperator', ...
        getGenBlockName(sys, 'RelationalOp'), ...
        'MAKENAMEUNIQUE','ON', varargin{:});

    % temp - eventually pass this with varargin, and potentially avoid the need
    % for it
    set_param(block, 'InputSameDT', 'off');

    % Set operator
    set_param(block, 'Operator', opType);
end