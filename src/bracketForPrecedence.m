function newexpression = bracketForPrecedence(expression)
% BRACKETFORPRECEDENCE Takes a logical expression and applies additional
%   brackets in order to preserve the appropriate order of operations
%   within the expression while only having to observe precedence of
%   brackets.
%
%   Inputs:
%       expression      Character array of a logical expression consisting
%                       of brackets, logical negation, unary minus,
%                       relational operators, logical AND, logical OR,
%                       as well as whitespace, numeric values,
%                       boolean values, and identifiers. {(, ), ~, -, <, <=,
%                       >, >=, ==, ~=, &, |,  , [0-9]+, TRUE, FALSE,
%                       [a-zA-Z][a-zA-Z0-9]*}
%
%   Outputs:
%       newexpression   Resulting expression after swapping logical 1s and
%                       0s with TRUE or FALSE respectively.

% Method from https://en.wikipedia.org/wiki/Operator-precedence_parser
% under "Alternative methods"
%
% Add "(((" at the start of the expression and after each ( in the original expression
% Add ")))" at the end of the expression and after each ) in the original expression
% Replace <, <=, >, >=, ==, ~= by ")o(" where o is the appropriate operator
% Replace & by "))&(("
% Replace | by ")))|((("

newexpression = expression;

% Add "(((" after each ( in the original expression
newexpression = strrep(newexpression, '(', '((((');

% Add ")))" after each ) in the original expression
newexpression = strrep(newexpression, ')', '))))');

% Add "(((" at the start of the expression
% Add ")))" at the end of the expression
newexpression = ['(((' newexpression ')))'];

% Replace <, <=, >, >=, ==, ~= by ")o(" where o is the appropriate operator
newexpression = regexprep(newexpression, '[><]=?|[~=]=', ')$0(');

% Replace & by "))&(("
newexpression = strrep(newexpression, '&', '))&((');

% Replace | by ")))|((("
newexpression = strrep(newexpression, '|', ')))|(((');

end

