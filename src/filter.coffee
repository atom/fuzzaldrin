scorer = require './scorer'
legacy_scorer = require './legacy'

pluckCandidates = (a) -> a.candidate
sortCandidates = (a, b) -> b.score - a.score
PathSeparator = require('path').sep


module.exports = (candidates, query, {key, maxResults, allowErrors, legacy }={}) ->
  if query
    scoredCandidates = []

    # allow any character of query to be optional (but better score if they are present)
    allowErrorsInQuery = !!allowErrors

    # or allow only some characters to be optional, for example: space and space like characters
    coreQuery = if allowErrorsInQuery then query else scorer.coreChars(query)

    #get "file.ext" from "folder/file.ext"
    pos = query.indexOf(PathSeparator)
    baseQuery = if pos > -1 then query.substring(pos) else query

    if(not legacy)
      for candidate in candidates
        string = if key? then candidate[key] else candidate
        continue unless string and ( allowErrorsInQuery or scorer.isMatch(string,coreQuery) )
        score = scorer.score(string, query)
        score = scorer.basenameScore(string, baseQuery, score)
        scoredCandidates.push({candidate, score}) if score > 0

    else
      queryHasSlashes = pos > -1
      for candidate in candidates
        string = if key? then candidate[key] else candidate
        continue unless string
        score = legacy_scorer.score(string, coreQuery, queryHasSlashes)
        unless queryHasSlashes
          score = legacy_scorer.basenameScore(string, coreQuery, score)
        scoredCandidates.push({candidate, score}) if score > 0


    # Sort scores in descending order
    scoredCandidates.sort(sortCandidates)

    candidates = scoredCandidates.map(pluckCandidates)

  candidates = candidates[0...maxResults] if maxResults?
  candidates
