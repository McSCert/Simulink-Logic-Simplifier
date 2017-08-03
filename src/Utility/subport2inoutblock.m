function inoutBlock = subport2inoutblock(subPort)
%
% Get the Inport or Outport block which corresponds with a given SubSystem
% Inport or Outport.

parent = get_param(subPort, 'Parent');

assert(strcmp(get_param(subPort, 'Type'), 'port'), ...
    'Input is expected to be a port handle.')
portType = get_param(subPort, 'PortType');

assert(strcmp(get_param(parent, 'BlockType'), 'SubSystem'), ...
    'Input is expected to belong to a SubSystem.')

assert(strcmp(portType, 'outport') || strcmp(portType, 'inport'), ...
    'Input is expected to be either an inport or outport.')

pNum = get_param(subPort, 'PortNumber');
blockType = [upper(portType(1)), portType(2:end)];
inoutBlock = find_system(parent, 'SearchDepth', 1, 'BlockType', blockType, 'Port', num2str(pNum));
end