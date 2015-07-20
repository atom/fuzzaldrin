# A match list is an array of indexes to characters that match.
# This file should closely follow `scorer` except that it returns an array
# of indexes instead of a score.

PathSeparator = require('path').sep
scorer = require './scorer'


exports.basenameMatch = (subject, query) ->

  # Skip trailing slashes
  end = subject.length - 1
  end-- while subject[end] is PathSeparator

  # Get position of basePath of subject. If no PathSeparator, no base path exist.
  basePos = subject.lastIndexOf(PathSeparator, end)

  # Get the number of folder in query
  qdepth = scorer.countDir(query, query.length)

  # Get that many folder from subject
  while(basePos > -1 && qdepth--)
    basePos = subject.lastIndexOf(PathSeparator, basePos-1)

  #consumed whole subject ?
  return [] if (basePos == -1)

  # Get basePath match
  exports.match(subject[basePos + 1 ... end + 1], query, basePos+1)


exports.match = (subject, query, stringOffset=0) ->
  return scorer.align(subject, query, stringOffset)


#
# Combine two matches result and remove duplicate
# (Assume sequences are sorted, matches are sorted by construction.)
#

exports.mergeMatches = (a, b) ->

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
