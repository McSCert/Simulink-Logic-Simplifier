% Simplify all A R1 x L A R2 y, for R1,R2 in {<,>,<=,>=,==,~=}, and [x,y] =
% [[1,2],[2,2],[2,1]]

syms A;
ands = {}; ors = {};
andSmtResults = {}; orSmtResults = {};
andOurResults = {}; orOurResults = {};
for op1 = {'<','<=','>','>=','==','~='}
    for x = [1,2]
        for y = [1,2]
            if x == 1 && y == 1
                continue
            else
                for op2 = {'<','<=','>','>=','==','~='}
                    ands{end+1} = ['A ', op1{1}, ' ', num2str(x), ' & A ', op2{1}, num2str(y)];
                    ors{end+1}  = ['A ', op1{1}, ' ', num2str(x), ' | A ', op2{1}, num2str(y)];
                    andSmtResults{end+1} = char(eval(['simplify(', ands{end}, ', ''Steps'', 100)']));
                    orSmtResults{end+1}  = char(eval(['simplify(',  ors{end}, ', ''Steps'', 100)']));
                    andOurResults{end+1} = simplifyExpression(ands{end});
                    orOurResults{end+1}  = simplifyExpression( ors{end});
                end
            end
        end
    end
end
% for i = 1:length(ands)
%     disp([ands{i}, '   ', andSmtResults{i}])
%     disp([ ors{i}, '   ',  orSmtResults{i}])
% end
for i = 1:length(ands)
    if ~strcmp(andSmtResults{i}, andOurResults{i})
        disp([ands{i}, '   ', andSmtResults{i}, '   ', andOurResults{i}])
    end
    if ~strcmp(orSmtResults{i}, orOurResults{i})
        disp([ ors{i}, '   ',  orSmtResults{i}, '   ',  orOurResults{i}])
    end
end