function index = getIndexForNameKey(name)
    global nameDic;
    if (~isa(nameDic, 'containers.Map'))
        nameDic = containers.Map();
    end
    if(~nameDic.isKey(name))
        index = length(nameDic.keys) + 1;
        nameDic(name) = index;
    else
        index = nameDic(name);
    end
end