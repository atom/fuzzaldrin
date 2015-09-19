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
# max pos bonus occurs at position 0 and have value of pos_bonus^2
# The ratio of max pos bonus and wm set importance of start of string position in overall score.

tau_size = 50 # Size at which the whole match score is halved.
tau_depth = 13 # Directory depth at which the full path influence is halved

# There is a compromise where user expects better pattern to win despite being
# in a longer string, later in the string, deeper directory etc.
#
# The knob are should be adjusted to they are as strong as possible without any test failing.
# This mean some test will barely pass. And making change might require a re-tuning of those number.


#
# Optional chars
#

opt_char_re = /[ _\-:\/\\]/g

exports.coreChars = coreChars = (query) ->
  return query.replace(opt_char_re, '')

#
# Search windows for fuzzy matching.
#
# IsMatch & Exact Matches (IndexOf & Acronym) use the full string.
#
# But character per character optimal alignment is expensive
# So we use a search window at the start of the string to control cost.
#

exports.defaultSearchWindow = 64

#
# Main export
#
# Manage the logic of testing if there's a match and calling the main scoring function
# Also manage scoring a path and optional character.

exports.score = (string, query, prepQuery = new Query(query), allowErrors = false, fuzzyWindow = exports.defaultSearchWindow) ->
  string_lw = string.toLowerCase()
  return 0 unless allowErrors or exports.isMatch(string_lw, prepQuery.core_lw)
  score = doScore(string, string_lw, prepQuery, fuzzyWindow)
  return Math.floor(basenameScore(string, string_lw, prepQuery, score, fuzzyWindow))


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
    @depth = countDir(query, query.length)


exports.prepQuery = (query) ->
  return new Query(query)


#
# isMatch:
# Are all characters of query in subject, in proper order ?
#

exports.isMatch = isMatch = (subject_lw, query_lw) ->
  m = subject_lw.length
  n = query_lw.length

  if !m or !n or n > m
    return false

  i = -1
  j = -1

  #foreach char of query
  while ++j < n

    qj_lw = query_lw[j]

    # continue search in subject from last match
    # until first positive or until we reach the end.
    while ++i < m
      break if subject_lw[i] == qj_lw

    # if we reach the end of the string then we do not have a match.
    # unless we are scanning last char of query and we have a match.
    if i == m then return (j == n - 1 and subject_lw[i - 1] == qj_lw)


  return true


#----------------------------------------------------------------------
#
# Main scoring algorithm
#

doScore = (subject, subject_lw, prepQuery, fuzzyWindow) ->
  query = prepQuery.query
  query_lw = prepQuery.query_lw

  m = subject.length
  n = query.length

  sz = scoreSize(n, m)

  #----------------------------
  # Abbreviations sequence

  acro = scoreAcronyms(subject, subject_lw, query, query_lw)
  acro_score = acro.score

  # Whole query is abbreviation ?
  # => use that as score
  if( acro.count == n)
    return 2 * n * ( wm * acro_score + scorePosition(acro.pos) ) * sz

  #----------------------------
  # Exact Match ?
  # => use that as score

  pos = subject_lw.indexOf(query_lw)
  if pos > -1
    return 2 * n * (  wm * scoreExactMatch(subject, subject_lw, query, pos, n, m) + scorePosition(pos) ) * sz


  #----------------------------
  # Individual characters
  # (Smith Waterman algorithm)

  #max string size for O(m*n) best match search
  m = fuzzyWindow if m > fuzzyWindow
  n = fuzzyWindow if n > fuzzyWindow

  #Init
  score_row = new Array(n)
  csc_row = new Array(n)

  #Fill with 0
  j = -1
  while ++j < n
    score_row[j] = 0
    csc_row[j] = 0

  i = -1 #0..m-1
  while ++i < m     #foreach char si of subject

    score = 0
    score_diag = 0
    csc_diag = 0
    si_lw = subject_lw[i]

    j = -1 #0..n-1
    while ++j < n   #foreach char qj of query

      #reset score
      csc_score = 0
      align = 0

      #Compute a tentative match
      if ( query_lw[j] == si_lw )

        # Forward search for a sequence of consecutive char
        csc_score = if csc_diag > 0  then csc_diag else scoreConsecutives(subject, subject_lw, query, query_lw, i, j)

        # Determine bonus for matching A[i] with B[j]
        align = score_diag + scoreCharacter(subject, subject_lw, query, i, j, acro_score, csc_score)

      #Prepare next sequence & match score.
      score_diag = score_row[j]
      csc_diag = csc_row[j]

      #Compare the score of making a match, a gap in Query (A), or a gap in Subject (B)
      gap = if(score > score_diag) then score else score_diag

      if(align > gap)
        score_row[j] = score = align
        csc_row[j] = csc_score
      else
        score_row[j] = score = gap
        csc_row[j] = 0 #If we do not use this character reset consecutive sequence.

  return score * sz

