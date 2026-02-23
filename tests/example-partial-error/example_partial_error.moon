-- hamming
distance = (left, right) ->
  assert #left == #right, 'strands must be of equal length'

  dist = 0
  -- below should be `=` not `in`
  for i in 1,#left
    dist += 1 if left\sub(i) ~= right\sub(i)
  dist

{ :distance }

