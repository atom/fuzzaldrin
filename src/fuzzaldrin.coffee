scorer = require './scorer'
filter = require './filter'
matcher = require './matcher'

PathSeparator = require('path').sep

module.exports =
  filter: (candidates, query, options) ->
    filter(candidates, query, options)

  score: (string, query) ->
    return 0 unless string
    return 0 unless query

    #get "file.ext" from "folder/file.ext"
    pos = query.indexOf(PathSeparator)
    baseQuery = if pos > -1 then query.substring(pos) else query

    score = scorer.score(string, query)
    score = scorer.basenameScore(string, baseQuery, score)

    score

  match: (string, query, {allowErrors}={}) ->
    return [] unless string
    return [] unless query
    return [0...string.length] if string is query

    return [] unless !!allowErrors or scorer.isMatch(string,query)

    #get "file.ext" from "folder/file.ext"
    pos = query.indexOf(PathSeparator)
    baseQuery = if pos > -1 then query.substring(pos) else query

    # Full path results
    matches = matcher.match(string, query)

    #if no matches on the long path. there will not be any on the base path either.
    return matches if matches.length == 0

    # Is there a base path ?
    if(string.indexOf(PathSeparator) > -1)

      # Base path results
      baseMatches = matcher.basenameMatch(string, baseQuery)

      # Combine the results, removing duplicate indexes
      matches = mergeSorted(matches,baseMatches)

    matches

#
# Combine two sorted sequence, remove duplicate
#

mergeSorted = (a, b) ->

  out = []
  m = a.length
  n = b.length

  return a.slice() if n == 0
  return b.slice() if m == 0

  i = -1
  j = 0
  bj = b[0]

  while ++i < m
    ai = a[i]

    while bj <= ai and ++j < n
      if bj < ai
        out.push bj
      bj = b[j]

    out.push ai

  while j < n
    out.push b[j++]

  return out

