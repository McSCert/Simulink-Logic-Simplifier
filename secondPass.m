function secondPass(sys)
%secondPass - The second pass of the system Looks for block patterns to
%condense into other blocks.

    %Looks for consecutive and blocks
    flag = true;
    andBlocks = find_system(sys, 'SearchDepth', 1, 'BlockType', 'Logic', 'Operator', 'AND');
    for i = 1:length(andBlocks)
        outLine = get_param(andBlocks{i}, 'LineHandles');
        outLine = outLine.Outport;
        dstBlock = get_param(outLine, 'DstBlockHandle');
        if (~isempty(dstBlock))&&(~(length(dstBlock)>1))
            dstBlockType = get_param(dstBlock, 'BlockType');
            if strcmp(dstBlockType, 'Logic')
                dstBlockOp = get_param(dstBlock, 'Operator');
                if strcmp(dstBlockOp, 'AND')
                    %set new number of inports on destination block
                    numNewInputs = get_param(andBlocks{i}, 'Inputs');
                    numOldInputs = get_param(dstBlock, 'Inputs');
                    numOldInputs = str2num(numOldInputs)-1;
                    numInputs = num2str(numOldInputs + str2num(numNewInputs));
                    set_param(dstBlock, 'Inputs', numInputs);
                    
                    %get rid of old line
                    delete_line(outLine);
                    
                    %Get ports of destination block and source block
                    dstPorts = get_param(dstBlock, 'PortHandles');
                    dstPorts = dstPorts.Inport;
                    srcLines = get_param(andBlocks{i}, 'LineHandles');
                    srcLines = srcLines.Inport;
                    for j = 1:length(dstPorts)-numOldInputs
                        source = get_param(srcLines(j), 'SrcPortHandle');
                        add_line(sys, source, dstPorts(j+numOldInputs));
                    end
                    delete_block(andBlocks{i})
                end
            end
        end
        
        delete_unconnected_lines(sys);
        
    end


end

