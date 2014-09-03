scorer = require './scorer'

pluckCandidates = (a) -> a.candidate

sortCandidates = (a, b) -> b.score - a.score

module.exports = (candidates, query, queryHasSlashes, {key, maxResults}={}) ->
  if query
    scoredCandidates = []
    for candidate in candidates
      string = if key? then candidate[key] else candidate
      continue unless string
      score = scorer.score(string, query, queryHasSlashes)
      unless queryHasSlashes
        score = scorer.basenameScore(string, query, score)
      scoredCandidates.push({candidate, score}) if score > 0

    # Sort scores in descending order
    scoredCandidates.sort(sortCandidates)

    candidates = scoredCandidates.map(pluckCandidates)

  candidates = candidates[0...maxResults] if maxResults?
  candidates
