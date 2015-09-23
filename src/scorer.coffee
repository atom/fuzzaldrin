#
# Score similarity between two string
#
#  isMatch: Fast detection if all character of needle is in haystack
#  score: Find string similarity using a Smith Waterman algorithm
#         Modified to account for programing scenarios (CamelCase folder/file.ext object.property)
#
# Copyright (C) 2015 Jean Christophe Roy and contributors
# MIT License: http://opensource.org/licenses/MIT

PathSeparator = require('path').sep

#Base point for a single character match
wm = 150

#Fading function
pos_bonus = 20 # The character from 0..pos_bonus receive a bonus for being at the start of string.
tau_size = 50 # Size at which the whole match score is halved.
tau_depth = 13 # Directory depth at which the full path influence is halved

# Miss count
# When subject[i] == query[j] we register a hit.
# Limiting hit put a boundary on how many permutation we consider to find the best one.
# Help to speed up the processing of deep path and frequent character eg vowels
# If a spec with frequent repetition fail, increase this.
# This has a direct influence on worst case scenario benchmark.
miss_coeff = 0.75 #Max number missed consecutive hit = ceil(miss_coeff*query.length) + 5

#
# Optional chars
#

opt_char_re = /[ _\-:\/\\]/g

exports.coreChars = coreChars = (query) ->
  return query.replace(opt_char_re, '')


#
# Main export
#
# Manage the logic of testing if there's a match and calling the main scoring function
# Also manage scoring a path and optional character.

exports.score = (string, query, prepQuery = new Query(query), allowErrors = false) ->
  return 0 unless allowErrors or isMatch(string, prepQuery.core_lw, prepQuery.core_up)
  string_lw = string.toLowerCase()
  score = doScore(string, string_lw, prepQuery)
  return Math.ceil(basenameScore(string, string_lw, prepQuery, score))


#
# Query object
#
class Query
  constructor: (query) ->
    return null unless query?.length

    @query = query
    @query_lw = query.toLowerCase()
    @core = coreChars(query)
    @core_lw = @core.toLowerCase()
    @core_up = @core.toUpperCase()
    @depth = countDir(query, query.length)


exports.prepQuery = (query) ->
  return new Query(query)


#
# isMatch:
# Are all characters of query in subject, in proper order ?
#

exports.isMatch = isMatch = (subject, query_lw, query_up) ->
  m = subject.length
  n = query_lw.length

  if !m or !n or n > m
    return false

  i = -1
  j = -1

  #foreach char of query
  while ++j < n

    qj_lw = query_lw[j]
    qj_up = query_up[j]

    while ++i < m
      si = subject[i]
      break if si == qj_lw or si == qj_up

    if i == m then return false

  return true


#----------------------------------------------------------------------
#
# Main scoring algorithm
#

doScore = (subject, subject_lw, prepQuery) ->
  query = prepQuery.query
  query_lw = prepQuery.query_lw

  m = subject.length
  n = query.length


  #----------------------------
  # Abbreviations sequence

  acro = scoreAcronyms(subject, subject_lw, query, query_lw)
  acro_score = acro.score

  # Whole query is abbreviation ?
  # => use that as score
  if( acro.count == n)
    return scoreExact(n, m, acro_score, acro.pos)

  #----------------------------
  # Exact Match ?
  # => use that as score

  pos = subject_lw.indexOf(query_lw)
  if pos > -1
    return scoreExactMatch(subject, subject_lw, query, query_lw, pos, n, m)


  #----------------------------
  # Individual characters
  # (Smith Waterman algorithm)


  #Init
  score_row = new Array(n)
  csc_row = new Array(n)
  sz = scoreSize(n, m)

  miss_budget = Math.ceil(miss_coeff * n + 5)
  miss_left = miss_budget

  #Fill with 0
  j = -1
  while ++j < n
    score_row[j] = 0
    csc_row[j] = 0


  # Limit the search for the active region
  # Before first letter, or -1
  i = subject_lw.indexOf(query_lw[0])
  if(i > -1) then i--

  # After last letter
  mm = subject_lw.lastIndexOf(query_lw[n - 1], m)
  if(mm > i) then m = mm + 1

  while ++i < m     #foreach char si of subject

    score = 0
    score_diag = 0
    csc_diag = 0
    si_lw = subject_lw[i]
    record_miss = true

    j = -1 #0..n-1
    while ++j < n   #foreach char qj of query

      # What is the best gap ?
      # score_up contain the score of a gap in subject.
      # score_left = last iteration of score, -> gap in query.
      score_up = score_row[j]
      score = score_up if(score_up > score )

      #Reset consecutive
      csc_score = 0

      #Compute a tentative match
      if ( query_lw[j] == si_lw )

        start = isWordStart(i, subject, subject_lw)

        # Forward search for a sequence of consecutive char
        csc_score = if csc_diag > 0  then csc_diag else scoreConsecutives(subject, subject_lw, query, query_lw, i,
          j, start)

        # Determine bonus for matching A[i] with B[j]
        align = score_diag + scoreCharacter(i, j, start, acro_score, csc_score)

        #Are we better using this match or taking the best gap (currently stored in score)?
        if(align > score)
          score = align
          # reset consecutive missed hit count
          miss_left = miss_budget
        else
          # We rejected this match and record a miss.
          # If budget is exhausted exit
          # Each character of query have it's score history stored in score_row
          # To get full query score use last item of row.
          return score_row[n - 1] * sz if(record_miss and --miss_left <= 0)
          record_miss = false


      #Prepare next sequence & match score.
      score_diag = score_up
      csc_diag = csc_row[j]
      csc_row[j] = csc_score
      score_row[j] = score


  return score * sz

