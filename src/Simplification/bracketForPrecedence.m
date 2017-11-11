function newexpression = bracketForPrecedence(expression, preserveLeft2Right)
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
%       preserveLeft2Right  Logical. If true, additional brackets are added
%                           to ensure that left-to-right precedence is
%                           followed for operations with equal precedence.
%                           E.g. a & b & c -> (a & b) & c
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


% Remove whitespace
newexpression = regexprep(newexpression,'\s','');

% (a) & (b) & (c) -> ((a) & (b)) & (c)
if preserveLeft2Right
    newexpression = addL2R(newexpression);
end

end

function str = addL2R(str)
% Recursively add brackets to preserve left to right precedence

% Test case:
% addL2R('(((a)==(1)~=(TRUE))&((3)>(var)<(TRUE)==(1)))')
% Expected: '((((a)==(1))~=(TRUE))&((((3)>(var))<(TRUE))==(1)))'

% Form should follow:
% str = 'str1'; str1 does not lead with a '('
% Or:
% str = '(str1)o1(str2)o2...oN-1(strN)'; oN is an operator, strN is a substring of the same form

% Base case
if ~strcmp(str(1),'(')
    return
end % else continue to recursive case

% Split str into (str1), o1, (str2), o2, ..., oN-1, (strN) and save in terms
terms = splitAtOps(str);

% Recurse on str1, str2, ..., strN
for i = 1:2:length(terms) % Skipping o1, o2, ..., oN-1
    terms{i} = ['(', addL2R(terms{i}(2:end-1)), ')']; % 2:end-1 strips '(', ')' from '(strN)'
end

% Combine the terms back together
str = combineTerms(terms);

end

function str = combineTerms(terms)
% Recursive

if length(terms) == 1
    % 'a' -> 'a'
    str = [terms{1:end}];
elseif length(terms) == 3
    % 'a & b' -> 'a & b'
    str = [terms{1:end}];
else
    % 'a & b & c'     -> ' (a & b) & c'
    % 'a & b & c & d' -> '((a & b) & c) & d'
    str = ['(', combineTerms(terms(1:end-2)), ')', terms{end-1}, terms{end}];
end

end

function terms = splitAtOps(str)
% Recursive

starti = 1; % Start index for a pair of parentheses
endi = findMatchingParen(str,starti);

if endi == length(str)
    terms = {str(starti:endi)};
else
    % Left-most term
    leftTerm = str(starti:endi);
    
    % Find next start paren
    starti2 = regexp(str(endi+1:end), '\(', 'once');
    starti2 = starti2 + endi;
    % Next operator is between current end paren and next start paren:
    op = str(endi+1:starti2-1);
    
    terms = splitAtOps(str(starti2:end));
    terms = {leftTerm, op, terms{1:end}};
end
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