function ReorderInputs(block)
% REORDERINPUTS Reorders which lines go to which input in a block to
% reduce line crossings. WARNING: only use on blocks where order of inputs
% does not matter.

    sys = get_param(block, 'parent');
    blockLineHandles = get_param(block, 'LineHandles');
    inLines = blockLineHandles.Inport;

    % Get line initial heights and source ports, delete lines
    initHeights = [];
    srcPorts = [];
    dstPorts = [];
    for i = 1:length(inLines)
        srcPort = get_param(inLines(i), 'SrcPortHandle');
        pos = get_param(srcPort, 'Position');
        initHeights(end + 1) = pos(2);
        srcPorts(end + 1) = get_param(inLines(i), 'SrcPortHandle');
        dstPorts(end + 1) = get_param(inLines(i), 'DstPortHandle');
        delete_line(inLines(i));
    end

    % Find the correct ordering of the lines
    orderArray = [1];
    for i = 2:length(initHeights)
        for j = 1:length(orderArray)
            if (initHeights(i) < initHeights(orderArray(j)))
                if (j == 1)
                    orderArray = [i orderArray];
                else
                    orderArray = [orderArray(1:j-1) i orderArray(j:end)];
                end
                break
            elseif (j == length(orderArray))
                orderArray(end+1) = i;
            end
        end
    end
    assert(length(orderArray) == length(inLines))

    % Redraw lines
    for i = 1:length(orderArray)
        add_line(sys, srcPorts(orderArray(i)), dstPorts(i));
    end
end