#
# Boundaries
#
# Is the character at the start of a word, end of the word, or a separator ?
# Fortunately those small function inline well.
#

exports.isWordStart = isWordStart = (pos, subject, subject_lw) ->
  return false if pos < 0
  return true if pos == 0 # match is FIRST char ( place a virtual token separator before first char of string)
  curr_s = subject[pos]
  prev_s = subject[pos - 1]
  return isSeparator(curr_s) or isSeparator(prev_s) or # match FOLLOW a separator
      (  curr_s != subject_lw[pos] and prev_s == subject_lw[pos - 1] ) # match is Capital in camelCase (preceded by lowercase)


exports.isWordEnd = isWordEnd = (pos, subject, subject_lw, len) ->
  return false if pos > len - 1
  return true if  pos == len - 1 # last char of string
  next_s = subject[pos + 1]
  return isSeparator(next_s) or # pos is followed by a separator
      ( subject[pos] == subject_lw[pos] and next_s != subject_lw[pos + 1] ) # pos is lowercase, followed by uppercase


isSeparator = (c) ->
  return c == ' ' or c == '.' or c == '-' or c == '_' or c == '/' or c == '\\'

#
# Scoring helper
#

scorePosition = (pos) ->
  if pos < pos_bonus
    sc = pos_bonus - pos
    return 100 + sc * sc
  else
    return 100 + pos_bonus - pos

scoreSize = (n, m) ->
  # Size penalty, use the difference of size (m-n)
  return tau_size / ( tau_size + Math.abs(m - n))

scoreExact = (n, m, quality, pos) ->
  return 2 * n * ( wm * quality + scorePosition(pos) ) * scoreSize(n, m)


#
# Shared scoring logic between exact match, consecutive & acronym
# Ensure pattern length dominate the score then refine to take into account case-sensitivity
# and structural quality of the pattern on the overall string (word boundary)
#

exports.scorePattern = scorePattern = (count, len, sameCase, start, end) ->
  sz = count

  bonus = 6 # to Enforce size ordering, this should be as large other bonus combined
  bonus += 2 if( sameCase == count )
  bonus += 3 if start
  bonus += 1 if end

  if( count == len) #when we match 100% of query we allow to break the size ordering.
    if start
      if( sameCase == len )
        sz += 2
      else
        sz += 1
    if end
      bonus += 1

  return sameCase + sz * ( sz + bonus )


#
# Compute the bonuses for two chars that are confirmed to matches in a case-insensitive way
#

exports.scoreCharacter = scoreCharacter = (i, j, start, acro_score, csc_score) ->

  #start of string bonus
  posBonus = scorePosition(i)

  #match IS a word boundary:
  if start
    return posBonus + wm * ( (if acro_score > csc_score then acro_score else csc_score) + 10  )

  #normal Match, add proper case bonus
  return posBonus + wm * csc_score


#
# Forward search for a sequence of consecutive character.
#