#
# Boundaries
#
# Is the character at the start of a word, end of the word, or a separator ?
#

isWordStart = (pos, subject, subject_lw) ->
  return false if pos < 0
  return true if pos == 0 # match is FIRST char ( place a virtual token separator before first char of string)
  prev_s = subject[pos - 1]
  return isSeparator(prev_s) or # match FOLLOW a separator
      (  subject[pos] != subject_lw[pos] and prev_s == subject_lw[pos - 1] ) # match is Capital in camelCase (preceded by lowercase)


isWordEnd = (pos, subject, subject_lw, len) ->
  return false if pos > len - 1
  return true if  pos == len - 1 # last char of string
  next_s = subject[pos + 1]
  return isSeparator(next_s) or # pos is followed by a separator
      ( subject[pos] == subject_lw[pos] and next_s != subject_lw[pos + 1] ) # pos is lowercase, followed by uppercase

# This is MUCH faster than `c in separator_list` or `c of separator_map`
# cut about 30% of processing time on worst case scenario

isSeparator = (c) ->
  return c == ' ' or c == '.' or c == '-' or c == '_' or c == '/' or c == '\\'


scorePosition = (pos) ->
  return 0 if pos > pos_bonus
  sc = pos_bonus - pos
  return sc * sc

scoreSize = (n, m) ->
  # Size penalty, use the difference of size (m-n)
  return tau_size / ( tau_size + Math.abs(m - n))


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

exports.scoreCharacter = scoreCharacter = (subject, subject_lw, query, i, j, acro_score, csc_score) ->


  #start of string bonus
  posBonus = scorePosition(i)

  #match IS a word boundary:
  if isWordStart(i, subject, subject_lw)
    return posBonus + wm * ( (if acro_score > csc_score then acro_score else csc_score) + 10  )

  #normal Match, add proper case bonus
  return posBonus + wm * csc_score


#
# Forward search for a sequence of consecutive character.
#

exports.scoreConsecutives = scoreConsecutives = (subject, subject_lw, query, query_lw, i, j) ->
  m = subject.length
  n = query.length

  mi = m - i
  nj = n - j
  k = if mi < nj then mi else nj

  startPos = i #record start position
  sameCase = 0
  sz = 0 #sz will be one more than the last qi == sj

  # query_lw[i] == subject_lw[j] has been checked before entering
  # now do case sensitive check.
  sameCase++ if (query[j] == subject[i])

  while (++sz < k and query_lw[++j] == subject_lw[++i])
    sameCase++ if (query[j] == subject[i])

  return 1 + 2 * sameCase if sz is 1

  # In a multi word query like "Git Commit" the consecutive sequence can start with a separator, here <space>.
  # We want to register this as a start of word match.
  start = isWordStart(startPos, subject, subject_lw) or isSeparator(subject_lw[startPos])
  end = isWordEnd(i, subject, subject_lw, m)
  return scorePattern(sz, n, sameCase, start, end)


#
# Compute the score of an exact match at position pos.
#

exports.scoreExactMatch = scoreExactMatch = (subject, subject_lw, query, pos, n, m) ->

  #Exact case bonus.
  i = -1
  sameCase = 0
  while (++i < n)
    if (query[pos + i] == subject[i])
      sameCase++

  start = isWordStart(pos, subject, subject_lw) or isSeparator(subject_lw[pos])
  end = isWordEnd(pos + n - 1, subject, subject_lw, m)
  return scorePattern(n, n, sameCase, start, end)


#
# Acronym prefix
#

class AcronymResult
  constructor: (@score, @pos, @count) ->

emptyAcronymResult = new AcronymResult(0, 0.1, 0)

exports.scoreAcronyms = scoreAcronyms = (subject, subject_lw, query, query_lw) ->
  m = subject.length
  n = query.length
  return emptyAcronymResult unless m and n

  count = 0
  pos = 0
  sameCase = 0

  i = -1
  j = -1
  k = m - 1

  #foreach char of query
  while ++j < n

    qj_lw = query_lw[j]

    while ++i < m

      #test if subject match
      if(qj_lw == subject_lw[i])

        # subject match.. test if we have an acronym
        # if so, record result & break to next char of query.
        if  isWordStart(i, subject, subject_lw)
          sameCase++ if ( query[j] == subject[i] )
          pos += i
          count++
          break

    #all of subject is consumed, stop processing the query.
    if i == k then break

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

basenameScore = (subject, subject_lw, prepQuery, fullPathScore, fuzzyWindow) ->
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

  #If fuzzyWindow limit apply, clip to the right  to get as much of the filename as possible
  basePos = Math.max(basePos, end - fuzzyWindow)

  # Get basePath score
  basePos++
  end++
  basePathScore = doScore(subject[basePos...end], subject_lw[basePos...end], prepQuery, fuzzyWindow)

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