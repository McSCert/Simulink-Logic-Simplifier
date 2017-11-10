function newInPh = getMatchingInportHandle(startHandle, newBlock)
% GETMATCHINGINPORTHANDLE Takes an inport handle from an arbitrary block
%   and returns the inport handle on newBlock with the same port number.
%
%   Input:
%       startHandle     Input port.
%       newBlock        Just a block name. This should probably be a copy of a 
%                       block from another system and the startHandle should be
%                       from this block.
%
%   Output:
%       newInPh         Equivalent port to startHandle (same port number), but
%                       from newBlock.
%
% Within the Logic Simplification tool, the use-case is to get a port to connect
%   the RHS of an expression to.

% TODO: make it work if startHandle is a block, ...

pNum = get_param(startHandle, 'PortNumber');
ph = get_param(newBlock, 'PortHandles');
newInPh = ph.Inport(pNum);

end