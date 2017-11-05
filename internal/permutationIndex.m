function index = permutationIndex(perm)
% perm type: [3 1 2] starts at 1
  index = 1;
  position = 2;
  factor = 1;
  for p = (length(perm)-1):-1:1
    successors = 0;
    for q = (p+1):length(perm)
      if(perm(p) > perm(q))
        successors = successors +1;
      end
    end
    index = index + successors*factor;
    factor = factor*position;
    position = position + 1;
  end
end