exports.scoreConsecutives = scoreConsecutives = (subject, subject_lw, query, query_lw, i, j, start) ->
  m = subject.length
  n = query.length

  mi = m - i
  nj = n - j
  k = if mi < nj then mi else nj

  startPos = i #record start position
  sameCase = 0
  sz = 0 #sz will be one more than the last qi == sj

  # query_lw[i] == subject_lw[j] has been checked before entering now do case sensitive check.
  sameCase++ if (query[j] == subject[i])

  #Continue while lowercase char are the same, record when they are case-sensitive match.
  while (++sz < k and query_lw[++j] == subject_lw[++i])
    sameCase++ if (query[j] == subject[i])

  # Faster path for single match.
  # Isolated character match occurs often and are not really interesting.
  # Fast path so we don't compute expensive pattern score on them.
  # Acronym should be addressed with acronym context bonus instead of consecutive.
  return 1 + 2 * sameCase if sz is 1

  return scorePattern(sz, n, sameCase, start, isWordEnd(i, subject, subject_lw, m))


#
# Compute the score of an exact match at position pos.
#

exports.scoreExactMatch = scoreExactMatch = (subject, subject_lw, query, query_lw, pos, n, m) ->

  # Test for word start
  start = isWordStart(pos, subject, subject_lw)

  # Heuristic
  # If not a word start, test next occurrence
  # - We want exact match to be fast
  # - For exact match, word start has the biggest impact on score.
  # - Testing 2 instances is somewhere between testing only one and testing every instances.

  if not start
    pos2 = subject_lw.indexOf(query_lw, pos + 1)
    if pos2 > -1
      start = isWordStart(pos2, subject, subject_lw)
      pos = pos2 if start

  #Exact case bonus.
  i = -1
  sameCase = 0
  while (++i < n)
    if (query[pos + i] == subject[i])
      sameCase++

  end = isWordEnd(pos + n - 1, subject, subject_lw, m)

  return scoreExact(n, m, scorePattern(n, n, sameCase, start, end), pos)


#
# Acronym prefix
#

class AcronymResult
  constructor: (@score, @pos, @count) ->

emptyAcronymResult = new AcronymResult(0, 0.1, 0)

exports.scoreAcronyms = scoreAcronyms = (subject, subject_lw, query, query_lw) ->
  m = subject.length
  n = query.length

  #a single char is not an acronym
  return emptyAcronymResult unless m > 1 and n > 1

  count = 0
  pos = 0
  sameCase = 0

  i = -1
  j = -1

  #foreach char of query
  while ++j < n

    qj_lw = query_lw[j]

    while ++i < m

      #test if subject match
      # Only record match that are also start-of-word.
      if qj_lw == subject_lw[i] and isWordStart(i, subject, subject_lw)
          sameCase++ if ( query[j] == subject[i] )
          pos += i
          count++
          break

    #all of subject is consumed, stop processing the query.
    if i == m then break

  #all of query is consumed.
  #a single char is not an acronym (also prevent division by 0)
  if(count < 2)
    return emptyAcronymResult

  score = scorePattern(count, n, sameCase, true, false)
  return new AcronymResult(score, pos / count, count)


#----------------------------------------------------------------------

#
# Score adjustment for path
#

basenameScore = (subject, subject_lw, prepQuery, fullPathScore) ->
  return 0 if fullPathScore == 0


  # Skip trailing slashes
  end = subject.length - 1
  end-- while subject[end] is PathSeparator

  # Get position of basePath of subject.
  basePos = subject.lastIndexOf(PathSeparator, end)

  #If no PathSeparator, no base path exist.
  return fullPathScore if (basePos == -1)

  # Get the number of folder in query
  depth = prepQuery.depth

  # Get that many folder from subject
  while(depth-- > 0)
    basePos = subject.lastIndexOf(PathSeparator, basePos - 1)
    if (basePos == -1) then return fullPathScore #consumed whole subject ?

  # Get basePath score
  basePos++
  end++
  basePathScore = doScore(subject[basePos...end], subject_lw[basePos...end], prepQuery)

  # Final score is linear interpolation between base score and full path score.
  # For low directory depth, interpolation favor base Path then include more of full path as depth increase
  #
  # A penalty based on the size of the basePath is applied to fullPathScore
  # That way, more focused basePath match can overcome longer directory path.

  alpha = 0.5 * tau_depth / ( tau_depth + countDir(subject, end + 1) )
  return  alpha * basePathScore + (1 - alpha) * fullPathScore * scoreSize(0, 0.5 * (end - basePos))


#
# Count number of folder in a path.
# (consecutive slashes count as a single directory)
#

exports.countDir = countDir = (path, end) ->
  return 0 if end < 1

  count = 0
  i = -1
  while ++i < end
    if (path[i] == PathSeparator)
      ++count
      while ++i < end and path[i] == PathSeparator
        continue

  return count