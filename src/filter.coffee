scorer = require './scorer'
legacy_scorer = require './legacy'

pluckCandidates = (a) -> a.candidate
sortCandidates = (a, b) -> b.score - a.score
PathSeparator = require('path').sep

module.exports = (candidates, query, {key, maxResults, maxInners, allowErrors, legacy }={}) ->

  scoredCandidates = []
  spotLeft = if maxInners? and  maxInners> 0 then maxInners else candidates.length

  bAllowErrors = !!allowErrors
  prepQuery = scorer.prepQuery(query)

  if(not legacy)
    for candidate in candidates
      string = if key? then candidate[key] else candidate
      continue unless string
      score = scorer.score(string, query, prepQuery, bAllowErrors)
      if score > 0
        scoredCandidates.push({candidate, score})
        break unless --spotLeft

  else
    queryHasSlashes = prepQuery.depth > 0
    coreQuery = prepQuery.core

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
