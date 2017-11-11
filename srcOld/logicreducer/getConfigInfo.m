function [ blockList ] = getConfigInfo( configFile )
% Parse config file and get application relevant info.
    configInfo = parseXML(configFile);
    blockList = parseStruct(configInfo);
end

function [blockList] = parseStruct(structTree)
    for i = 1:length(structTree.Children)
        if strcmp(structTree.Children(i).Name, 'SupportedBlocks') == 1
            blockList = getSupportedBlocks(structTree.Children(i)); 
        end
    end
end

function [supportedBlocks] = getSupportedBlocks(supportedBlocksNode)
% This is messy, consider cleaning it up TODO
% This function creates the 'block type-block category' mapping
    supportedBlocks = containers.Map();
    for i = 1:length(supportedBlocksNode.Children)
        if (strcmp(supportedBlocksNode.Children(i).Name, 'Block') == 1)
            for j = 1:length(supportedBlocksNode.Children(i).Attributes)
                if (strcmp(supportedBlocksNode.Children(i).Attributes(j).Name, ...
                        'type') == 1)
                    for k = 1:length(supportedBlocksNode.Children(i).Attributes)
                        if (strcmp(supportedBlocksNode.Children(i).Attributes(k).Name, ...
                                'category') == 1)
                        supportedBlocks(supportedBlocksNode.Children(i).Attributes(j).Value) ...
                        = supportedBlocksNode.Children(i).Attributes(k).Value;
                        end
                    end
                end
            end
        end
    end
end

% Below from: http://www.mathworks.com/help/matlab/ref/xmlread.html

function theStruct = parseXML(filename)
    % PARSEXML Convert XML file to a MATLAB structure.
    try
        tree = xmlread(filename);
    catch
        error('Failed to read XML file %s.', filename);
    end

    % Recurse over child nodes. This could run into problems 
    % with very deeply nested trees.
    try
        theStruct = parseChildNodes(tree);
    catch
        error('Unable to parse XML file %s.', filename);
    end
end


function children = parseChildNodes(theNode)
    % Recurse over node children.
    children = [];
    if theNode.hasChildNodes
        childNodes = theNode.getChildNodes;
        numChildNodes = childNodes.getLength;
        allocCell = cell(1, numChildNodes);

        children = struct( ...
            'Name', allocCell, 'Attributes', allocCell, ...
            'Data', allocCell, 'Children', allocCell);

        for count = 1:numChildNodes
            theChild = childNodes.item(count - 1);
            children(count) = makeStructFromNode(theChild);
        end
    end
end

function nodeStruct = makeStructFromNode(theNode)
    % Create structure of node info.

    nodeStruct = struct( ...
        'Name', char(theNode.getNodeName), ...
        'Attributes', parseAttributes(theNode), ...
        'Data', '', ...
        'Children', parseChildNodes(theNode));

    if any(strcmp(methods(theNode), 'getData'))
        nodeStruct.Data = char(theNode.getData);
    else
        nodeStruct.Data = '';
    end
end

function attributes = parseAttributes(theNode)
    % Create attributes structure.
    attributes = [];
    if theNode.hasAttributes
        theAttributes = theNode.getAttributes;
        numAttributes = theAttributes.getLength;
        allocCell = cell(1, numAttributes);
        attributes = struct('Name', allocCell, 'Value', ...
            allocCell);

        for count = 1:numAttributes
            attrib = theAttributes.item(count - 1);
            attributes(count).Name = char(attrib.getName);
            attributes(count).Value = char(attrib.getValue);
        end
    end
end