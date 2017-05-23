%atomicExpr is a map mapping the name of variable to a corresponding block

atomicExpr = containers.Map();

atomicExpr('A') = 'logictest/In1';
atomicExpr('B') = 'logictest/In2';
atomicExpr('C') = 'logictest/In3';

expression = '((((A)&&(B))&&(C))||((A)&&(B))';

sys = 'logictest';

createLogicBlocks(expression, 1, atomicExpr, sys)