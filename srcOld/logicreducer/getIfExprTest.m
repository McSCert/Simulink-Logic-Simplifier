function ifExpr = getIfExprTest(blockName, blockPort)
    %this function will parse the conditions of the if block
    %in order to produce a logical expression indicative of the if block
    portNum = get_param(blockPort, 'PortNumber');
    expressions = get_param(blockName, 'ElseIfExpressions');
    if ~isempty(expressions)
        expressions = regexp(expressions, ',', 'split');
        expressions = [{get_param(blockName, 'IfExpression')} expressions];
    else
        expressions = {};
        expressions{end + 1} = get_param(blockName, 'IfExpression');
    end
    exprOut = '(';
    for i = 1:portNum - 1
        exprOut = [exprOut '(~(' expressions{i} '))&' ];
    end
    exprOut = [ exprOut '(' expressions{portNum} '))' ];
    ifExpr = exprOut;
end