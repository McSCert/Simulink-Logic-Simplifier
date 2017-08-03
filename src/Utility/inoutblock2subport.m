function subPort = inoutblock2subport(inoutBlock)
%
% Get the SubSystem port handle which corresponds with a given Inport or
% Outport block.
%
% If the Inport/Outport is at the top-level of a model, subPort will be [].

blockType = get_param(inoutBlock, 'BlockType');
assert(strcmp(blockType,'Inport') || strcmp(blockType,'Outport'), 'Unexpected input block type.')

pNum = str2double(get_param(inoutBlock, 'Port'));
parent = get_param(inoutBlock, 'Parent');
if strcmp(get_param(parent, 'Type'), 'block_diagram')
    subPort = [];
else
    subPorts = get_param(parent, 'PortHandles');
    subPorts = getfield(subPorts, blockType);
    
    for i = 1:length(subPorts)
        if get_param(subPorts(i), 'PortNumber') == pNum
            subPort = subPorts(i);
            return
        end
    end
    assert(exist('subPort', 'var'))
end

end