%%%%%% Old test case when I thought == and ~= had lower precedence than > < >= <= %%%%%%
%We'll do a reasonably long test case.
%To test the method described above we'll evaluate the start and end expression manually.
%While doing this manual evaluation we'll make sure that operations execute in the same order (by visual comparison) for both the start expression and the output expression.
%To minimize risk of human error we'll write out as many steps as possible (even though most of the steps will be trivial).
%
% Test: bracketForPrecedence('~x  & y < 1 | (((TRUE)) == ((0 < z)) ~= FALSE) & ~TRUE & 0 < 1 & (TRUE == FALSE | 0 == y)')
% Expected order of operation analysis:
%   let x = FALSE, y = 0, z = 1, therefore:
%   ~x  & y < 1 | (((TRUE)) == ((0 < z)) ~= FALSE) & ~TRUE & 0 < 1 & (TRUE == FALSE | 0 == y)
% =>~FALSE  & 0 < 1 | (((TRUE)) == ((0 < 1)) ~= FALSE) & ~TRUE & 0 < 1 & (TRUE == FALSE | 0 == 0)
% => TRUE   & TRUE  | (( TRUE ) == (  TRUE ) ~= FALSE) & FALSE &  TRUE & (    FALSE     |  TRUE )
% =>      TRUE      | (  TRUE   ==    TRUE   ~= FALSE) & FALSE &  TRUE & (             TRUE     )
% =>      TRUE      | (        TRUE          ~= FALSE) & FALSE &  TRUE &               TRUE
% =>      TRUE      | (                     TRUE     ) & FALSE &  TRUE &               TRUE
% =>      TRUE      |                       TRUE       & FALSE &  TRUE &               TRUE
% =>      TRUE      |                                FALSE     &  TRUE &               TRUE
% =>      TRUE      |                                        FALSE     &               TRUE
% =>      TRUE      |                                                FALSE
% =>              TRUE
%
% Expected Output: '((((~x  )))&((( y )<( 1 ))))|(((( (((((((((((((((TRUE)))))))))) ))==(( ((((((((((0 )<( z)))))))))) ))~=(( FALSE))))) )))&((( ~TRUE )))&((( 0 )<( 1 )))&((( (((((TRUE ))==(( FALSE ))))|(((( 0 ))==(( y)))))))))'
%   as before, let x = FALSE, y = 0, z = 1, therefore:
%   ((((~x  )))&((( y )<( 1 ))))|(((( (((((((((((((((TRUE)))))))))) ))==(( ((((((((((0 )<( z)))))))))) ))~=(( FALSE))))) )))&((( ~TRUE )))&((( 0 )<( 1 )))&((( (((((TRUE ))==(( FALSE ))))|(((( 0 ))==(( y)))))))))
%holy crap this is going to be a pain to evaluate manually
% =>((((~FALSE  )))&((( 0 )<( 1 ))))|(((( (((((((((((((((TRUE)))))))))) ))==(( ((((((((((0 )<( 1)))))))))) ))~=(( FALSE))))) )))&((( ~TRUE )))&((( 0 )<( 1 )))&((( (((((TRUE ))==(( FALSE ))))|(((( 0 ))==(( 0)))))))))
% =>(((( TRUE   )))&((  0  <  1  )))|(((( (((((((((((((( TRUE ))))))))) ))==(( ((((((((( 0  <  1 ))))))))) ))~=(  FALSE )))) )))&((( FALSE )))&((  0  <  1  ))&((( (((( TRUE  )==(  FALSE  )))|(((  0  )==(  0 ))))))))
% =>(((  TRUE    ))&((   TRUE    )))|(((( (((((((((((((  TRUE  )))))))) ))==(( (((((((((   TRUE  ))))))))) ))~=   FALSE  ))) )))&((  FALSE  ))&((    TRUE   ))&((( (((  TRUE   ==   FALSE   ))|((   0   ==   0  )))))))
% =>((   TRUE     )&(    TRUE     ))|(((( ((((((((((((   TRUE   ))))))) ))==(( ((((((((    TRUE   )))))))) ))~=   FALSE  ))) )))&(   FALSE   )&(     TRUE    )&((( (((        FALSE         ))|((      TRUE     )))))))
% =>(    TRUE      &     TRUE      )|(((( (((((((((((    TRUE    )))))) ))==(( (((((((     TRUE    ))))))) ))~=   FALSE  ))) )))&    FALSE    &      TRUE     &((( ((         FALSE          )|(       TRUE      ))))))
% =>(            TRUE              )|(((( ((((((((((     TRUE     ))))) ))==(( ((((((      TRUE     )))))) ))~=   FALSE  ))) )))&    FALSE    &      TRUE     &((( (          FALSE           |        TRUE       )))))
% =>             TRUE               |(((( (((((((((      TRUE      )))) ))==(( (((((       TRUE      ))))) ))~=   FALSE  ))) )))&    FALSE    &      TRUE     &((( (                        TRUE                  )))))
% =>             TRUE               |(((( (((            TRUE             ==               TRUE              ~=   FALSE  ))) )))&    FALSE    &      TRUE     &                             TRUE                      ) % Removed extra brackets in one step this time
% =>             TRUE               |(((( (((                            TRUE                                ~=   FALSE  ))) )))&    FALSE    &      TRUE     &                             TRUE                      )
% =>             TRUE               |(((( (((                                                               TRUE         ))) )))&    FALSE    &      TRUE     &                             TRUE                      )
% =>             TRUE               |(                                                                      TRUE                &    FALSE    &      TRUE     &                             TRUE                      ) % Removed extra brackets in one step this time
% =>             TRUE               |(                                                                                        FALSE           &      TRUE     &                             TRUE                      )
% =>             TRUE               |(                                                                                                      FALSE             &                             TRUE                      )
% =>             TRUE               |(                                                                                                                      FALSE                                                     )
% =>             TRUE               |                                                                                                                       FALSE
% =>                              TRUE
%%%%%%%%%%%%%%%%%%%%%%%%