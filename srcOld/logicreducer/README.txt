Logic Reducer


This was a quick port from the sl2sf translation tool. As such there are unnexcessary functions and poor project setup.


This currently supports the following blocktypes with the following operators:

Logic (NOT, AND, OR)
Relational (<, >, <=, >=, ~=, ==)

It supports more blocks, see config.xml for more info.



A quick example to try it out can be done by:

load_system('simulinkeasy');

getExpressionForBlock('simulinkeasy/notequal')

ans = 
	(In1) ~= ((In1) || ((~In2)  && (unitdelay1_out)))