fs = require 'fs'
path = require 'path'

{filter, match} = require '../src/fuzzaldrin'

lines = fs.readFileSync(path.join(__dirname, 'data.txt'), 'utf8').trim().split('\n')

#warmup + compile
filter(lines, 'index')
filter(lines, 'index', {legacy:true})

forceAllMatch = {maxInners:-1}
legacy = {legacy:true}



console.log("======")

startTime = Date.now()
results = filter(lines, 'index')
console.log("Filtering #{lines.length} entries for 'index' took #{Date.now() - startTime}ms for #{results.length} results (~10% of results are positive, mix exact & fuzzy)")

if results.length isnt 6168
  console.error("Results count changed! #{results.length} instead of 6168")
  process.exit(1)

startTime = Date.now()
results = filter(lines, 'index', legacy)
console.log("Filtering #{lines.length} entries for 'index' took #{Date.now() - startTime}ms for #{results.length} results (~10% of results are positive, Legacy method)")


console.log("======")

startTime = Date.now()
results = filter(lines, 'indx')
console.log("Filtering #{lines.length} entries for 'indx' took #{Date.now() - startTime}ms for #{results.length} results (~10% of results are positive, Fuzzy match)")

startTime = Date.now()
results = filter(lines, 'indx', legacy)
console.log("Filtering #{lines.length} entries for 'indx' took #{Date.now() - startTime}ms for #{results.length} results (~10% of results are positive, Fuzzy match, Legacy)")

console.log("======")

startTime = Date.now()
results = filter(lines, 'walkdr')
console.log("Filtering #{lines.length} entries for 'walkdr' took #{Date.now() - startTime}ms for #{results.length} results (~1% of results are positive, fuzzy)")

startTime = Date.now()
results = filter(lines, 'walkdr', legacy)
console.log("Filtering #{lines.length} entries for 'walkdr' took #{Date.now() - startTime}ms for #{results.length} results (~1% of results are positive, Legacy method)")


console.log("======")

startTime = Date.now()
results = filter(lines, 'node', forceAllMatch)
console.log("Filtering #{lines.length} entries for 'node' took #{Date.now() - startTime}ms for #{results.length} results (~98% of results are positive, mostly Exact match)")

startTime = Date.now()
results = filter(lines, 'node', legacy)
console.log("Filtering #{lines.length} entries for 'node' took #{Date.now() - startTime}ms for #{results.length} results (~98% of results are positive, mostly Exact match, Legacy method)")


console.log("======")

startTime = Date.now()
results = filter(lines, 'nm', forceAllMatch)
console.log("Filtering #{lines.length} entries for 'nm' took #{Date.now() - startTime}ms for #{results.length} results (~98% of results are positive, Acronym match)")

startTime = Date.now()
results = filter(lines, 'nm', forceAllMatch)
console.log("Filtering #{lines.length} entries for 'nm' took #{Date.now() - startTime}ms for #{results.length} results (~98% of results are positive, Acronym match, Legacy method)")


console.log("======")

startTime = Date.now()
results = filter(lines, 'nodemodules', forceAllMatch)
console.log("Filtering #{lines.length} entries for 'nodemodules' took #{Date.now() - startTime}ms for #{results.length} results (~98% positive + Fuzzy match, [Worst case scenario])")

startTime = Date.now()
results = filter(lines, 'nodemodules')
console.log("Filtering #{lines.length} entries for 'nodemodules' took #{Date.now() - startTime}ms for #{results.length} results (~98% positive + Fuzzy match, [Mitigation])")

startTime = Date.now()
results = filter(lines, 'nodemodules', legacy)
console.log("Filtering #{lines.length} entries for 'nodemodules' took #{Date.now() - startTime}ms for #{results.length} results (Legacy)")

console.log("======")

startTime = Date.now()
match(line, 'index') for line in lines
console.log("Matching #{results.length} results for 'index' took #{Date.now() - startTime}ms")


